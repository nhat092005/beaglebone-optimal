# Runbook

Bản tiếng Anh: [`_RUNBOOK_EN.md`](./_RUNBOOK_EN.md)

## Phạm vi

Tài liệu này chỉ giữ đường vận hành ngắn nhất theo contract hiện tại của repo.

Source of truth:

- runtime: `compose.yaml`
- builder image: `docker/Dockerfile`
- public commands: `Makefile`
- local override: `local.mk`

## Thiết lập host

Điều kiện cần:

- Docker Engine
- Docker Compose plugin
- quyền chạy Docker bằng user hiện tại

Tạo local config:

```bash
cp local.mk.example local.mk
```

Đặt storage root là đường dẫn tuyệt đối:

```make
PROJECT_STORAGE_ROOT := /mnt/data/beaglebone-optimal
WORKSPACE_NAME := default
# DOCKER_USER := 1000:1000
```

Kiểm tra setup:

```bash
make doctor
```

Rule:

- không commit `local.mk`
- dữ liệu build lớn phải nằm dưới `PROJECT_STORAGE_ROOT`
- `sd-flash` và `sd-flash-tiny` là lệnh destructive trên host

## Đường dẫn quan trọng

```text
${PROJECT_STORAGE_ROOT}/
├── shared/
│   ├── downloads/
│   └── sstate/
└── workspaces/
    └── ${WORKSPACE_NAME}/yocto/
        ├── sources/
        └── build/
```

Đường dẫn dẫn xuất:

- `YOCTO_SOURCES_DIR=${PROJECT_STORAGE_ROOT}/workspaces/${WORKSPACE_NAME}/yocto/sources`
- `YOCTO_POKY_DIR=${YOCTO_SOURCES_DIR}/poky`
- `YOCTO_BUILD_DIR=${PROJECT_STORAGE_ROOT}/workspaces/${WORKSPACE_NAME}/yocto/build`

## Các lệnh chính

| Lệnh | Mục đích | Lưu ý |
| --- | --- | --- |
| `make doctor` | Kiểm tra Docker và storage setup | Tự build builder image nếu còn thiếu |
| `make docker-build` | Build builder image | Không cần `PROJECT_STORAGE_ROOT` |
| `make docker-shell` | Mở shell trong builder container | Chạy preflight trước |
| `make docker-run CMD='...'` | Chạy một lệnh trong builder container | Bắt buộc có `CMD` |
| `make yocto-init` | Tạo Yocto build dir | Không tự sửa `conf/` |
| `make yocto-parse` | Parse Yocto metadata đang active | Cần `YOCTO_BUILD_DIR/conf/local.conf` |
| `make yocto-dry-run YOCTO_IMAGE=<image>` | Dry-run dependency graph của image | Cần `YOCTO_IMAGE` không rỗng |
| `make yocto-qt-profile` | In profile `qtbase` đang effective | Dùng sau khi áp config Qt |
| `make yocto-build [YOCTO_IMAGE=<image>]` | Build image được chọn | Mặc định `YOCTO_IMAGE=core-image-minimal` |
| `make sd-flash SDCARD=/dev/sdX` | Flash `.wic` vào SD | Bắt buộc là whole-disk device |
| `make sd-flash-tiny SDCARD=/dev/sdX` | Tạo tiny boot media | Sẽ repartition và format thẻ |
| `make netboot-host-setup NETBOOT_IFACE=<iface>` | Setup TFTP+NFS trên host, idempotent | DEV ONLY, bắt buộc `NETBOOT_IFACE` |
| `make netboot-sync-app` | Sync output cài đặt của `qt-dashboard` vào NFS export | DEV ONLY |
| `make netboot-sync-kernel` | Sync `zImage`+dtb vào thư mục TFTP | DEV ONLY |

## Flow Baseline

Clone `poky` trước:

```bash
mkdir -p "$YOCTO_SOURCES_DIR"
cd "$YOCTO_SOURCES_DIR"
git clone -b scarthgap https://git.yoctoproject.org/poky
```

Khởi tạo và áp file mẫu baseline:

```bash
make yocto-init
cp yocto/conf/bblayers.conf.example "$YOCTO_BUILD_DIR/conf/bblayers.conf"
cat yocto/conf/local.conf.example >> "$YOCTO_BUILD_DIR/conf/local.conf"
```

Build và flash:

```bash
make yocto-parse
make yocto-build
make sd-flash SDCARD=/dev/sdX
```

Ghi chú:

- image baseline mặc định: `core-image-minimal`
- machine baseline mặc định: `beaglebone-yocto`
- `sd-flash` dùng `IMAGE` nếu có truyền vào; nếu không sẽ lấy file `.wic` mặc định theo `YOCTO_IMAGE` và `YOCTO_MACHINE` hiện tại

## Flow Tiny

Áp file mẫu tiny:

```bash
make yocto-init
cp yocto/conf/bblayers.conf.tiny.example "$YOCTO_BUILD_DIR/conf/bblayers.conf"
cat yocto/conf/local.conf.tiny.example >> "$YOCTO_BUILD_DIR/conf/local.conf"
```

Build và flash:

```bash
make yocto-parse
make yocto-dry-run YOCTO_IMAGE=core-image-optimal-tiny-initramfs
make yocto-build YOCTO_IMAGE=core-image-optimal-tiny-initramfs
make sd-flash-tiny SDCARD=/dev/sdX
```

Ghi chú:

- tiny image: `core-image-optimal-tiny-initramfs`
- tiny machine: `beaglebone-black-optimal-tiny`
- khi `YOCTO_IMAGE=core-image-optimal-tiny-initramfs`, `make yocto-build` sẽ build thêm `virtual/kernel` và `u-boot`
- `sd-flash-tiny` tạo một phân vùng FAT32 boot và copy `MLO`, `u-boot.img`, `zImage`, tiny DTB, `extlinux.conf`, và `uEnv.txt`

## Flow Qt Dashboard

Trước khi build, thêm `meta-qt6` ngang cấp với `poky` trong
`"$YOCTO_SOURCES_DIR"`.

Áp file mẫu Qt dashboard:

```bash
make yocto-init
cp yocto/conf/bblayers.conf.qt-dashboard.example "$YOCTO_BUILD_DIR/conf/bblayers.conf"
cat yocto/conf/local.conf.qt-dashboard.example >> "$YOCTO_BUILD_DIR/conf/local.conf"
```

Build và flash:

```bash
make yocto-parse
make yocto-qt-profile
make yocto-dry-run YOCTO_IMAGE=core-image-optimal-qt-dashboard
make yocto-build YOCTO_IMAGE=core-image-optimal-qt-dashboard
make sd-flash \
  YOCTO_MACHINE=beaglebone-black-optimal-qt-dashboard \
  YOCTO_IMAGE=core-image-optimal-qt-dashboard \
  SDCARD=/dev/sdX
```

Ghi chú:

- Qt dashboard image: `core-image-optimal-qt-dashboard`
- Qt dashboard machine: `beaglebone-black-optimal-qt-dashboard`

## Flow Qt Dashboard Dev Netboot (DEV ONLY)

Dev-only, không phải contract production. Machine `beaglebone-black-optimal-qt-dashboard-dev`.
Truyền tải qua **USB gadget** (RJ45 CPSW xác nhận hỏng phần cứng trên board này,
xem bd `beaglebone-optimal-24b`), không phải dây Ethernet. Static point-to-point:
host `192.168.7.1`, board `192.168.7.2`.

**Thứ tự bắt buộc: cắm/cấp nguồn board qua cáp USB TRƯỚC, rồi mới chạy
`netboot-host-setup`** — khác với NIC vật lý (luôn có sẵn), interface USB
gadget chỉ xuất hiện sau khi U-Boot đã khởi tạo `usb_ether`.

Cắm cáp USB vào board, cấp nguồn, rồi xem interface mới xuất hiện:

```bash
ip link show   # tìm interface enx... mới xuất hiện sau khi cắm board
```

Setup host (mỗi lần reset host, sau khi board đã cấp nguồn):

```bash
make netboot-host-setup NETBOOT_IFACE=<enx...>
```

Build và flash 1 lần:

```bash
make yocto-init
cp yocto/conf/bblayers.conf.qt-dashboard.example "$YOCTO_BUILD_DIR/conf/bblayers.conf"
cat yocto/conf/local.conf.qt-dashboard-dev.example >> "$YOCTO_BUILD_DIR/conf/local.conf"
make yocto-build YOCTO_MACHINE=beaglebone-black-optimal-qt-dashboard-dev YOCTO_IMAGE=core-image-optimal-qt-dashboard
make sd-flash YOCTO_MACHINE=beaglebone-black-optimal-qt-dashboard-dev SDCARD=/dev/sdX
```

Vòng lặp dev:

```bash
make yocto-bitbake BITBAKE_RECIPE=qt-dashboard && make netboot-sync-app
make yocto-bitbake BITBAKE_RECIPE=virtual/kernel && make netboot-sync-kernel
```

Cắm lại nguồn board sau mỗi lần sync. Không reflash.

Ghi chú:

- `netboot-host-setup` cần sẵn `tftpd-hpa` và `nfs-kernel-server` (không tự cài)
- Ctrl-C trong 2s bootdelay của U-Boot để vào shell thủ công nếu netboot chưa sẵn sàng
- đổi IP host cần rebuild u-boot + reflash lại boot partition (`CONFIG_ENV_IS_NOWHERE=y`)
- không dùng machine này để đo boot-time production

## Boot Timing Capture (`make boot-capture`)

Mặc định host-side UART capture:

- `BOOT_SERIAL_DEVICE=/dev/ttyUSB0`
- `BOOT_SERIAL_BAUD=115200`
- `BOOT_CAPTURE_LOG=tmp/boot-captures/latest.log`

Chạy:

```bash
make boot-capture
```

Hành vi:

- capture luồng serial kèm host timestamps
- append output vào `tmp/boot-captures/latest.log`
- dừng bằng `Ctrl-C`

## Tham chiếu

- `make help`
- `make yocto-list`
- `docs/boot-contract.md`
