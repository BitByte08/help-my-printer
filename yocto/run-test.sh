#!/bin/sh
# 호스트(Windows Git Bash 또는 Linux)에서 실행: 빌드한 qemuarm64 이미지를 부팅해 프린트 서버 동작을 검증한다.
# 사용법: yocto/run-test.sh          시험용 이미지 (qemu-test.sh)
#         yocto/run-test.sh deploy   현장 설치용 이미지 (deploy-test.sh, DEPLOY=1로 빌드한 뒤)
#         yocto/run-test.sh rpi      Pi 4 이미지 파일 구성 (rpi-test.sh, MACHINE=raspberrypi4-64로 빌드한 뒤)
# 결과는 yocto/out/qemu-test/에 남는다.
set -eu
cd "$(dirname "$0")/.."

docker build -q -t helpmyprinter-yocto yocto >/dev/null
# Git Bash에서는 Docker에 넘길 Windows 경로(C:/...)가 필요하다.
repo=$(pwd -W 2>/dev/null || pwd)

MSYS_NO_PATHCONV=1 exec docker run --rm \
    -v yocto-work:/work \
    -v yocto-downloads:/work/downloads \
    -v yocto-sstate:/work/sstate-cache \
    -v "$repo:/repo" \
    helpmyprinter-yocto bash "/repo/yocto/test/${1:-qemu}-test.sh"
