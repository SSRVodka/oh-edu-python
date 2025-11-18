#!/bin/bash

set -Eeuo pipefail

. setup.sh


CACHE_FILE=__hw_cache_gui.tar.gz

SRCS="freetype fontconfig libdrm SPIRV-Headers SPIRV-Tools SPIRV-LLVM-Translator glslang util-macros xcb-proto xorgproto libXau libxcb xlibs xprotos mesa glu ogre bullet3 flann pcl"

rm -rf $SRCS
if [ "${1:-}" == "--rm" ]; then
	exit 0
fi

if [ -f "$CACHE_FILE" ]; then
	
tar -zxpvf ${CACHE_FILE}

else

wget_source https://downloads.sourceforge.net/freetype/freetype-2.14.1.tar.xz
mv freetype-2.14.1 freetype

wget_source https://gitlab.freedesktop.org/api/v4/projects/890/packages/generic/fontconfig/2.17.1/fontconfig-2.17.1.tar.xz
mv fontconfig-2.17.1 fontconfig

wget_source https://dri.freedesktop.org/libdrm/libdrm-2.4.127.tar.xz
mv libdrm-2.4.127 libdrm

wget_source https://github.com/KhronosGroup/SPIRV-Headers/archive/vulkan-sdk-1.4.328.1/SPIRV-Headers-vulkan-sdk-1.4.328.1.tar.gz
mv SPIRV-Headers-vulkan-sdk-1.4.328.1 SPIRV-Headers

wget_source https://github.com/KhronosGroup/SPIRV-Tools/archive/vulkan-sdk-1.4.328.1/SPIRV-Tools-vulkan-sdk-1.4.328.1.tar.gz
mv SPIRV-Tools-vulkan-sdk-1.4.328.1 SPIRV-Tools

wget_source https://github.com/KhronosGroup/SPIRV-LLVM-Translator/archive/v21.1.1/SPIRV-LLVM-Translator-21.1.1.tar.gz
mv SPIRV-LLVM-Translator-21.1.1 SPIRV-LLVM-Translator

wget_source https://github.com/KhronosGroup/glslang/archive/16.0.0/glslang-16.0.0.tar.gz
mv glslang-16.0.0 glslang

wget_source https://www.x.org/pub/individual/util/util-macros-1.20.2.tar.xz
mv util-macros-1.20.2 util-macros

wget_source https://xorg.freedesktop.org/archive/individual/proto/xcb-proto-1.17.0.tar.xz
mv xcb-proto-1.17.0 xcb-proto

wget_source https://xorg.freedesktop.org/archive/individual/proto/xorgproto-2024.1.tar.xz
mv xorgproto-2024.1 xorgproto

wget_source https://www.x.org/pub/individual/lib/libXau-1.0.12.tar.xz
mv libXau-1.0.12 libXau

wget_source https://xorg.freedesktop.org/archive/individual/lib/libxcb-1.17.0.tar.xz
mv libxcb-1.17.0 libxcb

######################## start xorg libs ########################

XLIBS_MD5_FN=lib-7.md5
XPROTOS_MD5_FN=proto-7.md5
# also change build-gui.sh if change me
LIBNAME_LIST=libnames.list
mkdir -p xlibs xprotos
rm -f xlibs/$LIBNAME_LIST xprotos/$LIBNAME_LIST

pushd xlibs

cat > $XLIBS_MD5_FN << "EOF"
6ad67d4858814ac24e618b8072900664  xtrans-1.6.0.tar.xz
146d770e564812e00f97e0cbdce632b7  libX11-1.8.12.tar.xz
e59476db179e48c1fb4487c12d0105d1  libXext-1.3.6.tar.xz
c5cc0942ed39c49b8fcd47a427bd4305  libFS-1.0.10.tar.xz
d1ffde0a07709654b20bada3f9abdd16  libICE-1.1.2.tar.xz
3aeeea05091db1c69e6f768e0950a431  libSM-1.2.6.tar.xz
ec09c90a1cfd2c0630321d366a5e7203  libXScrnSaver-1.2.5.tar.xz
9acd189c68750b5028cf120e53c68009  libXt-1.3.1.tar.xz
85edefb7deaad4590a03fccba517669f  libXmu-1.2.1.tar.xz
05b5667aadd476d77e9b5ba1a1de213e  libXpm-3.5.17.tar.xz
2a9793533224f92ddad256492265dd82  libXaw-1.0.16.tar.xz
baa39ada682dd524491a165bb0dfc708  libXfixes-6.0.2.tar.xz
af0a5f0abb5b55f8411cd738cf0e5259  libXcomposite-0.4.6.tar.xz
4c54dce455d96e3bdee90823b0869f89  libXrender-0.9.12.tar.xz
5ce55e952ec2d84d9817169d5fdb7865  libXcursor-1.2.3.tar.xz
ca55d29fa0a8b5c4a89f609a7952ebf8  libXdamage-1.1.6.tar.xz
8816cc44d06ebe42e85950b368185826  libfontenc-1.1.8.tar.xz
66e03e3405d923dfaf319d6f2b47e3da  libXfont2-2.0.7.tar.xz
d378be0fcbd1f689f9a132e0d642bc4b  libXft-2.3.9.tar.xz
# 95a960c1692a83cc551979f7ffe28cf4  libXi-1.8.2.tar.xz
# 228c877558c265d2f63c56a03f7d3f21  libXinerama-1.1.5.tar.xz
24e0b72abe16efce9bf10579beaffc27  libXrandr-1.5.4.tar.xz
5014282a08b54ec0edfa73c5cf9ae2c1  libXres-1.2.3.tar.xz
# b62dc44d8e63a67bb10230d54c44dcb7  libXtst-1.2.5.tar.xz
8a26503185afcb1bbd2c65e43f775a67  libXv-1.0.13.tar.xz
a90a5f01102dc445c7decbbd9ef77608  libXvMC-1.0.14.tar.xz
74d1acf93b83abeb0954824da0ec400b  libXxf86dga-1.1.6.tar.xz
d3db4b6dc924dc151822f5f7e79ae873  libXxf86vm-1.1.6.tar.xz
# 57c7efbeceedefde006123a77a7bc825  libpciaccess-0.18.1.tar.xz
229708c15c9937b6e5131d0413474139  libxkbfile-1.1.3.tar.xz
9805be7e18f858bed9938542ed2905dc  libxshmfence-1.3.3.tar.xz
53b72ce969745f8d3e41175d6549ce0b  libXpresent-1.0.2.tar.xz
EOF

grep -v '^#' $XLIBS_MD5_FN | awk '{print $2}' | wget -i- -c \
    -B https://www.x.org/pub/individual/lib/ &&
md5sum -c $XLIBS_MD5_FN

libf_list=$(grep -v '^#' $XLIBS_MD5_FN | awk '{print $2}')
for tf in $libf_list; do
	name_with_version="${tf%%.tar*}"
	lib_name="${name_with_version%-*}"
	# version="${name_with_version##*-}"
	tar -xpvf $tf
	mv $name_with_version $lib_name
	rm $tf
	echo $lib_name >> $LIBNAME_LIST
done

popd

# proto headers

pushd xprotos

cat > $XPROTOS_MD5_FN << "EOF"
# 1a05fb01fa1d5198894c931cf925c025  bigreqsproto-1.1.2.tar.bz2
# 98482f65ba1e74a08bf5b056a4031ef0  compositeproto-0.4.2.tar.bz2
# 998e5904764b82642cc63d97b4ba9e95  damageproto-1.2.1.tar.bz2
# 4ee175bbd44d05c34d43bb129be5098a  dmxproto-2.3.1.tar.bz2
b2721d5d24c04d9980a0c6540cb5396a  dri2proto-2.8.tar.bz2
# a3d2cbe60a9ca1bf3aea6c93c817fee3  dri3proto-1.0.tar.bz2
# e7431ab84d37b2678af71e29355e101d  fixesproto-5.0.tar.bz2
# 36934d00b00555eaacde9f091f392f97  fontsproto-2.1.3.tar.bz2
5565f1b0facf4a59c2778229c1f70d10  glproto-1.4.17.tar.bz2
b290a463af7def483e6e190de460f31a  inputproto-2.3.2.tar.bz2
94afc90c1f7bef4a27fdd59ece39c878  kbproto-1.0.7.tar.bz2
# 92f9dda9c870d78a1d93f366bcb0e6cd  presentproto-1.1.tar.bz2
a46765c8dcacb7114c821baf0df1e797  randrproto-1.5.0.tar.bz2
# 1b4e5dede5ea51906f1530ca1e21d216  recordproto-1.14.2.tar.bz2
a914ccc1de66ddeb4b611c6b0686e274  renderproto-0.11.1.tar.bz2
# cfdb57dae221b71b2703f8e2980eaaf4  resourceproto-1.2.0.tar.bz2
# edd8a73775e8ece1d69515dd17767bfb  scrnsaverproto-1.2.2.tar.bz2
# fe86de8ea3eb53b5a8f52956c5cd3174  videoproto-2.3.3.tar.bz2
# 5f4847c78e41b801982c8a5e06365b24  xcmiscproto-1.2.2.tar.bz2
70c90f313b4b0851758ef77b95019584  xextproto-7.3.0.tar.bz2
# 120e226ede5a4687b25dd357cc9b8efe  xf86bigfontproto-1.2.0.tar.bz2
# a036dc2fcbf052ec10621fd48b68dbb1  xf86dgaproto-2.1.tar.bz2
1d716d0dac3b664e5ee20c69d34bc10e  xf86driproto-2.1.1.tar.bz2
e793ecefeaecfeabd1aed6a01095174e  xf86vidmodeproto-2.3.1.tar.bz2
# 9959fe0bfb22a0e7260433b8d199590a  xineramaproto-1.2.1.tar.bz2
16791f7ca8c51a20608af11702e51083  xproto-7.0.31.tar.bz2
EOF

grep -v '^#' $XPROTOS_MD5_FN | awk '{print $2}' | wget -i- -c \
    -B https://www.x.org/pub/individual/proto/ &&
md5sum -c $XPROTOS_MD5_FN

protf_list=$(grep -v '^#' $XPROTOS_MD5_FN | awk '{print $2}')
for tf in $protf_list; do
	name_with_version="${tf%%.tar*}"
	proto_name="${name_with_version%-*}"
	# version="${name_with_version##*-}"
	tar -xpvf $tf
	mv $name_with_version $proto_name
	rm $tf
	echo $proto_name >> $LIBNAME_LIST
done

popd

######################## end  xorg libs ########################

wget_source https://mesa.freedesktop.org/archive/mesa-25.2.2.tar.xz
mv mesa-25.2.2 mesa

wget_source https://archive.mesa3d.org/glu/glu-9.0.3.tar.xz
mv glu-9.0.3 glu

wget_source https://github.com/OGRECave/ogre/archive/refs/tags/v14.4.1.zip
mv ogre-14.4.1 ogre

wget_source https://github.com/bulletphysics/bullet3/archive/refs/tags/3.25.zip
mv bullet3-3.25 bullet3

wget_source https://github.com/flann-lib/flann/archive/refs/tags/1.9.2.zip
mv flann-1.9.2 flann

wget_source https://github.com/PointCloudLibrary/pcl/releases/download/pcl-1.15.1/source.tar.gz
# pcl don't need to mv


tar -zcpvf ${CACHE_FILE} $SRCS

fi

