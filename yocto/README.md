# Yocto 프린트 서버 이미지

SL-J1660용 CUPS + AirPrint/Mopria 프린트 서버만 담은 최소 이미지. Yocto 6.0 (wrynose), Docker 안에서 빌드한다.

## 사용법 (Windows, Git Bash)

```sh
sh yocto/run.sh                                  # qemuarm64 이미지 빌드
MACHINE=raspberrypi4-64 sh yocto/run.sh          # Raspberry Pi 4 이미지 빌드
sh yocto/run-test.sh                             # qemuarm64 이미지를 QEMU로 부팅해 검증
```

- 빌드 데이터는 Docker 볼륨 `yocto-work`, `yocto-downloads`, `yocto-sstate`에 남는다. 처음 빌드는 약 1시간 40분(16코어), 이후에는 바뀐 레시피만 다시 빌드한다.
- `UPDATE=1`이면 레이어를 최신으로 받는다.
- 결과 이미지: 볼륨 안 `/work/build/tmp/deploy/images/<MACHINE>/`

## 레이어 `meta-helpmyprinter`

| 파일 | 역할 |
|---|---|
| `recipes-core/images/printserver-image.bb` | cups, cups-filters, ghostscript, hplip(hpcups), avahi, dropbear |
| `recipes-extended/cups/` | `cupsd.conf`: 631 포트 공유, dnssd 광고, 웹 UI 끔 |
| `recipes-extended/j1660-queue/` | USB 연결 시 udev → systemd로 J1660 큐 자동 생성 |
| `recipes-extended/hplip/` | hpcups 크래시 수정 패치 (아래) |

### hplip 패치

hplip 3.25.8의 `IsChromeOs()`가 `/etc/os-release`의 NAME 값을 30바이트 스택 버퍼에 길이 확인 없이 복사한다.
Poky의 NAME(`"Poky (Yocto Project Reference Distro)"`, 39바이트)에서 넘쳐 hpcups가 매 페이지
`stack smashing detected`로 죽는다. Debian의 `0076-Let-IsChromeOS-always-return-0.patch`와 같은 방식으로 고쳤다.

## QEMU 검증 결과 (qemuarm64)

| 항목 | 결과 |
|---|---|
| 부팅 → SSH | 약 60–90초 (TCG 에뮬레이션) |
| 루트 파일시스템 | 232MB 사용, python3 없음 (perl은 hplip-filter 의존성) |
| 서비스 | cups, avahi-daemon, dropbear 모두 active |
| Bonjour | `_ipp._tcp` + `_universal` 서브타입, `URF=V1.4,CP1,W8,PQ4-5,SRGB24,RS300,FN3`, `mopria-certified=1.3` |
| IPP 형식 | application/pdf, image/pwg-raster, image/urf |
| 인쇄 | PDF 20KB / PWG 137KB / URF 16KB, 모두 `LANGUAGE=PCL3GUI`, 4–7초 |

장치 주소만 capture 백엔드(`pi/test/capture-backend.sh`)로 바꿔 시험했다. 출력은 `yocto/out/qemu-test/`에 남는다.
테스트가 `cupsctl --debug-logging`을 실행하므로 CUPS 로그의 `Scheduler shutting down due to program error`
한 줄은 그때 systemd가 cupsd를 다시 띄운 흔적이다.

## Raspberry Pi 4에 올리기

1. 볼륨에서 이미지 꺼내기 (빌드 후 1회):
   ```sh
   MSYS_NO_PATHCONV=1 docker run --rm -v yocto-work:/work -v "$(pwd -W):/repo" helpmyprinter-yocto bash -c \
     'bzip2 -dc /work/build/tmp/deploy/images/raspberrypi4-64/printserver-image-raspberrypi4-64.rootfs.wic.bz2 > /repo/yocto/out/images/printserver-rpi4.img'
   ```
2. Raspberry Pi Imager → 운영체제 "사용자 정의 이미지 사용" → `yocto/out/images/printserver-rpi4.img` → SD카드에 쓰기.
   Imager의 "OS 사용자 지정"(Wi-Fi, 사용자 설정)은 Raspberry Pi OS 전용이라 이 이미지에는 적용되지 않는다.
3. 유선 LAN과 전원을 꽂고 1분 정도 기다린 뒤, 같은 공유기에 연결된 PC에서 `ssh root@printpi.local` (비밀번호 없음).
4. 프린터 USB를 꽂으면 J1660 큐가 자동으로 생긴다. 확인: `lpstat -v`, `journalctl -u j1660-queue`

## 배포 전 할 일

- `conf/local.conf`의 `EXTRA_IMAGE_FEATURES`(root 빈 비밀번호, root SSH 허용)와 `avahi-utils` 제거
