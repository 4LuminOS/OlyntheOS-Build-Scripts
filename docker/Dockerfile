# syntax=docker/dockerfile:1
FROM debian:13

ENV DEBIAN_FRONTEND=noninteractive

# Install common ISO/build tooling (adjust if build.sh needs extra deps)
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    coreutils \
    curl \
    git \
    jq \
    make \
    xorriso \
    isolinux \
    syslinux-common \
    grub-pc-bin \
    grub-efi-amd64-bin \
    mtools \
    dosfstools \
    rsync \
    sudo \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Copy full project into container
COPY . /workspace

# Ensure build script is executable
RUN chmod +x /workspace/docker/build-docker.sh

# Run build and copy produced ISO(s) to /out (bind mount from host)
ENTRYPOINT ["/bin/bash", "-lc", "set -e; /workspace/docker/build-docker.sh; mkdir -p /out; find /workspace -type f -name '*.iso' -exec cp -v {} /out/ \\;; echo 'Done. ISO(s) copied to /out'"]
