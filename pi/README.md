# pi

Raspberry Pi에 Samsung SL-J1660을 공유 프린터로 설정한다. iPhone(AirPrint)과 Android(기본 인쇄 서비스/Mopria)에서 같은 Wi-Fi로 인쇄할 수 있다.

## Pi에서 실행

```sh
# 프린터를 USB로 연결하고 전원을 켠 뒤
sudo sh setup.sh
lp -d J1660 /usr/share/cups/data/testprint
```

- 드라이버는 hpcups DeskJet 2130 PPD를 쓴다. 근거는 `../filter-test/README.md`에 있다.
- 다른 PPD를 시험하려면 `sudo PPD=drv:///hpcups.drv/hp-deskjet_1110_series.ppd sh setup.sh`처럼 실행한다.

## Pi 없이 검증 (Docker, arm64 에뮬레이션)

저장소 루트에서 실행한다.

```sh
docker build --platform linux/arm64 --load -t j1660-pi-test pi/test
MSYS_NO_PATHCONV=1 docker run --rm --platform linux/arm64 \
  -v "$(pwd -W):/repo" -v "$(pwd -W)/pi/test/out:/out" j1660-pi-test sh /repo/pi/test/test.sh
```

USB 장치 대신 작업을 파일로 저장하는 `capture` 백엔드로 큐를 만든 뒤 다음을 확인한다.

| 확인 항목 | 결과 (Debian trixie arm64, CUPS 2.4 / hpcups 3.22.10) |
|---|---|
| AirPrint 광고 | `_universal._sub._ipp._tcp` 등록, TXT에 `URF=V1.4,CP1,W8,PQ4-5,SRGB24,RS300,FN3` |
| Mopria 광고 | `mopria-certified=1.3`, `pdl`에 `application/pdf`, `image/pwg-raster`, `image/urf` |
| 외부 주소에서 IPP 접속 | 컨테이너 IP로 `get-printer-attributes` 성공 |
| PDF 인쇄 (Android 주 형식) | PCL3GUI 출력 생성 |
| PWG 래스터 인쇄 (Android 대체 형식) | PCL3GUI 출력 생성 |
| URF 인쇄 (iPhone 형식) | PCL3GUI 출력 생성 |

Docker Desktop 컨테이너는 Bonjour 광고를 LAN으로 내보내지 못하므로, 실제 휴대전화에서 프린터가 보이는지는 Pi에서 확인해야 한다.
