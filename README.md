# Seminar Link

Ứng dụng Rails dùng để upload file trình chiếu, quản lý danh sách tài liệu và mở màn hình trình chiếu qua link chia sẻ. Ứng dụng hỗ trợ:

- Upload file `.pdf` và `.pptx` tối đa 50 MB.
- Tự convert `.pptx` sang PDF bằng LibreOffice chạy headless.
- Lưu file bằng Active Storage trên ổ đĩa local.
- Chạy background job bằng Solid Queue.
- Dùng SQLite trong thư mục `storage/`.

## 1. Yêu cầu hệ thống

Server khuyến nghị: Ubuntu 22.04/24.04 hoặc Debian tương đương.

Phần mềm cần có:

- Ruby đúng phiên bản trong `.ruby-version`: `ruby-4.0.5`.
- Bundler.
- SQLite 3.
- LibreOffice để convert PowerPoint sang PDF.
- libvips để Rails xử lý file/preview qua Active Storage.
- Git.
- Docker nếu deploy bằng Docker/Kamal.

Cài các gói hệ thống thường dùng trên Ubuntu/Debian:

```bash
sudo apt update
sudo apt install -y git curl build-essential pkg-config libyaml-dev sqlite3 libsqlite3-dev libvips42 libvips-tools libreoffice fontconfig fonts-dejavu fonts-liberation
```

Kiểm tra LibreOffice:

```bash
which soffice
soffice --version
```

Ứng dụng tìm LibreOffice tại `/usr/bin/soffice` trên Linux. Nếu lệnh `which soffice` không trả về đường dẫn này, chức năng convert `.pptx` sẽ lỗi.

## 2. Biến môi trường bắt buộc

Production cần `RAILS_MASTER_KEY` để giải mã `config/credentials.yml.enc`.

Trên server, tạo biến môi trường:

```bash
export RAILS_MASTER_KEY="<noi-dung-file-config/master.key>"
```

Không commit hoặc public file `config/master.key`.

Biến môi trường nên có:

```bash
export RAILS_ENV=production
export SOLID_QUEUE_IN_PUMA=true
```

`SOLID_QUEUE_IN_PUMA=true` cho phép Solid Queue chạy worker trong tiến trình Puma. Nếu tách worker riêng, chạy thêm:

```bash
bin/jobs
```

## 3. Cài đặt chạy trực tiếp trên server

Clone source:

```bash
git clone <repo-url> seminar-link
cd seminar-link
```

Nếu chạy trực tiếp trên Linux, chuẩn hóa các file thực thi trong `bin/` vì source hiện được tạo trên Windows:

```bash
chmod +x bin/*
sed -i "s/\r$//g" bin/*
sed -i 's/ruby\.exe$/ruby/' bin/*
```

Cài Ruby `4.0.5` bằng công cụ quản lý Ruby đang dùng trên server, ví dụ `rbenv`, `asdf` hoặc Ruby package nội bộ. Sau đó kiểm tra:

```bash
ruby -v
```

Cài gem:

```bash
gem install bundler
bundle install
```

Chuẩn bị database:

```bash
RAILS_ENV=production RAILS_MASTER_KEY="$RAILS_MASTER_KEY" bin/rails db:prepare
```

Precompile assets:

```bash
RAILS_ENV=production RAILS_MASTER_KEY="$RAILS_MASTER_KEY" bin/rails assets:precompile
```

Chạy app:

```bash
RAILS_ENV=production \
RAILS_MASTER_KEY="$RAILS_MASTER_KEY" \
SOLID_QUEUE_IN_PUMA=true \
bin/rails server -b 0.0.0.0 -p 3000
```

Sau đó mở:

```text
http://<server-ip>:3000
```

Health check:

```text
http://<server-ip>:3000/up
```

## 4. Dữ liệu cần backup

Ứng dụng đang dùng SQLite và Active Storage local, nên dữ liệu quan trọng nằm trong:

```text
storage/
```

Trong production, thư mục này chứa:

- `production.sqlite3`: database chính.
- `production_cache.sqlite3`: cache.
- `production_queue.sqlite3`: hàng đợi job.
- `production_cable.sqlite3`: dữ liệu cable nếu có.
- File upload và PDF sau convert của Active Storage.

Khi deploy, bắt buộc giữ persistent volume hoặc backup thư mục `storage/`. Nếu xóa thư mục này sẽ mất database và file đã upload.

## 5. Deploy bằng Docker

Build image:

```bash
docker build -t seminar_link .
```

Chạy container:

```bash
docker volume create seminar_link_storage

docker run -d \
  --name seminar_link \
  -p 80:80 \
  -e RAILS_MASTER_KEY="$RAILS_MASTER_KEY" \
  -e SOLID_QUEUE_IN_PUMA=true \
  -v seminar_link_storage:/rails/storage \
  seminar_link
```

Kiểm tra:

```bash
docker logs -f seminar_link
curl http://127.0.0.1/up
```

Lưu ý quan trọng: Dockerfile hiện tại phục vụ Rails production nhưng chưa cài LibreOffice trong image. Nếu deploy bằng Docker và cần convert `.pptx`, hãy bổ sung gói `libreoffice`, `fontconfig`, `fonts-dejavu`, `fonts-liberation` vào phần `apt-get install` của stage `base`, sau đó build lại image. Kiểm tra trong container:

```bash
docker exec seminar_link which soffice
```

Nếu không có `/usr/bin/soffice`, upload PDF vẫn dùng được nhưng convert PowerPoint sẽ thất bại.

## 6. Deploy bằng Kamal

File cấu hình chính:

```text
config/deploy.yml
.kamal/secrets
```

Trước khi deploy cần sửa `config/deploy.yml`:

- `servers.web`: đổi `192.168.0.1` thành IP server thật.
- `registry.server`: đổi sang registry Docker thật nếu không dùng registry local.
- `image`: đổi theo tên image muốn push, ví dụ `your-registry/seminar_link`.
- `proxy.host`: bật và cấu hình domain nếu dùng HTTPS qua Kamal proxy.

File `.kamal/secrets` đang đọc:

```bash
RAILS_MASTER_KEY=$(cat config/master.key)
```

Vì `config/master.key` không nên nằm trên git, máy chạy lệnh deploy phải có file này hoặc phải export `RAILS_MASTER_KEY` trước khi chạy Kamal.

Deploy:

```bash
bin/kamal setup
bin/kamal deploy
```

Xem log:

```bash
bin/kamal logs
```

Mở shell trong container:

```bash
bin/kamal shell
```

Kamal đã cấu hình volume:

```text
seminar_link_storage:/rails/storage
```

Không xóa volume này nếu không muốn mất database và file upload.

## 7. Cấu hình reverse proxy

Nếu chạy app ở port `3000` sau Nginx, cấu hình Nginx mẫu:

```nginx
server {
  listen 80;
  server_name example.com;

  client_max_body_size 60m;

  location / {
    proxy_pass http://127.0.0.1:3000;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
}
```

Nếu bật HTTPS tại reverse proxy, cân nhắc bật trong `config/environments/production.rb`:

```ruby
config.assume_ssl = true
config.force_ssl = true
```

## 8. Kiểm tra sau khi cài đặt

1. Mở trang chủ và upload thử một file PDF.
2. Kiểm tra file chuyển sang trạng thái `Sẵn sàng`.
3. Upload thử một file `.pptx`.
4. Kiểm tra log nếu trạng thái là `Lỗi`:

```bash
tail -f log/production.log
```

Nếu chạy Docker:

```bash
docker logs -f seminar_link
```

Kiểm tra database:

```bash
RAILS_ENV=production RAILS_MASTER_KEY="$RAILS_MASTER_KEY" bin/rails db:migrate:status
```

## 9. Lệnh vận hành thường dùng

Migrate database:

```bash
RAILS_ENV=production RAILS_MASTER_KEY="$RAILS_MASTER_KEY" bin/rails db:migrate
```

Rails console:

```bash
RAILS_ENV=production RAILS_MASTER_KEY="$RAILS_MASTER_KEY" bin/rails console
```

Xóa cache/tmp:

```bash
RAILS_ENV=production RAILS_MASTER_KEY="$RAILS_MASTER_KEY" bin/rails tmp:clear
```

Kiểm tra bảo mật và style ở môi trường phát triển:

```bash
bin/ci
```

## 10. Lỗi thường gặp

`soffice binary not found`

- Server/container chưa cài LibreOffice.
- Cài `libreoffice` và kiểm tra lại `which soffice`.

Convert `.pptx` bị lỗi font hoặc lệch layout

- Cài thêm font tương thích với file trình chiếu.
- Tối thiểu nên có `fonts-dejavu` và `fonts-liberation`.

Upload file xong nhưng mãi ở trạng thái `Đang chờ` hoặc `Đang convert`

- Kiểm tra `SOLID_QUEUE_IN_PUMA=true`.
- Nếu chạy worker riêng, kiểm tra tiến trình `bin/jobs`.
- Kiểm tra database queue trong `storage/production_queue.sqlite3`.

Mất dữ liệu sau deploy lại

- Chưa mount persistent volume cho `/rails/storage`.
- Kiểm tra lại cấu hình volume Docker/Kamal và backup thư mục `storage/`.

Lỗi `Missing secret_key_base` hoặc lỗi credentials

- Thiếu `RAILS_MASTER_KEY`.
- Kiểm tra biến môi trường hoặc file `config/master.key` trên máy deploy.
