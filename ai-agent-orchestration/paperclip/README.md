# Paperclip - AI Agent Control Plane

## ✅ Yêu cầu

- Linux (Ubuntu, Debian, Fedora...) hoặc Windows + WSL2
- Docker Engine + Docker Compose plugin (`docker compose version`). Trên WSL: Docker Desktop với WSL integration, hoặc Docker cài trong distro
- User có quyền chạy Docker không cần sudo (`sudo usermod -aG docker $USER`, rồi đăng nhập lại)
- `bash`, `openssl` (hoặc `python3`)

---

## 🚀 Chạy Paperclip

Mọi thao tác dùng 1 script `scripts/run.sh` (chạy trong terminal Linux / WSL):

```bash
cd <repo>/ai-agent-orchestration/paperclip

./scripts/run.sh --setup      # Lần đầu (máy mới / vừa clone repo)
./scripts/run.sh              # Bật Paperclip
./scripts/run.sh --refresh    # Cập nhật lên image mới nhất
./scripts/run.sh --help       # Xem hướng dẫn
```

| Lệnh | Khi nào dùng | Làm gì |
|---|---|---|
| `run.sh --setup` | **Chỉ lần đầu** trên máy mới | Kiểm tra Docker → tạo `.env` + sinh 2 secrets (32-byte hex) + đặt `PAPERCLIP_DATA_DIR=$HOME/paperclip-data` → tạo data dir → chạy. `.env` đã có thì giữ nguyên, nên chạy lại cũng an toàn |
| `run.sh` | Khi Paperclip đang tắt, hoặc sau khi sửa `.env` / `docker-compose.yml` | `docker compose up -d` và chờ container healthy |
| `run.sh --refresh` | Muốn cập nhật Paperclip | `docker compose pull` → tạo lại container. Dữ liệu và đăng nhập AI giữ nguyên |

Mỗi lần chạy, `run.sh` ghi `USER_UID`/`USER_GID` của user hiện tại vào `.env`; container dùng UID này nên data dir trên host luôn thuộc về bạn (kể cả máy có UID khác 1000).

> **Hằng ngày không cần chạy gì:** container có `restart: unless-stopped`, tự bật lại khi Docker khởi động.
>
> **Chuyển sang máy khác có backup?** Đừng chạy `--setup` (sẽ sinh secrets mới, không đọc được dữ liệu cũ). Dùng `./scripts/restore.sh` — xem [Data Persistence & Backup](#-data-persistence--backup).

Sau khi setup, kết nối Claude theo mục [Kết nối Claude](#-kết-nối-claude-subscription-promax) bên dưới.

---

## 🔑 Kết nối Claude Subscription (Pro/Max)

Paperclip tự quản lý đăng nhập cho từng AI connection (lưu trong data dir). Login `claude` trên máy host **không** được dùng. Image đã có sẵn Claude Code CLI.

1. Để trống `ANTHROPIC_API_KEY=""` trong `.env` (có key thì sẽ bị tính phí theo token).
2. Dashboard → **Connectors** → **Anthropic** → **Add account** (hoặc **Reconnect**) → chọn **Claude Subscription**.
3. Paperclip hiển thị lệnh dạng `(export CLAUDE_CONFIG_DIR='/paperclip/instances/default/ai-local-logins/<id>' && mkdir -p ... && claude auth login)`. Chạy nó **trong container**:
   ```bash
   docker exec -it -u node paperclip-server sh -c 'export CLAUDE_CONFIG_DIR=/paperclip/instances/default/ai-local-logins/<id> && mkdir -p "$CLAUDE_CONFIG_DIR" && claude auth login'
   ```
4. Mở URL được in ra, đăng nhập claude.ai, dán code lại vào terminal.
5. Quay lại trang Connect → **Connect**. Connection chuyển sang **Connected**.
6. Agent → **Harness / Runtime** → Adapter **Claude Code**, AI connection **My Claude subscription** → **Run test**.

> Nếu connection báo **Needs attention**, lặp lại từ bước 2 với **Reconnect**. Gói subscription có giới hạn sử dụng theo 5 giờ / tuần — chạy nhiều agent song song sẽ chạm giới hạn nhanh hơn.

### ⚠️ Gemini / Google AI Pro

Gói Google AI Pro **không** dùng được qua adapter Gemini CLI: Google trả về `IneligibleTierError: This client is no longer supported for Gemini Code Assist for individuals` (yêu cầu chuyển sang Antigravity, mà Paperclip chưa có adapter). Muốn dùng Gemini thì tạo API key tại [aistudio.google.com](https://aistudio.google.com/apikey) (tính phí riêng, không dùng quota AI Pro), lưu vào **Secrets & variables** của agent và đặt env `GEMINI_API_KEY`.

---

## 🛠️ Setup thủ công (nếu không dùng script)

### Bước 1: Tạo file `.env` từ template

```bash
# Copy template
cp .env.example .env

# Sinh 2 secret keys ngẫu nhiên (chạy 2 lần để lấy 2 keys)
openssl rand -hex 32
```

Mở `.env` và điền:
- `BETTER_AUTH_SECRET` — secret key 1 vừa sinh
- `PAPERCLIP_TOOL_ACTION_SIGNING_SECRET` — secret key 2 vừa sinh
- `PAPERCLIP_DATA_DIR` — thư mục data trên ổ Linux, ví dụ `/home/<user>/paperclip-data` (**không** dùng `/mnt/<ổ>`)
- `USER_UID`, `USER_GID` — kết quả `id -u` / `id -g`
- `OPENAI_API_KEY`, `ANTHROPIC_API_KEY` — tuỳ chọn, để `""` nếu kết nối tài khoản qua UI → Connectors (bắt buộc để trống `ANTHROPIC_API_KEY` khi dùng Claude Subscription)

### Bước 2: Chạy Docker Compose

```bash
docker compose up -d
```

### Bước 3: Truy cập Dashboard

Mở trình duyệt: **http://localhost:3100**

---

## 📋 Quản lý

```bash
# Bật / cập nhật
./scripts/run.sh
./scripts/run.sh --refresh

# Xem logs thời gian thực
docker compose logs -f

# Dừng container
docker compose down

# Reset toàn bộ data về ban đầu (mất hết agents, tasks, đăng nhập AI)
docker compose down
sudo rm -rf ~/paperclip-data
```

---

## 💾 Data Persistence & Backup

### Dữ liệu lưu ở đâu?

Tất cả dữ liệu Paperclip (DB, org chart, tasks, settings, secrets, đăng nhập AI connection) nằm ở `PAPERCLIP_DATA_DIR` trong `.env` — mặc định `~/paperclip-data`, **không** nằm trong repo:

```
~/paperclip-data/          ← ⚠️ TOÀN BỘ dữ liệu Paperclip (bind mount → /paperclip)
└── instances/default/
    ├── db/                ← Database
    ├── secrets/           ← Secrets (gồm credentials AI connection sau khi Connect)
    ├── ai-local-logins/   ← Thư mục tạm cho bước `claude auth login`
    └── ...

paperclip/ (repo)
├── .env                   ← Secrets + PAPERCLIP_DATA_DIR
├── scripts/               ← run.sh, backup.sh, restore.sh
└── backups/               ← Các bản backup (gitignored)
```

> Data dir phải nằm trên ổ Linux: NTFS (`/mnt/c`, `/mnt/e`...) không hỗ trợ `chmod 0700` mà Paperclip cần. Bind mount nên dữ liệu **không mất** khi `docker compose down -v`.

### Backup (1 lệnh)

```bash
./scripts/backup.sh
# → Tạm dừng container, nén data dir thành ./backups/paperclip_backup_YYYY-MM-DD_HH-mm-ss/data.tar.gz
#   (giữ nguyên owner/permission) + copy .env, rồi chạy lại container
```

### Restore (1 lệnh)

```bash
./scripts/restore.sh
# → Chọn backup → dừng container → ghi đè data dir từ data.tar.gz + khôi phục .env → khởi động lại
```

### Di chuyển sang máy khác

```bash
# Máy cũ
./scripts/backup.sh
# Copy thư mục backups/<bản backup>/ sang máy mới, đặt vào <repo>/ai-agent-orchestration/paperclip/backups/

# Máy mới (KHÔNG chạy run.sh --setup trước)
./scripts/restore.sh
```

Restore giữ nguyên secrets trong `.env` cũ (bắt buộc để đọc được dữ liệu đã mã hoá), nhưng tự đổi `PAPERCLIP_DATA_DIR` và `USER_UID`/`USER_GID` theo máy mới (`$HOME/paperclip-data` nếu chưa có `.env`). Khác user / khác UID vẫn dùng được.


---

## 🏗️ Cấu hình Org Chart cho team AI

Sau khi vào Dashboard, tạo Org Chart như sau:

```
👤 CEO (Bạn - Human Approval)
├── 🤖 Architect    → Antigravity (webhook)
├── 🟣 Engineer     → Claude Code (CLI runtime)
├── 🟢 QA           → GPT Codex (CLI runtime)
└── 🤖 Tech Writer  → Antigravity (webhook)
```

> Antigravity cần adapter HTTP/webhook — hiện Paperclip đánh dấu **Coming soon**. Trong lúc chờ, dùng Claude Code cho các vai trò này.

### Thiết lập budget caps gợi ý:
- Engineer (Claude Code): 200K tokens/task
- QA (Codex): 100K tokens/task
- Architect: 50K tokens/task

### Bật Approval Gates cho:
- Deploy / Merge PR
- Budget vượt ngưỡng
- Task liên quan đến security

---

## 🔗 Tham khảo

- [GitHub](https://github.com/paperclipai/paperclip)
- [Documentation](https://paperclip.ing)
