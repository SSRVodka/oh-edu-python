#!/bin/bash
set -Eeuo pipefail

CUR_DIR=$(dirname $(readlink -f $0))
cd $CUR_DIR

info () { printf "%b%s%b" "\E[1;34m❯ \E[1;36m" "${1:-}" "\E[0m\n"; }
error () { printf "%b%s%b" "\E[1;31m❯ " "ERROR: ${1:-}" "\E[0m\n" >&2; }
warn () { printf "%b%s%b" "\E[1;31m❯ " "Warning: ${1:-}" "\E[0m\n" >&2; }

supports_all_options() {
	local prog="$1"
	shift
	local options=("$@")

	if [ ! -x "$prog" ]; then
		return 1
	fi

	if [ ${#options[@]} -eq 0 ]; then
		return 1
	fi

	local option
	for option in "${options[@]}"; do
		# check configure file itself
		# grep options:
		#   -F: no regex (fixed string)
		#   -q: quiet mode (no stdout result)
		#   -w: whole word match (-h not match --help)
		#   --: mark the end of options for grep (avoid regarding contents start with '-' as parameters)
		if ! grep -Fq -- "$option" "$prog"; then
			# check --help
			help_output="$("$prog" --help 2>&1 || :)"
			local exit_code=$?
			if [ "$exit_code" -ne 0 ]; then
				return 1
			fi
			if ! echo "$help_output" | grep -Fq -- "$option"; then
				return 1
			fi
		fi
	done

	return 0
}

build_makeproj_with_deps() {
	local target_dir="$1"
	local deps="${2:-}"
	local extra_configure_flags="${3:-}"
	# executing just before configure
	local bootstrap_script="${4:-}"
	local suffix_configure_flags="${5:-}"
	local make_parallism="${6:-}"

	local OLD_CFLAGS="$CFLAGS"
	local OLD_CXXFLAGS="$CXXFLAGS"
	local OLD_CPPFLAGS="$CPPFLAGS"
	local OLD_LDFLAGS="$LDFLAGS"
	local OLD_PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR"

	pushd "$target_dir"

	local dep
	for dep in $deps; do
		CFLAGS="-I${TARGET_ROOT}.${dep}/include ${CFLAGS}"
		LDFLAGS="-L${TARGET_ROOT}.${dep}/${OHOS_LIBDIR} ${LDFLAGS}"
		PKG_CONFIG_LIBDIR="${TARGET_ROOT}.${dep}/${OHOS_LIBDIR}/pkgconfig:$PKG_CONFIG_LIBDIR"
	done

	CXXFLAGS="$CFLAGS"
	CPPFLAGS="$CFLAGS"

	if [ -n "$bootstrap_script" ] && [ -f "$bootstrap_script" ]; then
		"$bootstrap_script"
	fi

	local try_configure_exe="./configure ./Configure ./autogen.sh"
	local configure_exe=""
	for conf_exe in $try_configure_exe; do
		if [ -x "$conf_exe" ]; then
			configure_exe="$conf_exe"
			break
		fi
	done
	if [ -z "$configure_exe" ]; then
		error "no executable configure file in this project"
		return 1
	fi

	configure_flags="${extra_configure_flags} --prefix=${TARGET_ROOT}"
	configure_flags="${configure_flags} --libdir=${TARGET_ROOT}/${OHOS_LIBDIR}"

	if ! supports_all_options $configure_exe "--prefix" "--libdir"; then
		warn "configure file for ${target_dir} doesn't support --prefix/--libdir? It may cause some problems... Remember to check output directory afterwards :("
		#return 1
	fi
	if ! supports_all_options $configure_exe "--host"; then
		warn "configure file doesn't support --host. Take care of your CC/CXX environment variables!"
	else
		configure_flags="${configure_flags} --host=${OHOS_CPU}-linux-musl --build=${BUILD_PLATFORM_TRIPLET}"

		# optional
		if supports_all_options $configure_exe "--target"; then
			configure_flags="${configure_flags} --target=${OHOS_CPU}-linux-musl"
		fi
	fi

	# append suffix flags
	configure_flags="${configure_flags} ${suffix_configure_flags}"

	info "configure flags: ${configure_flags}"
	$configure_exe $configure_flags

	make -j${make_parallism}
	make install

	CFLAGS="$OLD_CFLAGS"
	CXXFLAGS="$OLD_CXXFLAGS"
	CPPFLAGS="$OLD_CPPFLAGS"
	LDFLAGS="$OLD_LDFLAGS"
	PKG_CONFIG_LIBDIR="$OLD_PKG_CONFIG_LIBDIR"

	popd
	mv ${TARGET_ROOT} ${TARGET_ROOT}.${target_dir}
	local dst_dir=${TARGET_ROOT}.${target_dir}/${OHOS_LIBDIR}
	if [ ! -d "$dst_dir" ]; then
		warn "library '$target_dir' doesn't have an arch-dependent library directory '$dst_dir'"
	else
		patch_libdir_origin $target_dir
	fi
}

build_cmakeproj_with_deps() {
	local target_dir=$1
	local deps=${2:-}
	local _my_cmake_extra_flags=${3:-}
	local parallism=${4:-}
	local _my_cmake_builddir=${5:-ohos-build}

	pushd $target_dir

	local dep
	local _extra_cflags=""
	local _extra_ldflags=""
	local _extra_cmakeprefix=""
	local OLD_PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR"
	for dep in $deps; do
		_extra_cflags="-I${TARGET_ROOT}.${dep}/include ${_extra_cflags}"
		_extra_ldflags="-L${TARGET_ROOT}.${dep}/${OHOS_LIBDIR} ${_extra_ldflags}"
		local _tmp_cmakedir="${TARGET_ROOT}.${dep}/${OHOS_LIBDIR}/cmake"
		if [ -d "$_tmp_cmakedir" ]; then
			# non-recursive
			for _item in "$_tmp_cmakedir"/*; do
				if [ ! -e "$item" ]; then
					continue
				fi
				_extra_cmakeprefix="$_item;${_extra_cmakeprefix}"
			done
		fi
		PKG_CONFIG_LIBDIR="${TARGET_ROOT}.${dep}/${OHOS_LIBDIR}/pkgconfig:$PKG_CONFIG_LIBDIR"
	done

	# Use SSRVODKA_APPEND_CMAKE_PREFIX_PATH with semicolons
	${CMAKE_BIN} \
		${_my_cmake_extra_flags} \
		-DOHOS_ARCH=${OHOS_ARCH} \
		-DSSRVODKA_APPEND_COMMON_CFLAGS="$_extra_cflags" \
		-DSSRVODKA_APPEND_COMMON_LINK_FLAGS="$_extra_ldflags" \
		-DSSRVODKA_APPEND_CMAKE_PREFIX_PATH="$_extra_cmakeprefix" \
		-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_CONFIG} \
		-DCMAKE_INSTALL_PREFIX=${TARGET_ROOT}.${target_dir} \
		-DCMAKE_INSTALL_LIBDIR=${OHOS_LIBDIR} \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_VERBOSE_MAKEFILE=ON \
		-B ${_my_cmake_builddir}

	${CMAKE_BIN} --build ${_my_cmake_builddir} -j${parallism}
	${CMAKE_BIN} --install ${_my_cmake_builddir}

	PKG_CONFIG_LIBDIR="$OLD_PKG_CONFIG_LIBDIR"
	popd

	local dst_archlibdir=${TARGET_ROOT}.${target_dir}/${OHOS_LIBDIR}
	if [ ! -d "$dst_archlibdir" ]; then
		warn "library '$target_dir' doesn't have an arch-dependent library directory '$dst_archlibdir'"
	else
		patch_libdir_origin $target_dir
	fi
}

# keep track with oh-pkgmgr install
patch_libdir_origin() {
	local target_dir=$1
	# for libraries like Python
	local skip_patch_so=${2:-}
	local postinst_name="postinst"
	local postinst_path=${TARGET_ROOT}.${target_dir}/postinst
	local dst_archlib_dir=${TARGET_ROOT}.${target_dir}/${OHOS_LIBDIR}
	if [ ! -d "$dst_archlib_dir" ]; then
		error "cannot find directory '$dst_archlib_dir'"
		return 1
	fi
	# don't forget to patch *.la for libtool
	for la_file in "$dst_archlib_dir"/*.la; do
		if [ -f "$la_file" ]; then
			info "patching library archive file generated by libtool: $la_file"
			sed -i "s|libdir='.*'|libdir='${dst_archlib_dir}'|g" "$la_file"
		fi
	done
	# and patch *.pc for pkg-config
	for pc_file in "$dst_archlib_dir"/pkgconfig/*.pc; do
		if [ -f "$pc_file" ]; then
			info "patching pkg-config file generated by Makefile: $pc_file"
			dst_prefix=${TARGET_ROOT}.${target_dir}
			sed -i -e "s|^prefix=.*|prefix=${dst_prefix}|g" \
				-e "s|libdir=.*|libdir=${dst_archlib_dir}|g" \
				-e "/^includedir=\${prefix}/! s|\(includedir=\).*\(/include/.*\)$|\1${dst_prefix}\2|g" \
				"$pc_file"
		fi
	done
	# and execute postinst hook
	if [ -f "$postinst_path" ]; then
		chmod u+x $postinst_path
		# not really important
		$postinst_path ${TARGET_ROOT}.${target_dir} || true
	fi
	# and patch so if necessary
	if [ -n "$skip_patch_so" ]; then
		info "skip patching shared objects"
		return 0
	fi
	for file in "$dst_archlib_dir"/*; do
		if [ -f "$file" ]; then
			if file "$file" | grep -q "ELF.*shared object"; then
				info "patching shared object: $file"
				patchelf --set-rpath '$ORIGIN' "$file"
			fi
		fi
	done
}

OLD_PATH=$PATH
OLD_LD_LIBPATH=${LD_LIBRARY_PATH:=""}

trap "export PATH=${OLD_PATH}; export LD_LIBRARY_PATH=${OLD_LD_LIBPATH}; unset CC CXX AS LD LDXX LLD STRIP RANLIB OBJDUMP OBJCOPY READELF NM AR PROFDATA CFLAGS CXXFLAGS CPPFLAGS LDFLAGS LDSHARED PKG_CONFIG_PATH PKG_CONFIG_LIBDIR PKG_CONFIG_SYSTEM_IGNORE_PATH" ERR SIGINT SIGTERM

if [ -z "${OHOS_SDK}" ]; then
	warn "please set OHOS_SDK env first"
	exit 0
fi

BUILD_PLATFORM_TRIPLET=x86_64-pc-linux-gnu

CMAKE_BIN=${OHOS_SDK}/native/build-tools/cmake/bin/cmake
CMAKE_TOOLCHAIN_CONFIG=${OHOS_SDK}/native/build/cmake/ohos.toolchain.cmake

OHOS_CPU=aarch64
OHOS_ARCH=arm64-v8a
# OHOS_CPU=arm
# OHOS_ARCH=armeabi-v7a
# OHOS_CPU=x86_64
# OHOS_ARCH=x86_64

ARCH=${OHOS_ARCH}

TARGET_ROOT=${CUR_DIR}/dist.${OHOS_CPU}
TEST_DIR=${CUR_DIR}/test-only

# OHOS_LIB_DIR=lib
# Set this for OHOS sdk installation
OHOS_LIBDIR=lib/${OHOS_CPU}-linux-ohos

# Note: Fortran compiler should be changed with ARCH
# Use gnu here instead of ohos: code gen only
#FC=${OHOS_CPU}-linux-gnu-gfortran-11
#mkdir -p ${TARGET_ROOT}/${OHOS_LIBDIR}
#if [ ! -d ${CUR_DIR}/gfortran.libs.${OHOS_CPU} ]; then
#    warn "cannot find library gfortran.libs.${OHOS_CPU} in ${CUR_DIR}"
#else
#    #cp ${CUR_DIR}/gfortran.libs.${OHOS_CPU}/* ${TARGET_ROOT}/${OHOS_LIBDIR}
#    warn "skipping gfortran libs for open source license"
#fi


HOST_SYSROOT=${OHOS_SDK}/native/sysroot
HOST_LIBC=${HOST_SYSROOT}/usr/lib/${OHOS_CPU}-linux-ohos/libc.so

export CC="${OHOS_SDK}/native/llvm/bin/clang --target=${OHOS_CPU}-linux-ohos"
export CXX="${OHOS_SDK}/native/llvm/bin/clang++ --target=${OHOS_CPU}-linux-ohos"
export AS=${OHOS_SDK}/native/llvm/bin/llvm-as
export LD=${OHOS_SDK}/native/llvm/bin/ld.lld
export LDXX=${LD}
export LLD=${LD}
export STRIP=${OHOS_SDK}/native/llvm/bin/llvm-strip
# let `install` to use toolchain's strip
if [ ! -f ${OHOS_SDK}/native/llvm/bin/strip ]; then
	pushd ${OHOS_SDK}/native/llvm/bin
	ln -s llvm-strip strip
	popd
fi
export RANLIB=${OHOS_SDK}/native/llvm/bin/llvm-ranlib
export OBJDUMP=${OHOS_SDK}/native/llvm/bin/llvm-objdump
export OBJCOPY=${OHOS_SDK}/native/llvm/bin/llvm-objcopy
export READELF=${OHOS_SDK}/native/llvm/bin/llvm-readelf
export NM=${OHOS_SDK}/native/llvm/bin/llvm-nm
export AR=${OHOS_SDK}/native/llvm/bin/llvm-ar
export PROFDATA=${OHOS_SDK}/native/llvm/bin/llvm-profdata
if [ ! -f ${OHOS_SDK}/native/llvm/bin/profdata ]; then
	pushd ${OHOS_SDK}/native/llvm/bin
	ln -s llvm-profdata profdata
	popd
fi
#export CFLAGS="-fPIC -D__MUSL__=1 -D__OPENHARMONY__=1 -I${TARGET_ROOT}/include -I${TARGET_ROOT}/include/lzma -I${TARGET_ROOT}/include/ncursesw -I${TARGET_ROOT}/include/readline -I${TARGET_ROOT}/ssl/include"
# keep track with ohos.toolchain.cmake + CMAKE_C_FLAGS_INIT
# including arch-dependent headers
export CFLAGS="-fPIC -D__MUSL__ -D__OHOS__ -D__OPENHARMONY__ -Wno-unused-command-line-argument -I${TARGET_ROOT}/include -I${HOST_SYSROOT}/usr/include -I${HOST_SYSROOT}/usr/include/${OHOS_CPU}-linux-ohos"
export CXXFLAGS=${CFLAGS}
export CPPFLAGS=${CXXFLAGS}
#export LDFLAGS="-fuse-ld=lld -L${TARGET_ROOT}/lib -L${TARGET_ROOT}/ssl/lib64 -L${CUR_DIR}/gfortran.libs.${OHOS_CPU}"
export LDFLAGS="-fuse-ld=lld -L${TARGET_ROOT}/lib -L${HOST_SYSROOT}/usr/${OHOS_LIBDIR}"
export LDSHARED="${CC} ${LDFLAGS} -shared"

export PATH=${OHOS_SDK}/native/llvm/bin:${OHOS_SDK}/native/toolchains:$PATH

export PKG_CONFIG_SYSTEM_IGNORE_PATH=/usr/local/lib/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig
export PKG_CONFIG_LIBDIR="${HOST_SYSROOT}/usr/${OHOS_LIBDIR}:${HOST_SYSROOT}/usr/${OHOS_LIBDIR}/pkgconfig"
# export PKG_CONFIG_SYSROOT_DIR=${HOST_SYSROOT}


################################# Python Relative Local Envs #################################

# NOTE: you also need to change download-python.sh if you change this
PY_VERSION=3.12
PY_VERSION_CODE=312

BUILD_PYTHON_DIST=${CUR_DIR}/build-python.dist
BUILD_PYTHON_DIST_PYTHON=${BUILD_PYTHON_DIST}/bin/python3

BUILD_PYTHON_BIN="${BUILD_PYTHON_DIST}/bin"
BUILD_PYTHON=$BUILD_PYTHON_BIN/python3
BUILD_PIP=$BUILD_PYTHON_BIN/pip3

HOST_PYTHON_DIST=${TARGET_ROOT}
HOST_PYTHON_BIN="${HOST_PYTHON_DIST}/bin"
HOST_PYTHON=$HOST_PYTHON_BIN/python3
HOST_PIP=$HOST_PYTHON_BIN/pip3
HOST_MESON=$HOST_PYTHON_BIN/meson

# modify ARCH in meson config
update_config() {
    local filename="$1"
    sed -i "s/py_ver = '.*'/py_ver = '${PY_VERSION}'/g" "$filename"
    sed -i "s|ohos_sdk = '.*'|ohos_sdk = '${OHOS_SDK}'|g" "$filename"
    sed -i "s|proj_root = '.*'|proj_root = '${CUR_DIR}'|g" "$filename"
    sed -i -e "s/host_cpu = '.*'/host_cpu = '${OHOS_ARCH}'/g" \
           -e "s/host_arch = '.*'/host_arch = '${OHOS_ARCH}'/g" "$filename"
}

if [ ! -d ${CUR_DIR}/meson-scripts ]; then
    warn "cannot find meson template directory: ${CUR_DIR}/meson-scripts"
else
    update_config ${CUR_DIR}/meson-scripts/ohos-build.meson
    update_config ${CUR_DIR}/meson-scripts/scipy-build.meson
    update_config ${CUR_DIR}/meson-scripts/scipy-build.numpy2.meson
    
    escaped_dir=$(printf '%s\n' "$CUR_DIR" | sed -e 's/[&/\]/\\&/g')
    sed -i "s|proj_root[[:space:]]*=[[:space:]]*'[^']*'|proj_root='$escaped_dir'|g" meson-scripts/scipy-build.meson
    sed -i "s|proj_root[[:space:]]*=[[:space:]]*'[^']*'|proj_root='$escaped_dir'|g" meson-scripts/scipy-build.numpy2.meson
fi


PY_CROSS_ROOT=${CUR_DIR}/crossenv_${OHOS_ARCH}
HOST_SITE_PKGS=${PY_CROSS_ROOT}/cross/lib/python${PY_VERSION}/site-packages

PYPKG_NATIVE_OUTPUT_DIR=${CUR_DIR}/dist-pypkgs.native.${OHOS_ARCH}
PYPKG_OUTPUT_WHEEL_DIR=${CUR_DIR}/dist.wheels

