# ubuntu:22.04 digest pinned 2026-04-18 — update with: docker pull ubuntu:22.04 && docker inspect ubuntu:22.04 --format='{{index .RepoDigests 0}}'
FROM ubuntu@sha256:962f6cadeae0ea6284001009daa4cc9a8c37e75d1f5191cf0eb83fe565b63dd7

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    bc \
    binutils-arm-linux-gnueabihf \
    binutils-arm-none-eabi \
    bison \
    ca-certificates \
    chrpath \
    cppcheck \
    cpio \
    curl \
    debianutils \
    device-tree-compiler \
    diffoscope \
    diffstat \
    file \
    flex \
    gawk \
    gcc \
    g++ \
    gcc-arm-linux-gnueabihf=4:11.2.0-1ubuntu1 \
    gcc-arm-none-eabi \
    git \
    iputils-ping \
    libelf-dev \
    libssl-dev \
    libyaml-dev \
    lz4 \
    locales \
    make \
    minicom \
    patch \
    python3 \
    python3-dev \
    python3-pip \
    qemu-system-arm \
    rsync \
    shellcheck \
    socat \
    sparse \
    swig \
    texinfo \
    u-boot-tools \
    unzip \
    wget \
    xz-utils \
    bzip2 \
    zstd \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir "dtschema==2026.4"

ENV CROSS_COMPILE=arm-linux-gnueabihf- \
    ARCH=arm \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /workspace

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
