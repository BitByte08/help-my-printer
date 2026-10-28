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
    printpi-wifi \
"

# Pi 4 와이파이 드라이버와 칩 펌웨어. 머신 설정의 MACHINE_EXTRA_RRECOMMENDS는 packagegroup-base만 가져오는데
# 이 이미지는 packagegroup-core-boot만 쓰므로 직접 넣는다. (빠지면 wlan0가 아예 생기지 않는다)
IMAGE_INSTALL:append:raspberrypi4-64 = " \
    kernel-module-brcmfmac \
    kernel-module-brcmfmac-cyw \
    kernel-module-brcmfmac-wcc \
    kernel-module-brcmfmac-bca \
    linux-firmware-rpidistro-bcm43455 \
"
