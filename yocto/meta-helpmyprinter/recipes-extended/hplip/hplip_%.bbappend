FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# hpcups가 Poky의 긴 os-release NAME에서 스택 오버플로로 죽는 문제 (patch 설명 참고)
SRC_URI += "file://0001-Let-IsChromeOs-always-return-0.patch"
