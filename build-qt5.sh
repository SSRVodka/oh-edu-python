#!/bin/bash

. setup.sh
# qmake.conf use x86-64 instead of x86_64
if [ "$OHOS_ARCH" == "x86_64" ]; then
	OHOS_ARCH="x86-64"
fi

# fuck OpenHarmony API
ver_cmp=$(compare_versions "${OHOS_SDK_API_VERSION}" "15")
if [ $ver_cmp == -1 ]; then
	error "Qt5 only support OHOS API greater then 15"
	exit 1
fi

# apply patches
QT_VERSION=v5.15.12

src_dir=${CUR_DIR}/qt5-ohos
patch_dir=${CUR_DIR}/qt-ohos-patches/patch/${QT_VERSION}
if [ ! -d $src_dir ]; then
	error "cannot find Qt source directory"
	exit 1
fi
if [ ! -d $patch_dir ]; then
	error "cannot find ohos patch for Qt ${QT_VERSION}"
	exit 1
fi

# patch mark
if [ ! -f $src_dir/patched ]; then

ptch_cnt=0
for ptch in $patch_dir/*.patch; do
	bn=$(basename $ptch)
	if [ $bn == "root.patch" ]; then
		git -C ${src_dir} apply $ptch
	else
		module_name=$(echo $bn | awk -F'.' '{print $1}')
		module_path=$src_dir/${module_name}
		git -C ${module_path} apply $ptch
	fi
	ptch_cnt=$[ptch_cnt+1]
done

if [ $ptch_cnt -eq 0 ]; then
	error "no patch file in $patch_dir"
	exit 1
fi
info "applied $ptch_cnt patch(es) to Qt ${QT_VERSION}"

# oh extra module
oh_extra_dir=$patch_dir/qtohextras
oh_extra_dest=$src_dir/qtohextras
if [ ! -d $oh_extra_dir ]; then
	warn "OH extra module for Qt ${QT_VERSION} not found"
else
	if [ -d $oh_extra_dest ]; then
		rm -rf $oh_extra_dest
	fi
	cp -r $oh_extra_dir $oh_extra_dest
	# create git submodule mark
	echo "gitdir: ../.git/modules/qtohextras" > $oh_extra_dest/.git
fi
info "added extra OH module for Qt $QT_VERSION"

touch $src_dir/patched

fi


pushd qt5-ohos
mkdir -p ohos-build.${OHOS_CPU}
pushd ohos-build.${OHOS_CPU}

flags=(
  -opensource
  -confirm-license
  -platform linux-g++
  -xplatform oh-clang
  -opengl es2
  -opengles3
  -no-dbus
  -openssl-runtime "OPENSSL_INCDIR=${TARGET_ROOT}.openssl/include"
  -disable-rpath
  -nomake tests
  -nomake examples
  -skip qtpim
  -skip qtvirtualkeyboard
  -skip qtwebengine
  -skip qtsystems
  -skip qtlocation
  -skip qtgamepad
  -skip qtscript
  -skip qtwebview
  -prefix "${TARGET_ROOT}.qt5"
  -release
  -device-option "OHOS_ARCH=${OHOS_ARCH}"
  -make-tool "make -j20"
  -feature-ipc_posix
  -verbose
)

# alsa assimp zstd

# mv build python
export LD_LIBRARY_PATH=${BUILD_PYTHON_DIST}/lib:$LD_LIBRARY_PATH
mv ${OHOS_SDK}/native/llvm/bin/python{,.lock}
ln -s ${BUILD_PYTHON} ${OHOS_SDK}/native/llvm/bin/python

export OHOS_SDK_PATH=$OHOS_SDK
../configure "${flags[@]}"

make -j20
make install

# restore build python
rm ${OHOS_SDK}/native/llvm/bin/python
mv ${OHOS_SDK}/native/llvm/bin/python{.lock,}

popd
popd

# copy dependencies: openssl
cp ${TARGET_ROOT}.openssl/${OHOS_LIBDIR}/{libcrypto.so*,libssl.so*} ${TARGET_ROOT}.qt5/lib



