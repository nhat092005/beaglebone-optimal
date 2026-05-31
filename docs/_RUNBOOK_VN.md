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
