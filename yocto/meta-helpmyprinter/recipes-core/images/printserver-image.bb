SUMMARY = "Samsung SL-J1660 print server (AirPrint / Mopria)"
DESCRIPTION = "USB로 연결한 SL-J1660을 CUPS로 공유해 iPhone과 Android에서 인쇄할 수 있게 하는 최소 이미지."
LICENSE = "MIT"

inherit core-image

IMAGE_FEATURES += "ssh-server-dropbear"

# hplip 본체(Python 도구 모음)는 빼고 hpcups 필터와 드라이버 정의만 넣는다.
IMAGE_INSTALL = " \
    packagegroup-core-boot \
    ${CORE_IMAGE_EXTRA_INSTALL} \
    cups \
    cups-filters \
    ghostscript \
    avahi-daemon \
    hplip-filter \
    hplip-cups \
    j1660-queue \
"
