SUMMARY = "Create the CUPS queue when a Samsung SL-J1660 is plugged in"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://j1660-queue \
    file://j1660-queue.service \
    file://70-j1660.rules \
    file://hpcups-j1660 \
    file://j1660-test \
    file://win-sample.prn \
"

S = "${UNPACKDIR}"

inherit allarch systemd

# udev 규칙이 장치 연결 시(부팅 시 콜드플러그 포함) 서비스를 띄우므로 따로 enable하지 않는다.
SYSTEMD_SERVICE:${PN} = "j1660-queue.service"
SYSTEMD_AUTO_ENABLE:${PN} = "disable"

do_install() {
    install -D -m 0755 ${S}/j1660-queue ${D}${sbindir}/j1660-queue
    install -D -m 0644 ${S}/j1660-queue.service ${D}${systemd_system_unitdir}/j1660-queue.service
    install -D -m 0644 ${S}/70-j1660.rules ${D}${nonarch_base_libdir}/udev/rules.d/70-j1660.rules
    install -D -m 0755 ${S}/hpcups-j1660 ${D}${libexecdir}/cups/filter/hpcups-j1660
    install -D -m 0755 ${S}/j1660-test ${D}${sbindir}/j1660-test
    install -D -m 0644 ${S}/win-sample.prn ${D}${datadir}/${BPN}/win-sample.prn
}

FILES:${PN} += "${nonarch_base_libdir}/udev/rules.d"

RDEPENDS:${PN} = "cups hplip-filter hplip-cups perl ghostscript"
