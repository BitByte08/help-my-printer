#!/bin/sh
# Raspberry Pi(Raspberry Pi OS trixie)에 Samsung SL-J1660 공유 프린터를 설정한다.
# 공유된 큐는 Avahi로 광고되어 iPhone(AirPrint)과 Android(기본 인쇄 서비스/Mopria)에서 바로 보인다.
#
# 사용법: sudo sh setup.sh
# 환경 변수:
#   QUEUE       큐 이름 (기본 J1660)
#   PPD         드라이버 (기본 hpcups DeskJet 2130 — filter-test/README.md 참고)
#   DEVICE_URI  장치 주소를 직접 지정 (기본: 연결된 J1660을 자동 검색)
set -eu

QUEUE=${QUEUE:-J1660}
PPD=${PPD:-drv:///hpcups.drv/hp-deskjet_2130_series.ppd}
DEVICE_URI=${DEVICE_URI:-}

if [ "$(id -u)" -ne 0 ]; then
    echo "sudo로 실행하세요: sudo sh $0" >&2
    exit 1
fi

echo "== 패키지 설치"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    cups cups-filters printer-driver-hpcups avahi-daemon ghostscript

echo "== 서비스 시작"
if [ -d /run/systemd/system ]; then
    systemctl enable --now avahi-daemon cups
else
    # systemd가 없는 환경(테스트용 컨테이너)에서는 직접 띄운다.
    if ! pgrep -x dbus-daemon >/dev/null; then
        mkdir -p /run/dbus
        dbus-daemon --system
    fi
    pgrep -x avahi-daemon >/dev/null || avahi-daemon -D
    pgrep -x cupsd >/dev/null || cupsd
fi
wait_cupsd() {
    i=0
    until lpstat -r >/dev/null 2>&1; do
        i=$((i + 1))
        [ "$i" -le 30 ] || { echo "cupsd가 응답하지 않습니다." >&2; exit 1; }
        sleep 1
    done
}
wait_cupsd

# 같은 네트워크(@LOCAL)의 기기에서 인쇄할 수 있게 공유를 켠다.
# cupsctl은 cupsd를 재시작하므로 큐를 만들기 전에 실행해야 기본 프린터 설정이 날아가지 않는다.
cupsctl --share-printers
sleep 2
wait_cupsd

echo "== 프린터 검색"
if [ -z "$DEVICE_URI" ]; then
    DEVICE_URI=$(lpinfo -v | awk '$2 ~ /^usb:\/\/Samsung\/SL-J16/ { print $2; exit }')
fi
if [ -z "$DEVICE_URI" ]; then
    echo "SL-J1660을 찾지 못했습니다. USB 연결과 전원을 확인하세요. 검색된 장치:" >&2
    lpinfo -v >&2
    exit 1
fi
echo "장치: $DEVICE_URI"

echo "== 큐 생성: $QUEUE"
lpadmin -p "$QUEUE" -E -v "$DEVICE_URI" -m "$PPD" \
    -D "Samsung SL-J1660" -L "$(hostname)" \
    -o printer-is-shared=true -o PageSize=A4 -o OutputMode=Normal
lpadmin -d "$QUEUE"

if [ -n "${SUDO_USER:-}" ]; then
    usermod -aG lpadmin "$SUDO_USER"
fi

echo "== 완료"
lpstat -t
echo "테스트 인쇄: lp -d $QUEUE /usr/share/cups/data/testprint"
