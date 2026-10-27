FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://cupsd.conf"

do_install:append() {
    # 원래 파일의 권한과 소유자(root:lp 0640)를 유지하도록 내용만 바꾼다.
    cat ${UNPACKDIR}/cupsd.conf > ${D}${sysconfdir}/cups/cupsd.conf
}
