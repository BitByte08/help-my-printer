#!/bin/bash
# 컨테이너 안에서 실행: raspberrypi4-64 이미지에 실물에서만 쓰는 파일(와이파이 드라이버/펌웨어 등)이
# 들어 있는지 확인한다. QEMU로는 부팅해 볼 수 없는 부분이다.
# 사용법(호스트): MACHINE=raspberrypi4-64 yocto/run.sh 로 빌드한 뒤 yocto/run-test.sh rpi
set -euo pipefail

D=/work/build/tmp/deploy/images/raspberrypi4-64
TAR=$D/printserver-image-raspberrypi4-64.rootfs.tar.bz2
files=$(tar -tjf "$TAR")
fail=0

check() {
    local what=$1 pattern=$2
    local hit
    hit=$(grep -E -m1 "$pattern" <<<"$files" || true)
    if [ -n "$hit" ]; then
        printf '있음  %-28s %s\n' "$what" "$hit"
    else
        printf '없음  %-28s (FAIL)\n' "$what"
        fail=1
    fi
}

echo "== 와이파이"
check "드라이버 brcmfmac" '/brcmfmac\.ko'
check "드라이버 brcmfmac-cyw" '/brcmfmac-cyw\.ko'
check "cfg80211" '/cfg80211\.ko'
# 드라이버는 보드 이름이 붙은 파일을 먼저 찾는다(Pi 4: raspberrypi,4-model-b).
check "칩 펌웨어 (Pi 4 링크)" 'brcm/brcmfmac43455-sdio\.raspberrypi,4-model-b\.bin'
check "칩 펌웨어 (본체)" 'cypress/cyfmac43455-sdio-standard\.bin$'
check "칩 설정 (Pi 4)" 'brcm/brcmfmac43455-sdio\.raspberrypi,4-model-b\.txt'
check "칩 CLM (Pi 4)" 'brcm/brcmfmac43455-sdio\.raspberrypi,4-model-b\.clm_blob'
check "국가별 규정 regulatory.db" '/regulatory\.db$'
check "wpa_supplicant" '/sbin/wpa_supplicant$'
check "wifi.txt 처리" '/sbin/printpi-wifi$'
check "상태 보고서 타이머" 'timers\.target\.wants/printpi-status\.timer'
echo "== 인쇄"
check "cupsd" '/sbin/cupsd$'
check "hpcups" '/cups/filter/hpcups$'
check "보정 필터" '/cups/filter/hpcups-j1660$'
check "큐 자동 생성 udev 규칙" '70-j1660\.rules$'
check "avahi-daemon" '/sbin/avahi-daemon$'

root=$(tar -xjOf "$TAR" ./etc/shadow | awk -F: '$1 == "root" { print $2 }')
case "$root" in
'') echo "root 비밀번호: 비어 있음 (시험용)" ;;
*) echo "root 비밀번호: 잠김 (현장 설치용)" ;;
esac

[ "$fail" -eq 0 ] && echo "== 결과: 통과" || { echo "== 결과: 실패"; exit 1; }
