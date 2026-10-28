#!/bin/bash
# 컨테이너 안에서 실행: 현장 설치용(DEPLOY=1) qemuarm64 이미지를 확인한다.
# root 로그인이 막혔는지, 시험용 도구가 빠졌는지, 인쇄 구성은 그대로인지 본다.
# 사용법(호스트): DEPLOY=1 yocto/run.sh 로 빌드한 뒤 yocto/run-test.sh deploy
set -euo pipefail

OUT=/repo/yocto/out/qemu-test
mkdir -p "$OUT"
D=/work/build/tmp/deploy/images/qemuarm64
TAR=$D/printserver-image-qemuarm64.rootfs.tar.zst
fail=0

echo "== 루트 파일시스템"
root=$(tar --zstd -xOf "$TAR" ./etc/shadow | awk -F: '$1 == "root" { print $2 }')
case "$root" in
'') echo "root 비밀번호: 비어 있음 (FAIL)"; fail=1 ;;
'*' | '!'*) echo "root 비밀번호: 잠김 ($root)" ;;
*) echo "root 비밀번호: 설정됨" ;;
esac
files=$(tar --zstd -tf "$TAR")
for f in ./usr/sbin/j1660-queue ./usr/libexec/cups/filter/hpcups-j1660 ./usr/libexec/cups/filter/hpcups ./usr/sbin/cupsd ./usr/sbin/avahi-daemon; do
    grep -qx "$f" <<<"$files" && echo "있음  $f" || { echo "없음  $f (FAIL)"; fail=1; }
done
grep -qx ./usr/bin/avahi-browse <<<"$files" && { echo "있음  avahi-browse (시험용 도구, FAIL)"; fail=1; } || echo "없음  avahi-browse"

echo "== 부팅 후 SSH 로그인"
export BITBAKEDIR=/work/layers/bitbake
set +u
# shellcheck disable=SC1091
. /work/layers/openembedded-core/oe-init-build-env /work/build >/dev/null
set -u
runqemu qemuarm64 printserver-image nographic slirp snapshot qemuparams="-m 1024" < /dev/null > "$OUT/deploy-console.log" 2>&1 &
qpid=$!
trap 'kill $qpid 2>/dev/null || true' EXIT

start=$(date +%s)
while :; do
    kill -0 $qpid 2>/dev/null || { echo "QEMU가 종료됨 (FAIL)"; exit 1; }
    [ $(( $(date +%s) - start )) -lt 600 ] || { echo "SSH 응답 없음 (FAIL)"; exit 1; }
    msg=$(ssh -p 2222 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR -o ConnectTimeout=5 root@127.0.0.1 true 2>&1) && { echo "root 로그인 성공 (FAIL)"; fail=1; break; }
    case "$msg" in
    *"Permission denied"*) echo "root 로그인 거부됨: ${msg##*: }"; break ;;
    esac
    sleep 3
done

[ "$fail" -eq 0 ] && echo "== 결과: 통과" || { echo "== 결과: 실패"; exit 1; }
