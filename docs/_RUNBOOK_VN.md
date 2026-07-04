# Runbook

Ban tieng Anh: [`_RUNBOOK_EN.md`](./_RUNBOOK_EN.md)

## Mục tiêu

Runbook này mô tả cách vận hành Docker builder phase 1 của repo
`beaglebone-optimal`.

Contract hiện tại:

- runtime truth nằm ở `compose.yaml`
- image build nằm ở `docker/Dockerfile`
- public interface nằm ở `Makefile`
- local machine override nằm ở `local.mk`

Builder này là môi trường build dùng theo kiểu ad-hoc. Đây không phải service
container chạy nền lâu dài.

## Cấu trúc liên quan

```text
.
├── Makefile
├── compose.yaml
├── docker/
│   └── Dockerfile
├── local.mk.example
└── scripts/docker/
    ├── doctor.sh
    └── lib.sh
```

## Điều kiện trước khi dùng

Máy local cần có:

- Docker Engine
- Docker Compose plugin, dùng qua `docker compose`
- quyền chạy Docker từ user hiện tại

Runbook này giả định Docker daemon của máy đã hoạt động ổn.

## Thiết lập local

1. Tạo file local config:

```bash
cp local.mk.example local.mk
```

2. Sửa `local.mk` và đặt `PROJECT_STORAGE_ROOT` thành đường dẫn tuyệt đối.

Ví dụ:

```make
PROJECT_STORAGE_ROOT := /mnt/data/beaglebone-optimal
WORKSPACE_NAME := default

# Optional override. Mặc định Make tự detect uid:gid hiện tại của host.
# DOCKER_USER := 1000:1000
```

Rule quan trọng:

- `PROJECT_STORAGE_ROOT` bắt buộc là absolute path
- `DOCKER_USER` là optional override, nếu set thì phải có dạng `uid:gid`
- không commit `local.mk`
- dữ liệu build lớn phải nằm dưới `PROJECT_STORAGE_ROOT`, không nằm trong source
  tree

## Storage model

Container mount:

- repo root -> `/workspace`
- host storage root -> `/storage`

Bên trong host storage root, repo tự tạo các thư mục chuẩn:

```text
${PROJECT_STORAGE_ROOT}/
├── shared/
│   ├── downloads/
│   └── sstate/
└── workspaces/
    └── ${WORKSPACE_NAME}/
        ├── logs/
        ├── out/
        ├── tmp/
        └── yocto/
            ├── sources/
            └── build/
```

Ý nghĩa:

- `shared/` giữ cache có thể tái sử dụng
- `workspaces/<name>/` giữ output và state riêng của workspace hiện tại
- `yocto/sources/` giữ source checkout và layer Yocto đã pin cho workspace
- `yocto/build/` giữ Yocto Build Directory đang dùng

Đường dẫn host dẫn xuất mà `Makefile` export:

- `YOCTO_SOURCES_DIR=${PROJECT_STORAGE_ROOT}/workspaces/${WORKSPACE_NAME}/yocto/sources`
- `YOCTO_BUILD_DIR=${PROJECT_STORAGE_ROOT}/workspaces/${WORKSPACE_NAME}/yocto/build`
- `YOCTO_DOWNLOADS_DIR=${PROJECT_STORAGE_ROOT}/shared/downloads`
- `YOCTO_SSTATE_DIR=${PROJECT_STORAGE_ROOT}/shared/sstate`

## Lệnh public chuẩn

Xem help:

```bash
make help
```

Build image:

```bash
make docker-build
```

Kiểm tra môi trường:

```bash
make doctor
```

Mở shell trong builder container:

```bash
make docker-shell
```

Chạy một lệnh bất kỳ trong builder container:

```bash
make docker-run CMD='uname -a'
```

Khởi tạo Yocto build directory:

```bash
make yocto-init
```

Build image Yocto mặc định:

```bash
make yocto-build
```

Parse metadata Yocto đang active:

```bash
make yocto-parse
```

Dry-run dependency graph của image hiện tại:

```bash
make yocto-dry-run
```

Flash image Yocto mặc định vào thẻ SD trên máy host:

```bash
make sd-flash SDCARD=/dev/sdX
```

## Hành vi từng lệnh

### `make docker-build`

Hành vi:

- chạy `docker compose build builder`
- không yêu cầu `PROJECT_STORAGE_ROOT`
- dùng cache build của Docker nếu có

Dùng khi:

- build image lần đầu
- muốn rebuild image sau khi sửa `docker/Dockerfile`

### `make doctor`

Hành vi:

- kiểm tra `docker compose version`
- kiểm tra `PROJECT_STORAGE_ROOT`
- tạo cây thư mục cần thiết dưới storage root
- render `docker compose config`
- tự build image nếu image chưa tồn tại
- chạy container và test ghi thật vào `/storage`

Kết quả pass:

```text
doctor: ok
```

Dùng khi:

- mới clone repo
- vừa đổi `local.mk`
- nghi ngờ mount hoặc permission sai

### `make docker-shell`

Hành vi:

- chạy preflight nhẹ
- yêu cầu `PROJECT_STORAGE_ROOT` hợp lệ
- tạo storage dirs nếu thiếu
- tự build image nếu image chưa có
- mở shell tại `/workspace`

### `make docker-run CMD='...'`

Hành vi:

- chạy preflight nhẹ giống `docker-shell`
- fail ngay nếu `CMD` rỗng
- chạy lệnh theo mẫu:

```bash
docker compose run --rm builder bash -lc "$CMD"
```

Ví dụ:

```bash
make docker-run CMD='pwd'
make docker-run CMD='ls -la /storage'
make docker-run CMD='env | sort'
```

### `make yocto-init`

Hành vi:

- chạy cùng preflight như `docker-shell`
- yêu cầu đã có checkout `poky` hợp lệ tại `YOCTO_POKY_DIR`
- tạo Yocto Build Directory bằng cách source `oe-init-build-env`
- không tự sửa file dưới `conf/`
- in ra đường dẫn file mẫu `local.conf` và `bblayers.conf` của project cùng bước manual tiếp theo

Dùng khi:

- `poky` đã được clone dưới `YOCTO_SOURCES_DIR`
- bạn muốn tạo `conf/` trong build dir nằm trên storage root

### `make yocto-build`

Hành vi:

- chạy cùng preflight như `docker-shell`
- yêu cầu có checkout `poky` và `YOCTO_BUILD_DIR/conf/local.conf`
- source `oe-init-build-env` cho build dir nằm trên storage root
- chạy `bitbake ${YOCTO_IMAGE}`

Dùng khi:

- `make yocto-init` đã tạo build dir
- `conf/local.conf` đã có các setting project mà bạn muốn

### `make yocto-parse`

Hành vi:

- chạy cùng preflight như `docker-shell`
- yêu cầu có checkout `poky` và `YOCTO_BUILD_DIR/conf/local.conf`
- source `oe-init-build-env` cho build dir nằm trên storage root
- chạy `bitbake -p`

Dùng khi:

- bạn muốn xác nhận metadata đang active parse được trước khi build thật
- bạn vừa đổi `bblayers.conf`, recipe, hoặc layer composition

### `make yocto-dry-run`

Hành vi:

- chạy cùng preflight như `docker-shell`
- yêu cầu có checkout `poky` và `YOCTO_BUILD_DIR/conf/local.conf`
- yêu cầu `YOCTO_IMAGE` không rỗng
- source `oe-init-build-env` cho build dir nằm trên storage root
- chạy `bitbake ${YOCTO_IMAGE} -n`

Dùng khi:

- bạn muốn xác nhận dependency graph của image hiện tại trước khi build thật
- bạn vừa đổi image, packagegroup, hoặc recipe contract

### `make sd-flash SDCARD='/dev/sdX'`

Hành vi:

- chạy trên máy host, không chạy trong builder container
- bắt buộc truyền block device dạng whole-disk qua `SDCARD`
- dùng `IMAGE` nếu có truyền vào, nếu không sẽ flash file `.wic` mặc định dưới `YOCTO_BUILD_DIR`
- tự unmount các partition con đang mounted của thiết bị đã chọn trước khi ghi
- ưu tiên `bmaptool` với `${IMAGE}.bmap` khi cả hai cùng tồn tại
- fallback sang `dd` khi thiếu `bmaptool` hoặc thiếu file `.bmap`

Dùng khi:

- `make yocto-build` đã tạo xong artifact `.wic`
- bạn đã xác định đúng device của thẻ SD trên host
- bạn cần một lệnh flash chạy trên host có thể lặp lại cho bring-up Phase 2

## Quy ước storage cho Yocto

Repo giữ toàn bộ dữ liệu Yocto nặng dưới cùng host storage root với Docker:

- `/storage/workspaces/${WORKSPACE_NAME}/yocto/sources`
- `/storage/workspaces/${WORKSPACE_NAME}/yocto/build`
- `/storage/shared/downloads`
- `/storage/shared/sstate`

Workflow khuyến nghị bên trong builder container:

```bash
mkdir -p "$YOCTO_SOURCES_DIR"
cd "$YOCTO_SOURCES_DIR"
git clone -b scarthgap https://git.yoctoproject.org/poky
cd poky

source oe-init-build-env "$YOCTO_BUILD_DIR"

cat /workspace/yocto/conf/local.conf.example
cat /workspace/yocto/conf/bblayers.conf.example
```

Cách này giữ source checkout, build output, downloads, và sstate ra khỏi
source tree và gom hết về cùng host-managed storage root.

Luồng cập nhật `conf/local.conf` bằng tay:

```bash
make yocto-init

cd "$YOCTO_POKY_DIR"
source oe-init-build-env "$YOCTO_BUILD_DIR"

cp /workspace/yocto/conf/bblayers.conf.example conf/bblayers.conf
cat /workspace/yocto/conf/local.conf.example >> conf/local.conf
```

## Tiny path workflow

Tiny path là Phase 1 initramfs-only bring-up cho BeagleBone Black.

File contract public:

- `docs/boot-contract.md`
- `yocto/conf/local.conf.tiny.example`
- `yocto/conf/bblayers.conf.tiny.example`
- `yocto/boot/extlinux.conf.tiny.example`
- `yocto/boot/uEnv.txt.tiny.example`

Luồng áp dụng config tiny thủ công:

```bash
make yocto-init

cd "$YOCTO_POKY_DIR"
source oe-init-build-env "$YOCTO_BUILD_DIR"

cp /workspace/yocto/conf/bblayers.conf.tiny.example conf/bblayers.conf
cat /workspace/yocto/conf/local.conf.tiny.example >> conf/local.conf
```

Build tiny image:

```bash
make yocto-parse
make yocto-dry-run YOCTO_IMAGE=core-image-optimal-tiny-initramfs
make yocto-build YOCTO_IMAGE=core-image-optimal-tiny-initramfs
```

Tạo SD boot media tiny trên host:

```bash
make sd-flash-tiny SDCARD=/dev/sdX
```

Lưu ý operator cho tiny path:

- `sd-flash-tiny` tạo một FAT boot partition duy nhất
- Tiny boot media chứa tên file ổn định:
  - `MLO`
  - `u-boot.img`
  - `zImage`
  - `am335x-boneblack-optimal-tiny.dtb`
  - `extlinux/extlinux.conf`
  - `uEnv.txt` (optional)
- Tiny path không dùng `.wic` hay ext4 rootfs partition riêng
- Tiny path vẫn cần chứng minh trên hardware qua UART boot logs

## Qt dashboard product path

Qt dashboard path là contract riêng ở lớp product. Nó không đổi nghĩa
contract của tiny path.

File contract public:

- `yocto/conf/bblayers.conf.qt-dashboard.example`
- `yocto/conf/local.conf.qt-dashboard.example`
- `meta-beaglebone-optimal/conf/machine/beaglebone-black-optimal-qt-dashboard.conf`
- `meta-beaglebone-optimal/recipes-kernel/linux/files-qt-dashboard/`
- `meta-beaglebone-optimal-product/conf/layer.conf`
- `meta-beaglebone-optimal-product/recipes-core/images/core-image-optimal-qt-dashboard.bb`
- `meta-beaglebone-optimal-product/recipes-core/packagegroups/packagegroup-optimal-dashboard.bb`
- `meta-beaglebone-optimal-product/recipes-qt/qt6/qtbase_%.bbappend`
- `meta-beaglebone-optimal-product/recipes-qt/qt-dashboard/qt-dashboard.bb`
- `meta-beaglebone-optimal-product/recipes-qt/qt-dashboard/files/qt-dashboard.sh`
- `qt-dashboard-app/`

Đường dẫn layer upstream kỳ vọng:

- `${YOCTO_SOURCES_DIR}/meta-qt6`

Luồng áp dụng config product thủ công:

```bash
make yocto-init

cd "$YOCTO_POKY_DIR"
source oe-init-build-env "$YOCTO_BUILD_DIR"

cp /workspace/yocto/conf/bblayers.conf.qt-dashboard.example conf/bblayers.conf
cat /workspace/yocto/conf/local.conf.qt-dashboard.example >> conf/local.conf
```

Build product image:

```bash
make yocto-parse
make yocto-qt-profile
make yocto-dry-run YOCTO_IMAGE=core-image-optimal-qt-dashboard
make yocto-build YOCTO_IMAGE=core-image-optimal-qt-dashboard
```

Flash product image BBB Black:

```bash
make sd-flash \
  YOCTO_MACHINE=beaglebone-black-optimal-qt-dashboard \
  YOCTO_IMAGE=core-image-optimal-qt-dashboard \
  SDCARD=/dev/sdX
```

Lưu ý operator:

- product path vẫn giữ BSP layer hiện tại ở `/workspace/meta-beaglebone-optimal`
- product path thêm `/workspace/meta-beaglebone-optimal-product` như một layer riêng
- product path này kỳ vọng `meta-qt6` nằm cạnh `poky`
- tiny vẫn headless; tiny không owner HDMI/display
- Layer BSP (`meta-beaglebone-optimal`) chứa định nghĩa machine và cấu hình phần cứng (DTS, kernel config, patch) cho màn hình HDMI, trong khi layer product (`meta-beaglebone-optimal-product`) chứa các cấu hình phần mềm Distro và ứng dụng dashboard.
- product path giờ target rõ BBB Black qua `beaglebone-black-optimal-qt-dashboard`, không dùng machine chung `beaglebone-yocto`
- runtime display default nằm trong `qt-dashboard.sh`
- build-time feature trimming nằm trong `local.conf.qt-dashboard.example` và `qtbase_%.bbappend`
- policy product loại bỏ desktop stack, audio, wifi, và zeroconf không phục vụ
  cho appliance fullscreen local-only
- launcher contract là một Qt Quick app fullscreen trên LinuxFB với software rendering

Checklist proof phía build:

```bash
make yocto-parse
make yocto-qt-profile
make yocto-dry-run YOCTO_IMAGE=core-image-optimal-qt-dashboard
make docker-run WORKSPACE_NAME=qt-dashboard CMD='cd "$$YOCTO_POKY_DIR" && source oe-init-build-env "$$YOCTO_BUILD_DIR" && bitbake gcc-source-13.4.0'
make docker-run WORKSPACE_NAME=qt-dashboard CMD='cd "$$YOCTO_POKY_DIR" && source oe-init-build-env "$$YOCTO_BUILD_DIR" && bitbake gcc'
make yocto-build WORKSPACE_NAME=qt-dashboard YOCTO_IMAGE=core-image-optimal-qt-dashboard
```

Checklist proof phía board HDMI:

```bash
ls -l /dev/fb0
systemctl status qt-dashboard
journalctl -u qt-dashboard -b --no-pager
```

Operator phải quan sát thêm:

- màn hình HDMI thật hiển thị dashboard fullscreen

Nếu product image không có `/dev/fb0`, coi đó là display gap của product path
và pause trước khi nới scope sang kernel hoặc device tree.

## RTC DS3231: chẩn đoán và khôi phục

Mục này áp dụng cho product image `beaglebone-black-optimal-qt-dashboard`.
Theo contract hiện tại, feature `RTC_DS3231` chỉ được bật cho machine product
này, không bật mặc định cho baseline hay tiny image.

Triệu chứng thường gặp trên board:

- dashboard hiện `RTC FAULT`
- đồng hồ hiện `--:--`
- `date` và `hwclock` cùng trả về năm cũ như `2000`

Lệnh chẩn đoán tối thiểu:

```bash
dmesg | grep -Ei 'rtc|ds3231|ds1307|i2c'
find /sys/firmware/devicetree/base -name 'rtc@68' 2>/dev/null
ls -l /dev/rtc*
date
hwclock -f /dev/rtc0 -r
```

Cách đọc kết quả:

- nếu `find ... rtc@68` không ra node nào, board không boot product image có
  `RTC_DS3231` hoặc device tree chưa mang feature RTC
- nếu `dmesg` không có dòng kiểu `rtc-ds1307 2-0068: registered as rtc0`, kernel
  chưa bind được DS3231
- nếu có `/dev/rtc0` và `hwclock -f /dev/rtc0 -r` đọc được nhưng năm nhỏ hơn
  `2024`, DS3231 đang hoạt động nhưng giữ thời gian rác; dashboard sẽ tự coi đó
  là fault
- nếu thiếu `/dev/i2c/2`, không coi đó là nguyên nhân gốc. Product image hiện
  vẫn có thể bind DS3231 qua kernel mà không expose thiết bị scan I2C cho
  userspace

Khôi phục khi RTC đang giữ thời gian sai:

```bash
date -s '2026-06-28 14:00:00'
hwclock -f /dev/rtc0 -w
hwclock -f /dev/rtc0 -r
reboot
date
```

Ghi chú operator:

- `date -s ...` sửa system clock hiện tại
- `hwclock -f /dev/rtc0 -w` ghi system clock xuống DS3231
- binary `/sbin/rtcsync` chỉ đồng bộ theo chiều `RTC -> system clock` lúc boot;
  nó không tự sửa RTC nếu chip đang giữ giờ sai

Nếu đã `hwclock -w` thành công nhưng cắt nguồn rồi board vẫn quay về năm cũ,
hãy nghi phần cứng backup của RTC:

- pin coin cell hết hoặc chưa gắn
- đường `VBAT` không có nguồn giữ
- module DS3231 lỗi phần cứng

### Thông điệp boot đã biết

**"Kernel memory protection not selected by kernel config."**

Nguồn: `init/main.c::mark_readonly()`

Ý nghĩa:
- Kiến trúc ARM hỗ trợ bảo vệ memory kernel (`CONFIG_ARCH_HAS_STRICT_KERNEL_RWX=y`)
- Tiny kernel cố ý tắt nó (`CONFIG_STRICT_KERNEL_RWX=n`)
- Trade-off: tiết kiệm ~200-300 KB vs. W^X kernel hardening

An toàn:
- Chấp nhận được cho learning board cô lập (không có network, không USB trong Phase 1)
- Protection ngăn code injection attacks và phát hiện memory corruption bugs sớm
- Nếu thêm network stack ở các phase sau, cân nhắc bật qua `hardening.cfg` fragment

Đây là lựa chọn cấu hình cố ý cho tiny profile, không phải lỗi.

## Đo thời gian boot (`make boot-capture`)

Áp dụng cho product path `beaglebone-black-optimal-qt-dashboard`. Công cụ này
đo thời gian boot thật (U-Boot → kernel → init → màn hình HDMI có nội dung)
bằng cách bắt log serial với timestamp chính xác gắn ở host, không phải đọc
bằng mắt trên minicom.

### Chạy

```bash
make boot-capture
# mặc định: BOOT_SERIAL_DEVICE=/dev/ttyUSB0, BOOT_SERIAL_BAUD=115200
# log lưu tại: tmp/boot-captures/latest.log
```

Nhấn `Ctrl-C` để dừng sau khi thấy dashboard lên màn hình.

### Cách hoạt động

`scripts/boot-capture.sh` chạy pipeline:

```text
cat /dev/ttyUSB0 | boot-capture-timestamp.pl /dev/ttyUSB0 | tee tmp/boot-captures/latest.log
```

`boot-capture-timestamp.pl` gắn timestamp `epoch.microsecond` vào **đầu mỗi
dòng**, kể cả dòng không kết thúc bằng `\n` (ví dụ shell prompt) — dùng
buffer + idle-timeout 100ms, và luôn stamp bằng **thời điểm byte cuối cùng
thực sự tới**, không phải lúc timeout hết hạn.

Script còn tự trả lời câu hỏi `ESC[6n` (cursor-position query) mà
`/etc/profile`'s `resize()` gửi ra lúc login lần đầu trên serial console —
nếu không trả lời, `read -t 2` phải chờ hết 2 giây timeout, làm số đo bị
thổi phồng giả tạo ~2-3s so với trải nghiệm thật (dùng terminal thật như
minicom thì không có delay này vì terminal tự trả lời tức thì).

### QUAN TRỌNG: luôn đọc file log, không đọc màn hình live

`resize()` gửi lệnh di chuyển con trỏ (`ESC[999;999H`) ra thẳng serial.
Nếu bạn nhìn/copy trực tiếp trên terminal đang chạy `make boot-capture`,
terminal của bạn có thể tự thực thi lệnh đó và tự trả lời, làm màn hình
hiển thị bị rối (chữ dính vào nhau, ký tự lạ như `^[[36;153R`). Đây không
phải lỗi của tool — luôn kiểm tra bằng:

```bash
cat -v tmp/boot-captures/latest.log | tail -20
```

### Mốc "màn hình HDMI có nội dung"

`qt-dashboard-app/src/main.cpp` hook vào `QQuickWindow::frameSwapped` (frame
đầu tiên), ghi một dòng qua `/dev/kmsg` (vì stdio của `qt-dashboard` bị null
theo `inittab`) với priority `<3>` (KERN_ERR — bắt buộc, vì cờ `quiet` trong
`extlinux.conf` set `console_loglevel=4`, priority `4` sẽ bị nuốt câm lặng).
Kernel tự gắn tiền tố `[  N.NNNNNN]` (nhờ `CONFIG_PRINTK_TIME=y`) nên không
cần code tự đọc đồng hồ. Dòng log sẽ là:

```text
[    4.689948] qt-dashboard: first frame rendered
```

Đây là marker phần mềm chính xác nhất có thể đạt được mà không cần thêm
phần cứng đo — sai số còn lại (~16-30ms, từ chu kỳ scan-out HDMI + độ trễ
màn hình vật lý) chỉ đo được bằng camera/photodiode, không thể khắc phục
bằng phần mềm.

### Đọc kết quả

Grep các mốc chính trong log (`cat -v ... | grep -E "Starting kernel|sh -l|first frame"`),
lấy timestamp epoch của từng dòng rồi trừ cho nhau:

| Giai đoạn | Ví dụ đo được |
|---|---|
| SPL start → `Starting kernel...` (U-Boot) | ~1.05s |
| `Starting kernel...` → shell prompt (kernel + init) | ~1.33s |
| Shell prompt → `first frame rendered` (Qt app) | ~3.90s |

Trong lần đo mẫu này, **Qt app chiếm ~62% tổng thời gian boot** — đây là nơi
nên tối ưu trước nếu cần giảm thời gian tới lúc màn hình sáng, không phải
U-Boot/kernel.

## Runtime contract

Compose service hiện tại tên là `builder`.

Runtime contract quan trọng:

- image: `${DOCKER_IMAGE}:${DOCKER_TAG}`
- source bind mount: `.:/workspace`
- storage bind mount: `${PROJECT_STORAGE_ROOT}:/storage`
- user map theo host: `${DOCKER_USER}`
- env trong container:
  - `PROJECT_STORAGE_ROOT=/storage`
  - `WORKSPACE_NAME=${WORKSPACE_NAME}`
  - `YOCTO_ROOT=/storage/workspaces/${WORKSPACE_NAME}/yocto`
  - `YOCTO_SOURCES_DIR=/storage/workspaces/${WORKSPACE_NAME}/yocto/sources`
  - `YOCTO_POKY_DIR=/storage/workspaces/${WORKSPACE_NAME}/yocto/sources/poky`
  - `YOCTO_BUILD_DIR=/storage/workspaces/${WORKSPACE_NAME}/yocto/build`
  - `YOCTO_DOWNLOADS_DIR=/storage/shared/downloads`
  - `YOCTO_SSTATE_DIR=/storage/shared/sstate`
  - `YOCTO_IMAGE=${YOCTO_IMAGE}`

## Image contract

`docker/Dockerfile` hiện tại:

- dùng `ubuntu@sha256:...` pin theo digest
- cài bộ toolchain và build deps cho builder
- dùng `--no-install-recommends`
- cleanup apt lists
- pin `dtschema==2026.4`
- dùng `WORKDIR /workspace`
- default command là `bash`

Không có:

- `ENTRYPOINT`
- `HEALTHCHECK`
- `EXPOSE`
- hardcoded APT mirror local
- hardcoded fixed runtime user

## Luồng vận hành khuyến nghị

### Lần đầu trên máy mới

```bash
cp local.mk.example local.mk
$EDITOR local.mk
make doctor
make docker-shell
```

### Sau khi sửa Dockerfile

```bash
make docker-build
make doctor
```

### Chạy lệnh kiểm tra nhanh

```bash
make docker-run CMD='uname -a'
make docker-run CMD='python3 --version'
```

## Lỗi thường gặp

### `PROJECT_STORAGE_ROOT is required`

Nguyên nhân:

- chưa tạo `local.mk`
- chưa export biến

Sửa:

```bash
cp local.mk.example local.mk
```

Rồi đặt:

```make
PROJECT_STORAGE_ROOT := /absolute/path
```

### `PROJECT_STORAGE_ROOT must be an absolute path`

Nguyên nhân:

- dùng path tương đối

Sai:

```make
PROJECT_STORAGE_ROOT := tmp/build
```

Đúng:

```make
PROJECT_STORAGE_ROOT := /mnt/data/beaglebone-optimal
```

### `CMD is required`

Nguyên nhân:

- gọi `make docker-run` nhưng không truyền `CMD`

Đúng:

```bash
make docker-run CMD='uname -a'
```

### `make doctor` fail ở bước ghi `/storage`

Nguyên nhân thường gặp:

- path host không writable
- user hiện tại không có quyền với thư mục đó
- Docker daemon chạy nhưng bind mount target không phù hợp

Cách xử lý:

1. kiểm tra `PROJECT_STORAGE_ROOT` trong `local.mk`
2. kiểm tra quyền ghi của user host lên path đó
3. chạy lại:

```bash
make doctor
```

### Shell hiện `I have no name!`

Ý nghĩa:

- container vẫn chạy đúng
- mapping UID/GID host không có entry tên tương ứng trong image

Ảnh hưởng:

- chủ yếu là cosmetic ở prompt shell
- không chặn `docker-shell`, `docker-run`, hay `doctor`

Hiện trạng:

- đây là known follow-up, không phải blocker phase 1

## Không nên làm

- không ghi artifact build vào source tree
- không hardcode local path như `/mnt/data/...` vào file tracked
- không chỉnh runtime contract trực tiếp trong README mà quên sync với
  `Makefile`, `compose.yaml`, `scripts/docker/*.sh`
- không dùng `rtk` trong repo docs hay repo scripts

## Khi cần sửa contract

Nếu sửa behavior Docker phase 1, phải kiểm tra tối thiểu:

```bash
docker compose config
make help
make docker-build
make doctor
make docker-run CMD='uname -a'
```

## Nguồn sự thật

Khi doc này mâu thuẫn với code, ưu tiên đọc theo thứ tự:

1. `Makefile`
2. `scripts/docker/lib.sh`
3. `scripts/docker/doctor.sh`
4. `compose.yaml`
5. `docker/Dockerfile`
