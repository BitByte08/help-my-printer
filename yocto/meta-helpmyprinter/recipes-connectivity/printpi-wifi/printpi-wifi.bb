SUMMARY = "Configure Wi-Fi from wifi.txt on the boot partition"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://printpi-wifi \
    file://printpi-wifi.service \
    file://wpa_supplicant-printpi.conf \
    file://80-wlan.network \
    file://71-printpi-wlan.rules \
    file://printpi-status \
    file://printpi-status.service \
    file://printpi-status.timer \
"

S = "${UNPACKDIR}"

inherit allarch systemd

SYSTEMD_SERVICE:${PN} = "printpi-wifi.service printpi-status.timer"

do_install() {
    install -D -m 0755 ${S}/printpi-wifi ${D}${sbindir}/printpi-wifi
    install -D -m 0644 ${S}/printpi-wifi.service ${D}${systemd_system_unitdir}/printpi-wifi.service
    install -D -m 0644 ${S}/wpa_supplicant-printpi.conf \
        ${D}${systemd_system_unitdir}/wpa_supplicant@.service.d/printpi.conf
    install -D -m 0644 ${S}/80-wlan.network ${D}${systemd_unitdir}/network/80-wlan.network
    install -D -m 0644 ${S}/71-printpi-wlan.rules ${D}${nonarch_base_libdir}/udev/rules.d/71-printpi-wlan.rules
    install -D -m 0755 ${S}/printpi-status ${D}${sbindir}/printpi-status
    install -D -m 0644 ${S}/printpi-status.service ${D}${systemd_system_unitdir}/printpi-status.service
    install -D -m 0644 ${S}/printpi-status.timer ${D}${systemd_system_unitdir}/printpi-status.timer
}

FILES:${PN} += " \
    ${systemd_system_unitdir}/printpi-status.service \
    ${systemd_system_unitdir}/wpa_supplicant@.service.d \
    ${systemd_unitdir}/network \
    ${nonarch_base_libdir}/udev/rules.d \
"

RDEPENDS:${PN} = "wpa-supplicant iw wireless-regdb-static perl"
