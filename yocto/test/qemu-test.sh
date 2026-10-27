#!/bin/bash
# 컨테이너 안에서 실행: printserver-image를 QEMU(qemuarm64)로 부팅하고 guest-test.sh를 SSH로 실행한다.
# 사용법(Windows): yocto/run-test.sh
set -euo pipefail

OUT=/repo/yocto/out/qemu-test
mkdir -p "$OUT"

export BITBAKEDIR=/work/layers/bitbake
set +u
# shellcheck disable=SC1091
. /work/layers/openembedded-core/oe-init-build-env /work/build >/dev/null
set -u

# 이미지가 ext4.zst라 snapshot 모드가 필요하다(압축을 풀어 임시로 부팅, 원본은 그대로). 기본 메모리 256MB는 gs에 빠듯하다.
runqemu qemuarm64 printserver-image nographic slirp snapshot qemuparams="-m 1024" < /dev/null > "$OUT/qemu-console.log" 2>&1 &
qpid=$!
trap 'kill $qpid 2>/dev/null || true' EXIT

ssh_guest() {
    ssh -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR -o ConnectTimeout=5 root@127.0.0.1 "$@"
}

echo "== QEMU 부팅 대기"
start=$(date +%s)
until ssh_guest true 2>/dev/null; do
    kill -0 $qpid 2>/dev/null || { echo "QEMU가 종료됨"; tail -30 "$OUT/qemu-console.log"; exit 1; }
    [ $(( $(date +%s) - start )) -lt 600 ] || { echo "SSH 접속 시간 초과"; exit 1; }
    sleep 3
done
echo "SSH 접속까지 $(( $(date +%s) - start ))초"

# 실물 프린터 대신 작업을 파일로 저장하는 백엔드를 넣는다.
ssh_guest 'd=$(ls -d /usr/libexec/cups/backend /usr/lib/cups/backend 2>/dev/null | head -n 1);
           cat > "$d/capture" && chmod 755 "$d/capture"' < /repo/pi/test/capture-backend.sh

ssh_guest sh -s < /repo/yocto/test/guest-test.sh 2>&1 | tee "$OUT/guest-test.log"
ssh_guest 'cat /tmp/capture/*.prn' > "$OUT/captured.prn" 2>/dev/null || true
ssh_guest poweroff || true
wait $qpid || true
