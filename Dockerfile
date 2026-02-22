ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive
ARG JADX_VERSION=1.5.2
ARG JADX_SHA256=5a8b480839c9c61527895d81d5572182279d973abe112047417f237df958a3aa

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    make \
    patch \
    unzip \
    apktool \
    aapt \
    zipalign \
    openjdk-21-jdk \
    ripgrep \
  && rm -rf /var/lib/apt/lists/*

RUN curl -fL "https://github.com/skylot/jadx/releases/download/v${JADX_VERSION}/jadx-${JADX_VERSION}.zip" -o /tmp/jadx.zip \
  && echo "${JADX_SHA256}  /tmp/jadx.zip" | sha256sum -c - \
  && rm -rf /opt/jadx \
  && mkdir -p /opt/jadx \
  && unzip -q /tmp/jadx.zip -d /opt/jadx \
  && chmod +x /opt/jadx/bin/jadx /opt/jadx/bin/jadx-gui \
  && ln -sf /opt/jadx/bin/jadx /usr/local/bin/jadx \
  && ln -sf /opt/jadx/bin/jadx-gui /usr/local/bin/jadx-gui \
  && rm -f /tmp/jadx.zip

WORKDIR /work
