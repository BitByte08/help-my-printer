#!/bin/sh
# 호스트(Windows Git Bash 또는 Linux)에서 실행: 빌드한 qemuarm64 이미지를 부팅해 프린트 서버 동작을 검증한다.
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
    helpmyprinter-yocto bash /repo/yocto/test/qemu-test.sh
