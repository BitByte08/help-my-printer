#!/bin/bash
# 컨테이너 안에서 실행한다: 레이어를 받고 빌드 설정을 복사한 뒤 bitbake를 돌린다.
# 사용법: build.sh [bitbake 인자...]   (기본: printserver-image)
#   MACHINE=raspberrypi4-64 build.sh   로 대상 보드를 바꾼다 (기본 qemuarm64)
#   UPDATE=1 build.sh                  로 레이어를 최신 커밋으로 갱신한다
#   DEPLOY=1 build.sh                  로 현장 설치용 이미지를 만든다 (SSH 로그인 막음)
set -euo pipefail

W=/work
L=$W/layers
REPO=/repo/yocto

fetch() {
    local name=$1 url=$2 branch=$3
    if [ ! -d "$L/$name/.git" ]; then
        git clone --branch "$branch" --single-branch "$url" "$L/$name"
    elif [ "${UPDATE:-0}" = 1 ]; then
        git -C "$L/$name" pull --ff-only
    fi
}

fetch bitbake            https://git.openembedded.org/bitbake            2.18
fetch openembedded-core  https://git.openembedded.org/openembedded-core  wrynose
fetch meta-yocto         https://git.yoctoproject.org/meta-yocto         wrynose
fetch meta-openembedded  https://git.openembedded.org/meta-openembedded  wrynose
fetch meta-raspberrypi   https://github.com/agherzan/meta-raspberrypi    wrynose

for d in "$L"/*/; do
    printf '%-20s %s\n' "$(basename "$d")" "$(git -C "$d" log -1 --format='%h %cs %s' | cut -c1-70)"
done

# 설정은 저장소의 파일이 기준이다. 매번 덮어써서 볼륨 안 설정이 어긋나지 않게 한다.
mkdir -p "$W/build/conf"
cp "$REPO/conf/local.conf" "$REPO/conf/bblayers.conf" "$W/build/conf/"

export BITBAKEDIR=$L/bitbake
export BB_ENV_PASSTHROUGH_ADDITIONS="${BB_ENV_PASSTHROUGH_ADDITIONS:-} MACHINE DEPLOY"
set +u
# shellcheck disable=SC1091
. "$L/openembedded-core/oe-init-build-env" "$W/build" >/dev/null
set -u

if [ $# -eq 0 ]; then
    set -- printserver-image
fi
bitbake "$@"
