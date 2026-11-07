#!/bin/sh
# 현장 설치용 Pi 4 이미지를 릴리스 파일로 묶는다. 업로드는 하지 않는다.
# 순서: git tag vX.Y.Z → DEPLOY=1 MACHINE=raspberrypi4-64 yocto/run.sh → yocto/release.sh
#       → yocto/out/release/vX.Y.Z/의 .img.xz를 실물로 시험 → 같은 파일을 gh release create로 올린다.
# 만드는 파일:
#   printserver-rpi4-<버전>.img.xz          Raspberry Pi Imager로 바로 굽는 이미지
#   printserver-rpi4-<버전>-licenses.txt    이미지에 든 패키지와 라이선스 목록
#   printserver-rpi4-<버전>-sources.tar     GPL/LGPL/AGPL 패키지의 원본 소스와 패치
#   SHA256SUMS
set -eu
cd "$(dirname "$0")/.."
repo=$(pwd -W 2>/dev/null || pwd)

MSYS_NO_PATHCONV=1 exec docker run --rm -i -v yocto-work:/work -v "$repo:/repo" helpmyprinter-yocto bash -s <<'EOF'
set -euo pipefail
T=/work/build/tmp/deploy
IMG=$T/images/raspberrypi4-64/printserver-image-raspberrypi4-64.rootfs

line=$(tar -xjOf "$IMG.tar.bz2" ./etc/printpi-version 2>/dev/null || true)
ver=${line%% *}
case "$line" in
*"(deploy)") ;;
*) echo "현장 설치용(DEPLOY=1) Pi 4 이미지가 아님: '${line:-버전 없음}'" >&2; exit 1 ;;
esac
case "$ver" in
*-dirty | unknown) echo "커밋하지 않은 변경이 들어간 빌드: $ver" >&2; exit 1 ;;
esac
[ -d "$T/sources" ] || { echo "소스 묶음 없음 ($T/sources). local.conf의 archiver 설정 확인" >&2; exit 1; }

OUT=/repo/yocto/out/release/$ver
rm -rf "$OUT"
mkdir -p "$OUT"
cd "$OUT"
name=printserver-rpi4-$ver

echo "이미지 압축: $name.img.xz"
bzip2 -dc "$IMG.wic.bz2" | xz -T0 -6 > "$name.img.xz"

manifest=$(ls -td "$T"/licenses/*/printserver-image-raspberrypi4-64*/license.manifest | head -n 1)
cp "$manifest" "$name-licenses.txt"

echo "소스 묶기: $name-sources.tar"
tar -cf "$name-sources.tar" -C "$T/sources" .

sha256sum -- * > SHA256SUMS
ls -l
cat SHA256SUMS
EOF
