# Yocto 6.0 (wrynose) 빌드 환경. 빌드 데이터는 /work 아래 Docker 볼륨에 둔다.
# 패키지 목록: https://docs.yoctoproject.org/6.0/ref-manual/system-requirements.html
FROM ubuntu:24.04

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential chrpath cpio debianutils diffstat file gawk gcc git iputils-ping \
      libacl1 libcrypt-dev locales python3 python3-git python3-jinja2 python3-pexpect \
      python3-pip python3-subunit python3-websockets socat texinfo unzip wget xz-utils zstd \
      ca-certificates lz4 iproute2 openssh-client \
 && rm -rf /var/lib/apt/lists/* \
 && locale-gen en_US.UTF-8

ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# bitbake는 root로 실행할 수 없다. 기본 ubuntu 사용자(uid 1000)를 builder로 바꾼다.
RUN userdel -r ubuntu \
 && useradd -m -u 1000 -s /bin/bash builder \
 && mkdir -p /work/layers /work/build /work/downloads /work/sstate-cache \
 && chown -R builder:builder /work

USER builder
WORKDIR /work
