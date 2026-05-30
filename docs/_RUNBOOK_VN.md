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
            └── build/
```

Ý nghĩa:

- `shared/` giữ cache có thể tái sử dụng
- `workspaces/<name>/` giữ output và state riêng của workspace hiện tại

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
