# filter-test

실물 프린터 없이 Samsung SL-J1660용 후보 드라이버(hpcups DeskJet 2130/1110)의 출력 스트림을 만들고 분석한다.

## 실행

```sh
docker build -t j1660-filter-test .
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W)/out:/out" j1660-filter-test
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/w" -w /w python:3.12-slim \
  sh -c 'for f in out/*.prn; do python -I pcl_dump.py "$f" > "${f%.prn}.dump.txt"; done'
```

`out/`에 품질 모드별 `.prn`(프린터로 가는 원본 바이트)과 `.dump.txt`(명령 요약)가 생긴다.

## hpcups 3.22.10 결과 (Raspberry Pi OS trixie와 같은 버전)

- 2130과 1110 PPD의 출력 명령 구조는 완전히 같다. 둘 중 무엇을 써도 된다.
- 공통 헤더: `@PJL ENTER LANGUAGE=PCL3GUI`, `ESC*o5W 0d 03 00 00 00`, `ESC*g20W`(래스터 구성)
- 품질 모드별 해상도: FastDraft 300dpi, Normal/Best 600dpi, Photo 1200dpi
- Windows 드라이버의 GPD(`sec_sl-j1660.gpd`)도 300/600dpi 해상도와 최대 1200x1200dpi를 정의하고 있어 서로 맞는다.

## Windows 정품 드라이버 출력과 비교

삼성 드라이버(`secygid17.inf`, 17.59.0.6402)로 `J1660-FILE` 프린터(출력 포트 = `out\win\j1660.prn`)를 만들고
`win_print_sample.ps1`로 같은 레이아웃을 인쇄했다. 관리자 권한으로 프린터를 추가해야 한다.

| 항목 | Windows 삼성 드라이버 | hpcups (2130, Normal) |
|---|---|---|
| 선행 바이트 | NUL 11000바이트 | 없음 |
| 언어 | `@PJL ENTER LANGUAGE=PCL3GUI` | 같음 |
| `ESC*o5W 0d 03 ...` | `00 03 ec` (1004 = GPD의 일반 용지 ID) | `00 00 00` |
| `ESC*o5W 0b 01 00 00 xx` | 컬러 `00`, 흑백 `02` | 없음 |
| `ESC*gW` (래스터 구성) | 12바이트, 컬러 성분 1개(600dpi `0a 01 20 01`) | 20바이트, 검정 1비트(`09 00 01 01`) + 같은 컬러 성분 |
| 해상도, 용지, 래스터 명령 | 600dpi, A4(`&lA26`), `*b V/W` | 같음 |

- 언어, 해상도, 컬러 성분 형식, 래스터 명령 방식이 같다. 같은 펌웨어 계열로 볼 수 있다.
- 차이는 선행 NUL, 용지 종류/컬러 모드 힌트(`*oW`), 별도 검정 평면 사용 여부다.
  실제 HP DeskJet 2130은 hpcups 출력을 그대로 받으므로 대부분 문제가 되지 않을 것으로 본다.
- `System.Drawing`으로는 드라이버의 품질 설정을 바꿀 수 없다(Draft/High 모두 600dpi로 나옴).

실물에서 hpcups 출력이 거부되면 CUPS 후처리 필터로 NUL 선행 바이트와 `*oW` 명령을 Windows와 같게 맞추는 것부터 시도한다.
