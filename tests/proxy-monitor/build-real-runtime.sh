#!/bin/sh
# Build actual upstream daemons/modules in a private CI prefix, never on router.
set -eu
PREFIX=${1:?private runtime prefix required}
WORK=${2:?private build directory required}
mkdir -p "$PREFIX" "$WORK"
fetch() {
    repo=$1; sha=$2; name=$3
    git clone "$repo" "$WORK/$name"
    git -C "$WORK/$name" checkout "$sha"
}
build() {
    name=$1; shift
    cmake -S "$WORK/$name" -B "$WORK/$name-build" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_PREFIX_PATH="$PREFIX" "$@"
    cmake --build "$WORK/$name-build" -j2
    cmake --install "$WORK/$name-build"
}
fetch https://github.com/openwrt/libubox.git da2d205a5cf3e877c45a2eec488218cbaf452e7d libubox
build libubox -DBUILD_LUA=OFF -DBUILD_EXAMPLES=OFF
fetch https://github.com/openwrt/uci.git 74f6277aabffc943d026f406df57c22595134c42 uci
build uci -DBUILD_LUA=OFF
fetch https://github.com/openwrt/ubus.git 414c60a2e29e72c2c4f573bc50ad54aef076d169 ubus
build ubus -DBUILD_LUA=OFF -DBUILD_EXAMPLES=OFF
fetch https://github.com/jow-/ucode.git fa288dd9b827045265900d0d25f9d834ffd755bf ucode
build ucode -DUBUS_SUPPORT=OFF -DUCI_SUPPORT=ON -DRTNL_SUPPORT=OFF -DNL80211_SUPPORT=OFF -DULOOP_SUPPORT=ON -DZLIB_SUPPORT=OFF -DDIGEST_SUPPORT=OFF -DFFI_SUPPORT=OFF -DCMAKE_C_FLAGS=-Wno-error=deprecated-declarations
fetch https://github.com/openwrt/rpcd.git d99f703e4035d03fbcfbada3cb697db346c2b984 rpcd
# Relocate only filesystem constants of the test build; loader/daemon logic is
# unmodified. This avoids writes to the runner's real /etc/config or /var/run.
python3 - "$WORK/rpcd" "$PREFIX" <<'PY'
import pathlib,sys
src=pathlib.Path(sys.argv[1]); prefix=sys.argv[2]
for name in ['include/rpcd/uci.h','include/rpcd/session.h']:
    p=src/name;s=p.read_text().replace('"/var/run/rpcd', '"'+prefix+'/var/run/rpcd').replace('"/etc/config/', '"'+prefix+'/etc/config/')
    p.write_text(s)
PY
build rpcd -DFILE_SUPPORT=OFF -DIWINFO_SUPPORT=OFF -DRPCSYS_SUPPORT=OFF -DUCODE_SUPPORT=ON -DCMAKE_C_FLAGS="-I$PREFIX/include"
mkdir -p "$PREFIX/etc/config" "$PREFIX/share/rpcd/ucode" "$PREFIX/share/rpcd/acl.d" "$PREFIX/var/run/rpcd"
