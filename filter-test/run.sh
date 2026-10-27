#!/bin/sh
# hpcups로 SL-J1660 후보 PPD들의 출력(.prn)을 만들어 /out에 저장한다.
set -eu

OUT=/out
SPOOL=/tmp/cupsout
mkdir -p "$OUT" "$SPOOL"
chmod 777 "$SPOOL"

cupsd
for _ in $(seq 1 20); do lpstat -r >/dev/null 2>&1 && break; sleep 0.5; done

lpinfo -m | grep -i -E "2130|1110" | tee "$OUT/models.txt"

# 테스트 입력: CUPS 기본 테스트 페이지 + 텍스트/컬러 박스가 들어간 A4 PDF
cat > /tmp/sample.ps <<'EOF'
%!PS
<< /PageSize [595 842] >> setpagedevice
/Helvetica findfont 28 scalefont setfont
72 760 moveto (SL-J1660 hpcups test) show
/Helvetica findfont 14 scalefont setfont
72 730 moveto (Black text line - 0123456789 ABCDEFG) show
1 0 0 setrgbcolor 72 560 120 120 rectfill
0 1 0 setrgbcolor 212 560 120 120 rectfill
0 0 1 setrgbcolor 352 560 120 120 rectfill
0 0 0 setrgbcolor 72 400 400 100 rectfill
showpage
EOF
gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=/tmp/sample.pdf /tmp/sample.ps

for model in deskjet_2130_series deskjet_1110_series; do
  q="$model"
  lpadmin -p "$q" -E -v "file://$SPOOL/$q.prn" -m "drv:///hpcups.drv/hp-$model.ppd"
  lpoptions -p "$q" -l > "$OUT/$q.options.txt"
  cp "/etc/cups/ppd/$q.ppd" "$OUT/$q.ppd"

  for mode in $(sed -n 's/^OutputMode[^:]*: *//p' "$OUT/$q.options.txt" | tr -d '*'); do
    for input in sample.pdf testprint; do
      src=/tmp/sample.pdf
      [ "$input" = testprint ] && src=/usr/share/cups/data/testprint
      rm -f "$SPOOL/$q.prn"
      lp -d "$q" -o media=A4 -o OutputMode="$mode" "$src" >/dev/null
      for _ in $(seq 1 120); do [ -z "$(lpstat -o "$q")" ] && break; sleep 0.5; done
      cp "$SPOOL/$q.prn" "$OUT/$q.$mode.${input%.pdf}.prn"
    done
  done
done

cp /var/log/cups/error_log "$OUT/cups_error_log.txt" 2>/dev/null || true
ls -la "$OUT"
