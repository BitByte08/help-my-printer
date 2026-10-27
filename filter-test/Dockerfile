# Raspberry Pi OS(Debian trixie 기반)와 같은 CUPS/hpcups 조합을 재현한다.
# 필터 출력은 CPU 아키텍처와 무관하므로 amd64 이미지로 충분하다.
FROM debian:trixie-slim

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      cups cups-client cups-filters printer-driver-hpcups ghostscript poppler-utils xxd \
 && rm -rf /var/lib/apt/lists/*

# file:// 장치를 허용해야 프린터 대신 파일로 출력을 받을 수 있다.
RUN echo "FileDevice Yes" >> /etc/cups/cups-files.conf

COPY run.sh /run.sh
RUN chmod +x /run.sh

ENTRYPOINT ["/run.sh"]
