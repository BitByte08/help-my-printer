#!/bin/sh
# setup.sh를 실행한 뒤 iPhone(AirPrint)과 Android(IPP/Mopria)가 요구하는 조건을 확인한다.
# 사용법: 저장소를 /repo에 마운트하고 결과 폴더를 /out에 마운트해서 실행한다.
set -eu

OUT=/out
mkdir -p "$OUT" /tmp/capture
chmod 1777 /tmp/capture
# CUPS가 만든 파일은 0600이라 그대로 복사하면 Linux 호스트의 일반 사용자가 읽지 못한다.
trap 'chmod -R a+rX "$OUT"' EXIT

DEVICE_URI=capture:/j1660 sh /repo/pi/setup.sh > "$OUT/setup.log" 2>&1 || {
    tail -30 "$OUT/setup.log"
    exit 1
}
tail -12 "$OUT/setup.log"

IP=$(hostname -i | awk '{ print $1 }')
URI="ipp://$IP:631/printers/J1660"

echo
echo "== Bonjour 광고 (_ipp._tcp)"
sleep 3
avahi-browse -rtp _ipp._tcp | tee "$OUT/avahi-ipp.txt" | grep '^=' | head -1 | tr ';' '\n' | grep -E 'J1660|"(URF|pdl|Color|kind|product|rp)=' || echo "(광고 없음)"
echo "== AirPrint 서브타입 (_universal._sub._ipp._tcp)"
avahi-browse -tp _universal._sub._ipp._tcp | tee "$OUT/avahi-universal.txt" | grep J1660 || echo "(없음)"

echo
echo "== IPP 속성 ($URI, 컨테이너 외부 주소로 접속)"
ipptool -tv "$URI" get-printer-attributes.test > "$OUT/ipp-attributes.txt"
grep -E "^\s*(document-format-supported|urf-supported|pwg-raster-document-resolution-supported|pwg-raster-document-type-supported|color-supported|media-default|printer-make-and-model|ipp-versions-supported) " "$OUT/ipp-attributes.txt"

echo
echo "== 휴대전화가 보내는 형식으로 인쇄"
cat > /tmp/sample.ps <<'EOF'
%!PS
<< /PageSize [595 842] >> setpagedevice
/Helvetica findfont 28 scalefont setfont
72 760 moveto (SL-J1660 phone test) show
1 0 0 setrgbcolor 72 560 120 120 rectfill
0 0 1 setrgbcolor 352 560 120 120 rectfill
0 0 0 setrgbcolor 72 400 400 100 rectfill
showpage
EOF
gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=/tmp/sample.pdf /tmp/sample.ps
gs -q -dNOPAUSE -dBATCH -sDEVICE=pwgraster -r300 -sOutputFile=/tmp/sample.pwg /tmp/sample.ps
if gs -h | grep -qw urfrgb; then
    gs -q -dNOPAUSE -dBATCH -sDEVICE=urfrgb -r300 -sOutputFile=/tmp/sample.urf /tmp/sample.ps
fi

for f in /tmp/sample.pdf /tmp/sample.pwg /tmp/sample.urf; do
    [ -f "$f" ] || { echo "$(basename "$f"): 생성 불가, 건너뜀"; continue; }
    before=$(ls /tmp/capture | wc -l)
    if ! ipptool -tf "$f" "$URI" print-job.test > "$OUT/print-$(basename "$f").txt" 2>&1; then
        echo "$(basename "$f"): 작업 거부"
        grep -E "FAIL|status-code|EXPECTED" "$OUT/print-$(basename "$f").txt" | head -5
        continue
    fi
    i=0
    while [ -n "$(lpstat -o J1660)" ] && [ "$i" -lt 240 ]; do i=$((i + 1)); sleep 1; done
    job=$(ls -t /tmp/capture | head -1)
    if [ "$(ls /tmp/capture | wc -l)" -le "$before" ]; then
        echo "$(basename "$f"): 출력 없음"
        continue
    fi
    cp "/tmp/capture/$job" "$OUT/$(basename "$f").prn"
    python3 -I /repo/filter-test/pcl_dump.py "$OUT/$(basename "$f").prn" > "$OUT/$(basename "$f").dump.txt"
    printf '%s: %s bytes, %s, %s\n' "$(basename "$f")" "$(wc -c < "$OUT/$(basename "$f").prn")" \
        "$(grep -o 'LANGUAGE=[A-Z0-9]*' "$OUT/$(basename "$f").dump.txt")" \
        "$(grep -c '^RASTER' "$OUT/$(basename "$f").dump.txt") page(s)"
done

cp /var/log/cups/error_log "$OUT/cups_error_log.txt" 2>/dev/null || true
