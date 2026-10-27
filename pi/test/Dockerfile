# Raspberry Pi OS trixie를 흉내 내는 arm64 환경. setup.sh가 패키지 설치부터 직접 하도록
# 여기서는 테스트 도구와 캡처 백엔드만 넣는다.
FROM --platform=linux/arm64 debian:trixie-slim

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      procps avahi-utils python3-minimal

# 실물 프린터 대신 작업을 /tmp/capture에 저장하는 CUPS 백엔드
COPY capture-backend.sh /usr/lib/cups/backend/capture
RUN chmod 755 /usr/lib/cups/backend/capture
