# syntax=docker/dockerfile:1
# =============================================================================
# uml-kernel — prebuilt User Mode Linux kernel image
#
# Stages:
#   kernel      — pinned upstream LTS kernel compiled with ARCH=um -> ./linux
#   kernel-dist — scratch image carrying /uml/linux + /uml/System.map,
#                 published to Docker Hub as oldienki/uml-kernel-6 by
#                 build-kernel-image.sh
#
# Build (from this directory):
#   docker build --target kernel-dist -t oldienki/uml-kernel-6:latest .
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: kernel — compile a pinned upstream LTS kernel with ARCH=um.
# -----------------------------------------------------------------------------
FROM debian:bookworm AS kernel

ARG KERNEL_VERSION=6.6.58
ARG KERNEL_SHA256=e7df81e588d70fab5ec3ec3bb04ac53d51f0860fc3b1ec45e0a4167a026899db

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        bc \
        bison \
        flex \
        libelf-dev \
        libssl-dev \
        rsync \
        cpio \
        xz-utils \
        ca-certificates \
        curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Fetch + verify the pinned tarball (checksum from kernel.org sha256sums.asc).
RUN curl -fSL "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz" \
        -o linux.tar.xz \
    && echo "${KERNEL_SHA256}  linux.tar.xz" | sha256sum -c - \
    && tar -xf linux.tar.xz \
    && mv "linux-${KERNEL_VERSION}" linux \
    && rm linux.tar.xz

COPY kernel.config /build/kernel.config

# Base defconfig for ARCH=um, then apply the fragment, then olddefconfig
# to resolve any leftovers deterministically.
RUN make -C linux ARCH=um defconfig \
    && cd linux \
    && ./scripts/kconfig/merge_config.sh -m .config /build/kernel.config \
    && make ARCH=um olddefconfig \
    && make ARCH=um -j"$(nproc)" linux \
    && cp linux /build/uml-linux \
    && cp System.map /build/System.map \
    && /build/uml-linux --version || true

# Hard-fail the image build if a required option regressed out of the
# merged config (Triad negative case).
RUN for opt in CONFIG_BLK_DEV_UBD CONFIG_HOSTFS CONFIG_UML_NET_TUNTAP \
        CONFIG_NET_SCH_HTB CONFIG_NET_SCH_FQ CONFIG_NET_SCH_INGRESS \
        CONFIG_NET_CLS_U32 CONFIG_NET_CLS_FW \
        CONFIG_NF_TABLES CONFIG_NF_TABLES_INET CONFIG_NFT_MASQ \
        CONFIG_NF_CONNTRACK CONFIG_NF_CONNTRACK_MARK CONFIG_NF_CONNTRACK_PROCFS \
        CONFIG_NFT_REJECT CONFIG_NFT_REJECT_INET \
        CONFIG_IPV6 \
        CONFIG_BPF_SYSCALL CONFIG_NET_CLS_BPF CONFIG_NET_ACT_BPF \
        CONFIG_TUN CONFIG_VETH CONFIG_BRIDGE; do \
        grep -q "^${opt}=y" linux/.config \
            || { echo "MISSING KERNEL OPTION: ${opt}"; exit 1; }; \
    done

# -----------------------------------------------------------------------------
# Stage 1b: kernel-dist — minimal scratch image with the UML kernel
# artifacts. Published as oldienki/uml-kernel-6:<version|latest>.
# -----------------------------------------------------------------------------
FROM scratch AS kernel-dist
COPY --from=kernel /build/uml-linux /uml/linux
COPY --from=kernel /build/System.map /uml/System.map
