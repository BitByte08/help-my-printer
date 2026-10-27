#!/bin/sh
# CUPS 백엔드: 프린터로 보낼 데이터를 /tmp/capture/job-<작업번호>.prn에 저장한다.
if [ $# -eq 0 ]; then
    echo 'direct capture "Unknown" "Capture to file"'
    exit 0
fi
cat ${6:+"$6"} > "/tmp/capture/job-$1.prn"
