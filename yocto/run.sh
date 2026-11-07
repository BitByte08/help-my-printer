#!/bin/sh
# 호스트(Windows Git Bash 또는 Linux)에서 실행: 빌드 환경 이미지를 만들고 컨테이너 안에서 build.sh를 돌린다.
# 사용법: yocto/run.sh [bitbake 인자...]
#   MACHINE=raspberrypi4-64 yocto/run.sh
#   UPDATE=1 yocto/run.sh
#   DEPLOY=1 MACHINE=raspberrypi4-64 yocto/run.sh   (현장 설치용: SSH 로그인 막음)
#   yocto/run.sh -c devshell cups   (대화형은 터미널에서 실행)
set -eu
cd "$(dirname "$0")/.."

docker build -q -t helpmyprinter-yocto yocto >/dev/null

tty=
[ -t 0 ] && tty=-it
# Git Bash에서는 Docker에 넘길 Windows 경로(C:/...)가 필요하다.
repo=$(pwd -W 2>/dev/null || pwd)
# 이미지에 넣을 버전. 태그가 붙은 커밋이면 v0.1.0, 아니면 커밋 해시(고친 파일이 있으면 -dirty).
version=${PRINTPI_VERSION:-$(git describe --tags --always --dirty 2>/dev/null || echo unknown)}

# 빌드 데이터는 Docker 볼륨에 둔다. Windows 폴더(NTFS)에서 빌드하면 느리고 대소문자 문제로 깨진다.
MSYS_NO_PATHCONV=1 exec docker run --rm $tty \
    -e MACHINE="${MACHINE:-qemuarm64}" -e UPDATE="${UPDATE:-0}" -e DEPLOY="${DEPLOY:-0}" \
    -e PRINTPI_VERSION="$version" \
    -v yocto-work:/work \
    -v yocto-downloads:/work/downloads \
    -v yocto-sstate:/work/sstate-cache \
    -v "$repo:/repo" \
    helpmyprinter-yocto bash /repo/yocto/build.sh "$@"
