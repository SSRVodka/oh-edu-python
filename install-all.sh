#!/bin/bash

. setup.sh

pkgs=""
while IFS= read -r line; do
	case "$line" in
		\#*) continue;;
	esac
	n=$(echo $line | awk '{ print $2 }')
	ver_cmp=$(compare_versions "${OHOS_SDK_API_VERSION}" "15")
	if [ "$n" == "qt5" ] && [ $ver_cmp == -1 ]; then
		continue
	fi
	pkgs="$n $pkgs"
done < $(pwd)/VERSIONS

oh-pkgmgr add $pkgs

