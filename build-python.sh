#!/bin/bash
set -Eeuo pipefail

DOWNLOAD=0
while getopts "d" arg
do
    case $arg in
    d)
        DOWNLOAD=1
        ;;
    ?)
        warn "Unknown argument: $arg. Ignored."
        ;;
    esac
done

if [ "$DOWNLOAD" -eq 1 ]; then
    ./download-python.sh
fi

################################# Build build-python first! #################################

# NOTE: keep same with setup.sh
BUILD_PYTHON_DIST=$(dirname $(readlink -f $0))/build-python.dist

echo "Set Build-Python Destination: ${BUILD_PYTHON_DIST}"

pushd BPython
./configure \
	--prefix=${BUILD_PYTHON_DIST} \
	--enable-shared
make -j
make install
popd

################################# Setup Envs #################################

. setup.sh

################################# Build Python Dependencies #################################

build_makeproj_with_deps "zlib"

build_makeproj_with_deps "openssl" "zlib" "linux-${OHOS_CPU} shared zlib"

build_makeproj_with_deps "libffi" "" "--enable-shared" "./autogen.sh"

build_makeproj_with_deps "sqlite" "" "--enable-shared"


pushd bzip2
# remove cross compile test
# sed -i.bak -e '/^all:/ s/ test//' -e '/^dist:/ s/ check//' Makefile
sed -i -e '/^all:/ s/ test//' -e '/^dist:/ s/ check//' Makefile
make CC="${CC}" AR="${AR}" RANLIB="${RANLIB}" LDFLAGS="${LDFLAGS}" CFLAGS="${CFLAGS} -shared" PREFIX="${TARGET_ROOT}" -f Makefile-libbz2_so
make CC="${CC}" AR="${AR}" RANLIB="${RANLIB}" LDFLAGS="${LDFLAGS}" CFLAGS="${CFLAGS}" PREFIX="${TARGET_ROOT}"
make install PREFIX="${TARGET_ROOT}"
# instsall bzip binaries
cp bzip2-shared ${TARGET_ROOT}/bin
# remove the fucking idiot absolute path symlink
rm -f ${TARGET_ROOT}/bin/{bzcmp,bzegrep,bzfgrep,bzless}
# install bzip dynamic library
bzip_archlib_dst=${TARGET_ROOT}/${OHOS_LIBDIR}
mkdir -p $bzip_archlib_dst
cp libbz2.so.* $bzip_archlib_dst
# bzip2 doesn't support --libdir
mv $bzip_archlib_dst/../*.a $bzip_archlib_dst
popd
mv ${TARGET_ROOT} ${TARGET_ROOT}.bzip2
patch_libdir_origin "bzip2"


build_makeproj_with_deps "xz" "" "--enable-shared" "./autogen.sh"


# fix PKG_CONFIG_LIBDIR for ncurses (ncurses' Makefile use this to install *.pc files)
_pre_ncurses_pkgconfig_libdir=${PKG_CONFIG_LIBDIR}
PKG_CONFIG_LIBDIR="${TARGET_ROOT}/${OHOS_LIBDIR}/pkgconfig"
# we need to patch text-binary for ncursesw6-config
mkdir ${TARGET_ROOT}
cat << 'EOF' > ${TARGET_ROOT}/postinst
#!/bin/bash
set -Eeuo pipefail
_prefix=${1:-}
if [ -z "$_prefix" ]; then
	echo "ERROR: empty prefix in 1st parameter"
	exit 1
fi
sed -i -e "s|^prefix=.*|prefix=${_prefix}|g" \
	-e "s|^\(libdir=\"\).*\(/lib/.*\)$|\1${_prefix}\2|g" \
	-e "s|echo \"\(.*\)/share/terminfo\"|echo \"${_prefix}/share/terminfo\"|g" \
	${_prefix}/bin/ncursesw6-config
EOF

build_makeproj_with_deps "ncurses" "" "--without-progs --with-shared --with-cxx-shared --with-termlib --enable-pc-files"
# link libname without 'w'
info "symlinking alias for ncurses"
pushd ${TARGET_ROOT}.ncurses/${OHOS_LIBDIR}
for lib in form panel menu tinfo ncurses ncurses++ ; do
	ln -sfv lib${lib}w.so lib${lib}.so
	pushd pkgconfig
	ln -sfv ${lib}w.pc ${lib}.pc
	popd
done
popd
PKG_CONFIG_LIBDIR=${_pre_ncurses_pkgconfig_libdir}

# special headers for ncurses
_pre_readline_cflags="$CFLAGS"
CFLAGS="$CFLAGS -I${TARGET_ROOT}.ncurses/include/ncursesw"
CXXFLAGS="$CFLAGS"
CPPFLAGS="$CFLAGS"
build_makeproj_with_deps "readline" "ncurses" "--enable-shared --with-curses"
CFLAGS="$_pre_readline_cflags"
CXXFLAGS="$CFLAGS"
CPPFLAGS="$CFLAGS"

build_makeproj_with_deps "gettext" "" "--enable-shared"

# OHOS doesn't support mq_* (kernel message queue), versionsort, strvercomp
sed -i 's/versionsort/alphasort/g' util-linux/libmount/src/tab_parse.c
build_makeproj_with_deps "util-linux" "ncurses readline" "--disable-static --disable-chfn-chsh --disable-login --disable-nologin --disable-su --disable-setpriv --disable-runuser --disable-pylibmount --disable-liblastlog2 --disable-lsmem --disable-chmem --disable-wall --disable-ipcs --disable-ipcmk --disable-ipcrm --disable-irqtop --disable-lsirq --disable-lsfd --disable-lsipc --disable-libsmartcols --disable-makeinstall-chown --without-python --without-systemd --without-systemdsystemunitdir" "./autogen.sh"

################################# Build Python And Patch #################################

pushd Python
export LD_LIBRARY_PATH=${BUILD_PYTHON_DIST}/lib:$LD_LIBRARY_PATH
# patch configure: ohos triplet not supported
sed -i '/MULTIARCH=\$($CC --print-multiarch 2>\/dev\/null)/a PLATFORM_TRIPLET=$MULTIARCH' configure
# manually add deps (keep track with setup.sh)
_py_deps=$PY_DEPS
_py_cflags="$CFLAGS"
_py_ldflags="$LDFLAGS"
_py_pkgconfig_libdir="$PKG_CONFIG_LIBDIR"
for dep in $_py_deps; do
	_py_cflags="$_py_cflags -I${TARGET_ROOT}.${dep}/include"
	_py_ldflags="$_py_ldflags -L${TARGET_ROOT}.${dep}/${OHOS_LIBDIR}"
	_py_pkgconfig_libdir="$_py_pkgconfig_libdir:${TARGET_ROOT}.${dep}/${OHOS_LIBDIR}/pkgconfig"
done
# add header path for fucking lzma, ncursesw, readline, uuid
_py_cflags="$_py_cflags -I${TARGET_ROOT}.xz/include/lzma -I${TARGET_ROOT}.ncurses/include/ncursesw -I${TARGET_ROOT}.readline/include/readline -I${TARGET_ROOT}.util-linux/include/uuid"

_py_libdir=${TARGET_ROOT}/${OHOS_LIBDIR}

./configure --libdir=${_py_libdir} \
	--target=${OHOS_CPU}-linux-musl \
	--host=${OHOS_CPU}-linux-musl \
	--build=x86_64-pc-linux-gnu \
	--disable-ipv6 \
	--enable-shared \
	--with-libc=${HOST_LIBC} \
	--with-build-python=${BUILD_PYTHON_DIST_PYTHON} \
	--with-ensurepip=install \
	--with-readline=readline \
	--with-openssl=${TARGET_ROOT}.openssl \
	--enable-loadable-sqlite-extensions \
	--prefix=${TARGET_ROOT} \
	ac_cv_file__dev_ptmx=yes \
	ac_cv_file__dev_ptc=no \
	CC="${CC}" CXX="${CXX}" RANLIB="${RANLIB}" STRIP="${STRIP}" AR="${AR}" \
	CFLAGS="${_py_cflags}" CPPFLAGS="${_py_cflags}" LDFLAGS="${_py_ldflags}" \
	LD="${LD}" LDXX="${LDXX}" NM="${NM}" OBJDUMP="${OBJDUMP}" OBJCOPY="${OBJCOPY}" \
	READELF="${READELF}" PROFDATA="${PROFDATA}" \
	PKG_CONFIG_LIBDIR="${_py_pkgconfig_libdir}"
make -j
make install
export LD_LIBRARY_PATH=$OLD_LD_LIBPATH
popd

# Patch the needed info in *.so
_LOST_LIBRARY=libpython${PY_VERSION}.so
_DIST_LIB_DYLOAD_PATH=${_py_libdir}/python${PY_VERSION}/lib-dynload
find "${_DIST_LIB_DYLOAD_PATH}" -type f -name "*.so" -print0 | while IFS= read -r -d '' sofile; do
    info "patch dynamic-linked file: $sofile"
    if ! patchelf --add-needed "${_LOST_LIBRARY}" "$sofile"; then
        error "failed to process file $sofile"
    fi
done

mv ${TARGET_ROOT} ${TARGET_ROOT}.Python
# Patch other info
patch_libdir_origin "Python" "skip-patch-so"


. cleanup.sh
