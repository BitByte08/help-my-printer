# shellcheck shell=sh
# QEMU 게스트 안에서 실행한다(qemu-test.sh가 SSH로 넘김). pi/test/test.sh와 같은 항목을 확인한다.
set -u

echo "== 이미지"
uname -sr
df -h / | tail -1
for c in python3 perl gs hpcups; do
    printf '%-8s %s\n' "$c" "$(command -v "$c" || ls /usr/libexec/cups/filter/"$c" 2>/dev/null || echo '없음')"
done

echo "== 서비스"
for s in cups avahi-daemon dropbear.socket; do
    printf '%-16s %s\n' "$s" "$(systemctl is-active "$s")"
done

echo "== 큐 설정 (j1660-queue, 장치 주소만 capture로 대체)"
mkdir -p /tmp/capture
chmod 1777 /tmp/capture
# 필터 실패 원인이 남도록 디버그 로그를 켠다(cupsd 재시작, j1660-queue가 기동을 기다린다).
cupsctl --debug-logging
DEVICE_URI=capture:/j1660 /usr/sbin/j1660-queue
lpstat -d -v

IP=$(ip route get 1.1.1.1 | awk '{ for (i = 1; i < NF; i++) if ($i == "src") print $(i + 1) }')
URI="ipp://$IP:631/printers/J1660"

echo "== Bonjour 광고"
sleep 3
avahi-browse -rtp _ipp._tcp | grep '^=' | head -n 1 | tr ';' '\n' | tail -n 1 | tr ' ' '\n' | grep -E '"(URF|pdl|Color|mopria-certified|ty)=' || echo "(광고 없음)"
avahi-browse -tp _universal._sub._ipp._tcp | grep -q J1660 && echo "_universal 서브타입: 있음" || echo "_universal 서브타입: 없음"

echo "== IPP 속성 ($URI)"
ipptool -tv "$URI" get-printer-attributes.test > /tmp/attrs.txt || echo "IPP 접속 실패"
grep -E "^ *(urf-supported|pwg-raster-document-resolution-supported|media-default|printer-make-and-model) " /tmp/attrs.txt
grep -o "image/urf\|image/pwg-raster\|application/pdf" /tmp/attrs.txt | sort -u | tr '\n' ' '
echo

echo "== 휴대전화 형식으로 인쇄"
cat > /tmp/sample.ps <<'EOF'
%!PS
<< /PageSize [595 842] >> setpagedevice
/Helvetica findfont 28 scalefont setfont
72 760 moveto (SL-J1660 yocto test) show
1 0 0 setrgbcolor 72 560 120 120 rectfill
0 0 1 setrgbcolor 352 560 120 120 rectfill
0 0 0 setrgbcolor 72 400 400 100 rectfill
showpage
EOF
gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=/tmp/sample.pdf /tmp/sample.ps
gs -q -dNOPAUSE -dBATCH -sDEVICE=pwgraster -r300 -sOutputFile=/tmp/sample.pwg /tmp/sample.ps
gs -q -dNOPAUSE -dBATCH -sDEVICE=urfrgb -r300 -sOutputFile=/tmp/sample.urf /tmp/sample.ps 2>/dev/null || rm -f /tmp/sample.urf

for f in /tmp/sample.pdf /tmp/sample.pwg /tmp/sample.urf; do
    name=$(basename "$f")
    [ -s "$f" ] || { echo "$name: 생성 불가, 건너뜀"; continue; }
    before=$(ls /tmp/capture | wc -l)
    if ! ipptool -tf "$f" "$URI" print-job.test > "/tmp/print-$name.txt" 2>&1; then
        echo "$name: 작업 거부"
        grep -E "FAIL|status-code|EXPECTED" "/tmp/print-$name.txt" | head -n 5
        continue
    fi
    i=0
    # 필터가 실패하면 큐가 멈추고 작업이 남으므로 큐 상태도 본다.
    while [ -n "$(lpstat -o J1660)" ] && ! lpstat -p J1660 | grep -q disabled && [ "$i" -lt 300 ]; do
        i=$((i + 1)); sleep 1
    done
    job=$(ls -t /tmp/capture | head -n 1)
    if [ "$(ls /tmp/capture | wc -l)" -le "$before" ] || [ ! -s "/tmp/capture/$job" ]; then
        echo "$name: 출력 없음 (${i}초)"
        id=$(grep -o '\[Job [0-9]*\]' /var/log/cups/error_log | tail -n 1 | tr -dc 0-9)
        grep "\[Job $id\]" /var/log/cups/error_log |
            grep -iE "error|fail|unable|exited|crashed|signal|started filter|missing" | tail -n 20
        cancel -a J1660
        cupsenable J1660
        continue
    fi
    echo "$name: $(wc -c < "/tmp/capture/$job") bytes, $(grep -a -o 'LANGUAGE=[A-Z0-9]*' "/tmp/capture/$job" | head -n 1), ${i}초"
done

echo "== CUPS 오류 로그"
grep -E "^E " /var/log/cups/error_log 2>/dev/null | tail -5 || true
