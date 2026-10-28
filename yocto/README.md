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

## 와이파이로 연결하기

유선을 쓸 수 없으면 SD카드를 구운 뒤 Windows에 보이는 `boot` 드라이브에 메모장으로 `wifi.txt`를 만든다.

```
SSID=와이파이이름
PASSWORD=비밀번호
COUNTRY=KR
```

- 부팅할 때마다 읽는다. 와이파이가 바뀌면 파일을 고쳐 다시 넣고 재부팅한다. 파일은 지우지 않는다.
- `PASSWORD`를 비우면 암호 없는 와이파이, `COUNTRY`를 생략하면 KR. 메모장의 BOM/CRLF와 한글 SSID를 처리한다.
- 유선이 연결돼 있으면 유선을 우선한다(RouteMetric 10 < 20).
- 와이파이 절전을 끈다. 켜져 있으면 mDNS를 놓쳐 휴대전화에서 프린터가 안 보이거나 깜빡인다.
- 휴대전화도 같은 와이파이에 있어야 한다. 게스트 네트워크나 AP 격리가 켜져 있으면 프린터가 보이지 않는다.
- Windows 모바일 핫스팟에 붙일 때는 대역을 2.4GHz로, "연결된 장치가 없을 때 끄기"를 끔으로 둔다.
  대역 "자동"과 절전 켬 상태에서는 접속에 실패했고, 2.4GHz로 바꾸자 바로 붙었다(2026-10-28 실측).
- 접속이 안 되면 전원을 2분 이상 켜 둔 뒤 끄고, SD카드의 `printpi-status.txt`를 PC에서 연다.
  IP, 주변 와이파이(주파수/신호/보안), 접속 기록, 드라이버 메시지가 들어 있다.
- `boot` 드라이브는 어느 PC에서나 열리므로 비밀번호가 그대로 보인다.

구성: `recipes-connectivity/printpi-wifi` (wifi.txt → `/etc/wpa_supplicant/wpa_supplicant-wlan0.conf`,
wlan0가 생기면 udev가 `wpa_supplicant@wlan0`를 띄움). Pi 4 와이파이 펌웨어 때문에 `local.conf`에서
`synaptics-killswitch` 라이선스를 받는다.

## 실물 프린터 첫 시험

hpcups 출력을 실물이 받아들이는지는 프린터로만 확인할 수 있다. `j1660-test`로 같은 페이지를 세 방식으로 한 장씩 보내 본다.

| 명령 | 보내는 데이터 | 인쇄되면 |
|---|---|---|
| `j1660-test win` | Windows 드라이버 출력 그대로 (변환 없음) | USB 경로와 프린터는 정상 |
| `j1660-test hpcups` | 기본 방식 (hpcups) | 할 일 없음 |
| `j1660-test compat` | hpcups + Windows 호환 보정 | 큐 기본값을 보정으로 바꾼다 |

- win만 인쇄되면 `lpadmin -p J1660 -o J1660Compat=True`로 보정을 기본으로 켠다. 휴대전화 작업에도 적용된다.
- 셋 다 안 되면 `lpstat -t`, `tail -50 /var/log/cups/error_log`과 프린터 반응을 기록한다.

### Windows 호환 보정 (`hpcups-j1660`)

큐는 hpcups를 감싼 필터 `hpcups-j1660`을 쓴다. `J1660Compat`이 꺼져 있으면(기본) hpcups를 그대로 실행하고,
켜져 있으면 출력 머리말을 Windows 드라이버와 같게 맞춘다. 래스터 데이터는 건드리지 않는다.

| 항목 | hpcups | 보정 후 (= Windows) |
|---|---|---|
| 작업 맨 앞 | 없음 | NUL 11000바이트 |
| 미디어 subtype (`*o5W 0d 03 00 ..`, 페이지마다) | 0 | 1004 (`03 ec`) |
| 단면 (`&l0S`, 페이지마다) | 없음 | 있음 |
| 컬러 모드 (`*o5W 0b 01 00 00 ..`) | 흑백일 때만 `02`/`01` | 컬러일 때도 `00` |

남는 차이: hpcups는 검정 평면을 따로 보낸다(`*gW` 20바이트, Windows는 12바이트). 머리말 보정으로는 맞출 수 없다.

## 시험용 / 현장 설치용 이미지

| | 시험용 (기본) | 현장 설치용 (`DEPLOY=1`) |
|---|---|---|
| SSH | root 빈 비밀번호로 접속 | root 비밀번호 잠김, 로그인 불가 |
| avahi-browse | 있음 | 없음 |
| 인쇄 구성 | 같음 | 같음 |

```sh
MACHINE=raspberrypi4-64 sh yocto/run.sh            # 시험용
DEPLOY=1 MACHINE=raspberrypi4-64 sh yocto/run.sh   # 현장 설치용
DEPLOY=1 sh yocto/run.sh && sh yocto/run-test.sh deploy   # 현장 설치용 QEMU 확인
```

두 버전은 같은 빌드 폴더를 쓰므로 마지막에 빌드한 쪽이 deploy 폴더에 남는다. 빌드할 때마다 이미지를 꺼내 둔다
(`printserver-rpi4-test.img`, `printserver-rpi4-deploy.img`).
