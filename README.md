# uml-kernel

Prebuilt **User Mode Linux (UML)** kernel image, published to Docker Hub as
[`oldienki/uml-kernel-6`](https://hub.docker.com/r/oldienki/uml-kernel-6).

The image is a `scratch` image carrying only:

- `/uml/linux` — the UML kernel binary (`linux-6.6.x`, `ARCH=um`)
- `/uml/System.map` — matching symbol map

Consumers mount or `COPY --from=` these artifacts into a runtime image that
also provides a rootfs and entrypoint.

## Contents

- `Dockerfile` — multi-stage build: `kernel` (compile) → `kernel-dist` (scratch image)
- `kernel.config` — kconfig fragment merged onto `ARCH=um defconfig`
- `build-kernel-image.sh` — build/tag/push helper

## Build

```sh
# local build + tag (~15-20 min compile)
./build-kernel-image.sh

# build and publish (requires docker login / git-docker-publish)
./build-kernel-image.sh --push             # push to $DOCKER_REGISTRY (default: ghcr.io)
./build-kernel-image.sh --push-ghcr-io     # push explicitly to ghcr.io
./build-kernel-image.sh --push-docker-io   # push explicitly to docker.io
```

The `--push-*` flags may be combined to push to multiple registries in one run.

Tags produced: `oldienki/uml-kernel-6:<KERNEL_VERSION>` plus `latest`.

### Overrides

| Env var              | Default                  | Purpose                    |
| -------------------- | ------------------------ | -------------------------- |
| `KERNEL_IMAGE_REPO`  | `oldienki/uml-kernel-6`  | Target repo for tags/push  |
| `KERNEL_VERSION`     | `6.6.58`                 | Upstream kernel version    |
| `KERNEL_SHA256`      | (see script/Dockerfile)  | Tarball sha256 (required when bumping `KERNEL_VERSION`) |
| `EXTRA_TAGS`         | `latest`                 | Extra tags to apply        |
| `DOCKER_REGISTRY`    | `ghcr.io`                | Registry used by bare `--push` |

## Bumping the kernel version

1. Pick the version at <https://cdn.kernel.org/pub/linux/kernel/v6.x/> and grab
   its sha256 from `sha256sums.asc`.
2. Build with `KERNEL_VERSION=<x.y.z> KERNEL_SHA256=<sum> ./build-kernel-image.sh`.
3. Review `kernel.config` — the build hard-fails if a required `CONFIG_*`
   option is missing after merge.

## Config contract

`kernel.config` enables what a router/test workload needs: `BLK_DEV_UBD`,
`HOSTFS`, `UML_NET_TUNTAP`, nftables + conntrack + NAT/masquerade, tc
(HTB/FQ/ingress/u32/fw), eBPF (`CLS_BPF`/`ACT_BPF`), `TUN`/`VETH`/`BRIDGE`,
and IPv6 (required for `NF_TABLES_INET` on 6.6). The Dockerfile verifies the
final `.config` and fails the build on regressions.
