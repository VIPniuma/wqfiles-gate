#!/usr/bin/env bash
# 在 macOS runner 执行：编译 dylib -> 组装 deb 目录 -> dpkg-deb 打包。
# 产出 doro_sb_ball.deb（装到越狱机 /var/jb 或 / 由 Cydia/Sileo 安装后 SpringBoard 自动加载）。
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$ROOT"

make clean || true
make

DEB="$ROOT/_deb"
rm -rf "$DEB"
mkdir -p "$DEB/DEBIAN" \
         "$DEB/Library/MobileSubstrate/DynamicLibraries" \
         "$DEB/Library/Application Support/DoroSB"

cp control "$DEB/DEBIAN/control"
cp libDoroSB.dylib "$DEB/Library/MobileSubstrate/DynamicLibraries/libDoroSB.dylib"
cp com.apple.springboard.plist "$DEB/Library/MobileSubstrate/DynamicLibraries/libDoroSB.plist"
# 悬浮球用的头像，随 tweak 安装（SpringBoard 进程从 tweak 安装目录读）
AVATAR="$ROOT/doro_avatar.jpg"
if [[ ! -f "$AVATAR" ]]; then
    AVATAR="$(cd "$ROOT/../heimao_gate" && pwd)/doro_avatar.jpg"
fi
if [[ -f "$AVATAR" ]]; then
    cp "$AVATAR" "$DEB/Library/Application Support/DoroSB/doro_avatar.jpg"
else
    echo "WARNING: doro_avatar.jpg not found, ball will be plain circle" >&2
fi

chmod 0755 "$DEB/DEBIAN" "$DEB/Library/MobileSubstrate/DynamicLibraries/libDoroSB.dylib"
dpkg-deb -b "$DEB" "$ROOT/doro_sb_ball.deb"
echo "wrote $ROOT/doro_sb_ball.deb"
