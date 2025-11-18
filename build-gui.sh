#!/bin/bash
# run build_llvm.sh first

. setup.sh

# ENTER build machine python env: necessary for many GUI pkgs
# override LD_LIBRARY_PATH to use build-python
export LD_LIBRARY_PATH=${BUILD_PYTHON_DIST}/lib:$LD_LIBRARY_PATH
if [ ! -d ${BUILD_PYTHON_DIST} ]; then
	error "build-python is needed by build-gui"
	exit 1
fi
enter_pycrossenv


build_makeproj_with_deps "freetype"

# freetype, readline, ncurses use special header dir
_pre_fc_cflags=$CFLAGS
_pre_fc_cxxflags=$CXXFLAGS
CFLAGS="-I${TARGET_ROOT}.freetype/include/freetype2 -I${TARGET_ROOT}.ncurses/include/ncursesw -I${TARGET_ROOT}.readline/include/readline $CFLAGS"
CXXFLAGS=$CFLAGS
build_makeproj_with_deps "fontconfig" "freetype ncurses readline icu libexpat libxml2 libiconv" "--disable-docs"
CFLAGS=$_pre_fc_cflags
CXXFLAGS=$_pre_fc_cxxflags


# patch meson script to use build-python on host machine
reset_meson $MESON_CROSS_FILE_BASE
sed -i "s|^\(python[[:space:]]*=[[:space:]]*\).*|\1'${BUILD_PYTHON}'|" $MESON_CROSS_FILE_BASE

build_mesonproj_with_deps "libdrm" "" "$MESON_CROSS_FILE_BASE" "-Dvalgrind=disabled"

build_cmakeproj_with_deps "SPIRV-Headers"

build_cmakeproj_with_deps "SPIRV-Tools" "SPIRV-Headers" "\
	-D BUILD_SHARED_LIBS=ON \
	-D SPIRV_WERROR=OFF \
	-D SPIRV-Headers_SOURCE_DIR=${TARGET_ROOT}.SPIRV-Headers \
	"
#-D SPIRV_TOOLS_BUILD_STATIC=OFF

build_cmakeproj_with_deps "SPIRV-LLVM-Translator" "SPIRV-Headers SPIRV-Tools llvm" "\
	-DBUILD_SHARED_LIBS=ON \
	-DCMAKE_SKIP_INSTALL_RPATH=ON \
	-DLLVM_EXTERNAL_SPIRV_HEADERS_SOURCE_DIR=${TARGET_ROOT}.SPIRV-Headers \
	"

build_cmakeproj_with_deps "glslang" "SPIRV-Headers SPIRV-Tools llvm SPIRV-LLVM-Translator" "\
	-DBUILD_SHARED_LIBS=ON \
	-DALLOW_EXTERNAL_SPIRV_TOOLS=ON \
	-DGLSLANG_TESTS=ON \
	"

####################### start building Xorg-7 #######################

XORG_PREFIX=${TARGET_ROOT}.xorg
rm -rf ${XORG_PREFIX}
mkdir -p ${XORG_PREFIX}
# XORG_CONFIG="--sysconfdir=/etc --localstatedir=/data --disable-static"
XORG_CONFIG="--disable-static"
_PRE_XORG_PKGCFG_LIBDIR=$PKG_CONFIG_LIBDIR
PKG_CONFIG_LIBDIR="${XORG_PREFIX}/share/pkgconfig:$PKG_CONFIG_LIBDIR"

mv_xorg_comp_to_prefix() {
	local comp_name=$1
	local original_dst=${TARGET_ROOT}.${comp_name}

	cp -r $original_dst/* ${XORG_PREFIX}/
	rm -rf $original_dst
	# fix patching for Xorg libs like util-macros (pc in share dir)
	patch_libdir_origin "xorg" "" "" "${XORG_PREFIX}/share"
	if [ -d "${XORG_PREFIX}/${OHOS_LIBDIR}" ]; then
		patch_libdir_origin "xorg"
	fi
}

build_makeproj_with_deps "util-macros" "" "$XORG_CONFIG"
mv_xorg_comp_to_prefix "util-macros"

PYTHON=${BUILD_PYTHON} build_makeproj_with_deps "xcb-proto" "" "$XORG_CONFIG"
mv_xorg_comp_to_prefix "xcb-proto"

reset_meson $MESON_CROSS_FILE_BASE
# deps: util-macros
build_mesonproj_with_deps "xorgproto" "util-macros" "$MESON_CROSS_FILE_BASE"
mv_xorg_comp_to_prefix "xorgproto"
# rename doc
mv -v $XORG_PREFIX/share/doc/xorgproto{,-2024.1}

# deps: xorgproto
build_makeproj_with_deps "libXau" "xorgproto" "$XORG_CONFIG"
mv_xorg_comp_to_prefix "libXau"

# deps: libXau, xcp-proto (fake deps xorg)
build_makeproj_with_deps "libxcb" "xorg" "$XORG_CONFIG --without-doxygen --docdir=\${datadir}/doc/libxcb-1.17.0"
mv_xorg_comp_to_prefix "libxcb"

pushd xprotos
for pkg in $(cat libnames.list); do
	info "building xorg protocol component: $pkg"

	# rubbish 2009 xproto. Fuck xorg
	case $pkg in
		xproto|xextproto|renderproto|dri2proto|xf86driproto|xf86vidmodeproto)
			# configure it manually
			# not support aarch64 (${OHOS_CPU}), not support musl. Idiot
			_xproto_arch=${OHOS_CPU}
			if [ "${OHOS_CPU}" == "aarch64" ]; then
				_xproto_arch=arm
			fi
			pushd $pkg
			./configure --prefix=${TARGET_ROOT} \
				--libdir=${TARGET_ROOT}/${OHOS_LIBDIR} \
				--target=${_xproto_arch}-linux-gnu \
				--host=${_xproto_arch}-linux-gnu \
				--build=${BUILD_PLATFORM_TRIPLET} \
				${XORG_CONFIG}
			make install
			popd
			mv ${TARGET_ROOT} ${TARGET_ROOT}.$pkg
			mv_xorg_comp_to_prefix "$pkg"
			continue
		;;
	esac
	build_makeproj_with_deps "$pkg" "util-macros" "$XORG_CONFIG"
	mv_xorg_comp_to_prefix "$pkg"
done
popd

pushd xlibs
# deps: libxcb (fake deps), fontconfig
# note: freetype, readline, ncurses use special header dir
_pre_xlibs_cflags=$CFLAGS
_pre_xlibs_cxxflags=$CXXFLAGS
CFLAGS="-I${TARGET_ROOT}.freetype/include/freetype2 -I${TARGET_ROOT}.ncurses/include/ncursesw -I${TARGET_ROOT}.readline/include/readline $CFLAGS"
CXXFLAGS=$CFLAGS
_xlibs_deps="xorg fontconfig freetype ncurses readline libexpat icu libxml2 libiconv"
for pkg in $(cat libnames.list); do
	info "building xorg lib component: $pkg"
	pkg_flags="$XORG_CONFIG --enable-malloc0returnsnull=no"
	case $pkg in
		libXfont2)
			pkg_flags="$pkg_flags --disable-devel-docs"
		;;
		libXt)
			#pkg_flags="$pkg_flags --with-appdefaultdir=/etc/X11/app-defaults"
		;;
		libXpm)
			pkg_flags="$pkg_flags --disable-open-zfile"
		;;
		libpciaccess*)
			error "OHOS doesn't support X11 pci access"
			# exit 1
			reset_meson "$MESON_CROSS_FILE_BASE"
			build_mesonproj_with_deps "$pkg" "$_xlibs_deps" "$MESON_CROSS_FILE_BASE"
			mv_xorg_comp_to_prefix "$pkg"
			continue
		;;
		*)
			# do nothing special
		;;
	esac
	build_makeproj_with_deps "$pkg" "$_xlibs_deps" "$pkg_flags"
	mv_xorg_comp_to_prefix "$pkg"
done
popd
CFLAGS=$_pre_xlibs_cflags
CXXFLAGS=$_pre_xlibs_cxxflags

# restore flags before leaving xorg building env
PKG_CONFIG_LIBDIR=$_PRE_XORG_PKGCFG_LIBDIR


####################### end  building Xorg-7 #######################


reset_meson $MESON_CROSS_FILE_BASE
# preparing build-time python deps before building mesa
BUILDTIME_PY=$(which build-python)
sed -i "s|^\(python[[:space:]]*=[[:space:]]*\).*|\1'${BUILDTIME_PY}'|" $MESON_CROSS_FILE_BASE
# using build-time (not runtime) python on the host machine
build-pip install packaging mako pyyaml

# patch meson for ohos
sed -i -e "\|ohos|! s|^\(system_has_kms_drm[[:space:]]*=[[:space:]]*.*'linux',[[:space:]]*\)\('sunos',.*\)$|\1'ohos', \2|" \
	-e "\|ohos|! s|^\(if with_platform_android and get_option('platform-sdk-version').*\)$|\1 or 'ohos' == 'ohos'|" \
	mesa/meson.build
# patch for not supporting pthread_cancel
sed -i -e "\|//|! s|\(pthread_cancel(.*);\)|// \1\nprintf(\"OHOS not support pthread_cancel\");exit(1);|g" \
	-e "\|//|! s|\(pthread_setcanceltype(.*);\)|// \1\nprintf(\"OHOS not support pthread_setcanceltype\");exit(1);|g" \
	mesa/src/vulkan/wsi/wsi_common_display.c
# deps: xorg, libdrm, glslang, llvm, SPIRV-*, zstd
_pre_mesa_cflags=$CFLAGS
_pre_mesa_cxxflags=$CXXFLAGS
_pre_mesa_cppflags=$CPPFLAGS
_pre_mesa_ldflags=$LDFLAGS
CFLAGS="-I${TARGET_ROOT}.freetype/include/freetype2 -I${TARGET_ROOT}.ncurses/include/ncursesw -I${TARGET_ROOT}.readline/include/readline -D_GNU_SOURCE $CFLAGS"
CXXFLAGS=$CFLAGS
CPPFLAGS="-D_GNU_SOURCE $CPPFLAGS"
# fix llvm-config failure
LDFLAGS="-lLLVM-21 $LDFLAGS"
build_mesonproj_with_deps "mesa" "xorg libdrm glslang llvm SPIRV-Headers SPIRV-Tools SPIRV-LLVM-Translator zstd fontconfig freetype ncurses readline icu libexpat libxml2 libiconv" \
	"$MESON_CROSS_FILE_BASE" \
	"\
	-Dcpp_rtti=false \
	-Dvalgrind=disabled \
	-Dplatforms=x11 \
	-Dgallium-drivers=llvmpipe \
	-Dvulkan-drivers=swrast \
	" \
	"20"
CFLAGS=$_pre_mesa_cflags
CXXFLAGS=$_pre_mesa_cxxflags
CPPFLAGS=$_pre_mesa_cppflags
LDFLAGS=$_pre_mesa_ldflags


# patch meson.build error
sed -i "s|\(requires:\).*|\1 'gl'|" glu/meson.build
# deps: mesa
_pre_glu_cflags=$CFLAGS
_pre_glu_cxxflags=$CXXFLAGS
CFLAGS="-I${TARGET_ROOT}.freetype/include/freetype2 -I${TARGET_ROOT}.ncurses/include/ncursesw -I${TARGET_ROOT}.readline/include/readline -D_GNU_SOURCE $CFLAGS"
CXXFLAGS=$CFLAGS
build_mesonproj_with_deps "glu" "mesa xorg libdrm glslang llvm SPIRV-Headers SPIRV-Tools SPIRV-LLVM-Translator zstd fontconfig freetype ncurses readline icu libexpat libxml2 libiconv" \
	"$MESON_CROSS_FILE_BASE" \
	"\
	-Dgl_provider=gl \
	"
CFLAGS=$_pre_glu_cflags
CXXFLAGS=$_pre_glu_cxxflags

# patch ogre/deps' cmake
sed -i "s|\(-G \${CMAKE_GENERATOR}\).*$|\1 -DOHOS_ARCH=${OHOS_ARCH}|" ogre/CMake/Dependencies.cmake
# deps: mesa xorg freetype
_pre_ogre_cflags=$CFLAGS
_pre_ogre_cxxflags=$CXXFLAGS
CFLAGS="-I${TARGET_ROOT}.freetype/include/freetype2 -I${TARGET_ROOT}.ncurses/include/ncursesw -I${TARGET_ROOT}.readline/include/readline -D_GNU_SOURCE $CFLAGS"
CXXFLAGS=$CFLAGS
build_cmakeproj_with_deps "ogre" "mesa xorg libdrm glslang llvm SPIRV-Headers SPIRV-Tools SPIRV-LLVM-Translator zstd fontconfig freetype ncurses readline icu libexpat libxml2 libiconv" \
	"-DOGRE_LIB_DIRECTORY=${OHOS_LIBDIR}"
CFLAGS=$_pre_ogre_cflags
CXXFLAGS=$_pre_ogre_cxxflags

# build bullet3 without python bindings (use build-pypkg-bullet.sh to get python bindings)
## patch for pthread_getconcurrency
#sed -i '\|__OPENHARMONY__|! s|^\(#if !defined(__NetBSD__) \&\& !defined(__ANDROID__)\)|\1 \&\& !defined(__OPENHARMONY__)|' bullet3/examples/OpenGLWindow/X11OpenGLWindow.cpp
#sed -i '\|python|! s|^\(TARGET_LINK_LIBRARIES(pybullet[[:space:]]*\)\(BulletRoboticsGUI.*\)$|\1python3.12 \2|' bullet3/examples/pybullet/CMakeLists.txt
## why it will build shared lib without STATIC even STATIC is default? We don't know :(
#sed -i '\|STATIC|! s|^\(ADD_LIBRARY(gwen[[:space:]]*\)\(.*)\)$|\1STATIC \2|' bullet3/examples/ThirdPartyLibs/Gwen/CMakeLists.txt
## deps: mesa xorg python
#build_cmakeproj_with_deps "bullet3" "glu mesa xorg Python" \
#	"\
#	-DLIB_SUFFIX=/${OHOS_CPU}-linux-ohos \
#	-DUSE_DOUBLE_PRECISION=ON \
#	-DBT_USE_EGL=ON \
#	"

# not support libdir
sed -i "\|${OHOS_LIBDIR}|! s|^\(set(config_install_dir \"\)lib\(/cmake/.*\)$|\1${OHOS_LIBDIR}\2|" flann/CMakeLists.txt
_flann_flags="-DBUILD_SHARED_LIBS=ON -DBUILD_MATLAB_BINDINGS=OFF -DBUILD_PYTHON_BINDINGS=OFF"
_flann_libsuffix="${OHOS_LIBDIR#*/}"
if [ ! "$_flann_libsuffix" == "${OHOS_LIBDIR}" ]; then
	_flann_flags="-DLIB_SUFFIX=/$_flann_libsuffix"
fi
build_cmakeproj_with_deps "flann" "lz4" "$_flann_flags"

# deps mesa boost eigen libpng qhull flann
build_cmakeproj_with_deps "pcl" "mesa xorg boost eigen libpng qhull flann lz4" "-DBUILD_SHARED_LIBS=ON -DLIB_INSTALL_DIR=${OHOS_LIBDIR}" "" "" "" "" "20"


