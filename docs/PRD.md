# BamboOS — Product Requirements Document

**One-liner:** Một bản Arch Linux tối giản, cấu hình sẵn "đẹp ngay out-of-the-box", chỉ gồm những gì một developer cần: terminal đẹp, Chrome, trình xem video, quay màn hình — điều khiển hoàn toàn bằng bàn phím theo phong cách Omarchy.

- Version: 0.1 (Draft)
- Date: 2026-11-26
- Status: Ready for implementation

## 1. Tầm nhìn (Vision)

BamboOS là "chiếc xe đạp" của thế giới Linux distro: nhẹ, đơn giản, không có gì thừa, và chạy đúng như mong đợi. Lấy cảm hứng từ Omarchy (Arch + Hyprland được cấu hình sẵn một cách có chủ kiến), nhưng đi xa hơn về sự tối giản:

- Không desktop environment — chỉ có Hyprland (tiling Wayland compositor)
- Không app store, không bloatware — chỉ 4 nhóm công cụ: terminal, browser, media, system
- Keyboard-first — mọi thao tác chính đều có phím tắt, chuột là tùy chọn
- Đẹp mặc định — dark mode charcoal, viền hairline, font Inter + JetBrains Mono, accent xanh dương/cam/xanh lá (design language "Tessera")
- Agent-ready — môi trường sạch, nhẹ, dự đoán được; lý tưởng để chạy AI coding agents (Claude Code, Cursor CLI...) trong terminal hoặc container

## 2. Mục tiêu & Phi mục tiêu

### Goals (P0)

- Boot từ USB → vào thẳng môi trường desktop dùng được ngay (live session), không cần cài đặt
- Trải nghiệm "Try BamboOS": tải ISO → flash USB → boot → dùng thử trong 5 phút
- Terminal đẹp ngay lần mở đầu tiên: theme đồng bộ, font ligature, prompt cấu hình sẵn
- Bộ phím tắt thống nhất phong cách Omarchy (Super là trung tâm)
- Chrome có sẵn, mpv có sẵn, quay màn hình có sẵn
- Cài đặt lên ổ cứng bằng một lệnh duy nhất

### Non-goals (rõ ràng KHÔNG làm)

- Không office suite, email client, photo editor
- Không GUI settings app — mọi config là file text + dotfiles repo
- Không hỗ trợ dual-GPU/NVIDIA ở v0.1 (Wayland + NVIDIA còn nhiều ma sát)
- Không tự build kernel, không fork package nào của Arch
- Không phải distro cho người mới dùng Linux lần đầu

## 3. Đối tượng người dùng

| Persona | Nhu cầu chính |
| --- | --- |
| Developer thích tối giản | Môi trường dev sạch, nhanh, không rối mắt, kiểm soát 100% bằng phím |
| Người chạy AI agents | Máy/VM nhẹ để agents chạy terminal + browser headless, ít attack surface |
| Fan của Omarchy muốn nhẹ hơn | Omarchy nhưng ít package hơn, config đơn giản hơn, dễ fork |

## 4. Kiến trúc kỹ thuật

### 4.1. Stack nền

| Lớp | Lựa chọn | Ghi chú |
| --- | --- | --- |
| Base | Arch Linux (rolling) | Không fork, dùng repo chính chủ |
| Compositor | Hyprland (Wayland) | Tiling WM, animation mượt, config bằng text |
| Display manager | Không có (auto-login TTY → Hyprland) hoặc greetd | Giữ tối giản |
| Shell | zsh + starship prompt | Theme đồng bộ BamboOS |
| Terminal | kitty (hoặc foot) | GPU-accelerated, hỗ trợ ligature |
| Browser | Google Chrome (AUR) hoặc Chromium | Cài sẵn, icon trong launcher |
| Media player | mpv | Xem mọi định dạng video |
| Screen recorder | wf-recorder (+ slurp chọn vùng) | Quay màn hình Wayland, gọi bằng phím tắt |
| Screenshot | grim + slurp | Chụp màn hình |
| Launcher | walker hoặc rofi-wayland | Super+Space |
| Bar | waybar | Hiển thị workspace, CPU/RAM, pin, giờ |
| Fonts | Inter (UI) + JetBrains Mono (terminal/code) | Cài sẵn trong ISO |
| Build ISO | archiso | Chuẩn của Arch, dễ reproduce |
| Installer | Script TUI (gum) 1 lệnh | `bambo-install` |

### 4.2. Design language ("Tessera")

Áp dụng thống nhất cho: Hyprland border, waybar, launcher, terminal theme, wallpaper.

| Token | Giá trị |
| --- | --- |
| Background | `#101012` (charcoal) |
| Surface | `#161618` |
| Border (hairline) | `rgba(255,255,255,0.08)`, 1px |
| Text primary | `#f4f4f5` |
| Text muted | `#8e8e96` |
| Accent blue (info/focus) | `#5b8def` |
| Accent orange (warning) | `#ff8a4c` |
| Accent green (success) | `#3ecf8e` |
| UI font | Inter |
| Mono font | JetBrains Mono (bật ligature) |
| Border radius | 12px |
| Focused window border | accent blue, 1px |

## 5. Yêu cầu chức năng (Functional Requirements)

### FR-1: Live session "Try BamboOS" — P0

- ISO boot ở chế độ live: vào thẳng desktop Hyprland, không hỏi password
- Live session có đủ 100% tính năng của bản cài (trừ lưu trữ persistent)
- Trên desktop có 1 shortcut/launcher duy nhất: "Install BamboOS" → chạy `bambo-install`
- ISO chạy được trong VM (QEMU/VMware/UTM) để thử nhanh không cần USB

### FR-2: Installer 1 lệnh — P0

- `bambo-install`: TUI (dùng gum) hỏi 4 thứ: ổ đĩa, hostname, username, password
- Tự phân vùng (ext4, có tùy chọn encryption ở v0.2)
- Cài xong reboot vào desktop, auto-login lần đầu
- Thời gian cài mục tiêu: < 10 phút trên máy có SSD

### FR-3: Terminal experience — P0

- Mở terminal (Super+Enter) ra ngay: prompt starship đẹp, hiển thị git branch, viền/cửa sổ đúng theme
- Alias hữu ích có sẵn: `ll`, `gs` (git status), `..`, `update` (pacman -Syu)
- Cài sẵn: git, curl, wget, tmux, htop/btop, ripgrep, fzf, jq, unzip
- Font JetBrains Mono + ligature mặc định

### FR-4: Browser — P0

- Chrome (hoặc Chromium) cài sẵn, mở bằng Super+B
- Chạy native Wayland (không XWayland) để không bị mờ font

### FR-5: Media & quay/chụp màn hình — P0

- mpv mở được mọi file video phổ biến
- Super+Shift+S: chụp màn hình vùng chọn → lưu `~/Pictures/` + copy clipboard
- Super+Shift+R: bật/tắt quay màn hình (wf-recorder) → lưu `~/Videos/`, có indicator đỏ trên waybar khi đang quay

### FR-6: Hệ thống phím tắt — P0

Triết lý: Super là trung tâm, học theo Omarchy, tối đa 2 phím cho 90% thao tác.

| Phím tắt | Hành động |
| --- | --- |
| Super + Enter | Mở terminal |
| Super + B | Mở browser |
| Super + Space | App launcher |
| Super + Q | Đóng cửa sổ |
| Super + F | Fullscreen |
| Super + V | Toggle floating/tiling |
| Super + 1..9 | Chuyển workspace |
| Super + Shift + 1..9 | Di chuyển cửa sổ sang workspace |
| Super + H/J/K/L | Di chuyển focus (kiểu vim) |
| Super + Shift + H/J/K/L | Đổi vị trí cửa sổ |
| Super + Shift + S | Screenshot vùng chọn |
| Super + Shift + R | Toggle quay màn hình |
| Super + L | Khóa màn hình |
| Super + Shift + E | Menu power (logout/reboot/shutdown) |
| Super + / | Hiển thị cheat sheet phím tắt (popup) |

### FR-7: Waybar (thanh trạng thái) — P1

- Hiển thị: workspaces, window title, CPU, RAM, network, pin (nếu laptop), giờ
- Style theo design tokens §4.2, module đang quay màn hình thì hiện chấm đỏ nhấp nháy

### FR-8: Agent-ready environment — P1

- Cài sẵn: docker (hoặc podman), node LTS (nvm), python + uv, go (tùy chọn)
- Cấu hình sẵn tmux với prefix hợp lý để agents chạy session dài
- Tài liệu hướng dẫn chạy headless: `bambo-agent` script khởi tạo môi trường không-GUI (tắt Hyprland, chỉ TTY) cho máy chủ/VM chạy agents

## 6. Yêu cầu phi chức năng (Non-functional)

| Chỉ số | Mục tiêu |
| --- | --- |
| Dung lượng ISO | ≤ 2.5 GB |
| RAM khi idle (desktop) | ≤ 800 MB |
| Thời gian boot → desktop | ≤ 10s trên SSD (live USB: ≤ 30s) |
| Số package cài sẵn | ≤ 250 (đếm bằng `pacman -Q`) |
| Reproducible build | `make iso` build ra ISO từ repo config, không bước thủ công |
| Update | Theo Arch rolling, không tự duy trì repo riêng ở v0.1 |

## 7. Cấu trúc repo (đề xuất)

```
bambo-os/
├── iso/                  # archiso profile
│   ├── packages.x86_64   # danh sách package
│   └── airootfs/         # file đè vào root filesystem
├── config/
│   ├── hyprland/         # hyprland.conf + keybindings
│   ├── kitty/            # terminal theme
│   ├── waybar/
│   ├── starship.toml
│   ├── zshrc
│   └── walker/
├── scripts/
│   ├── bambo-install     # installer TUI
│   ├── bambo-agent       # chế độ headless cho agents
│   └── bambo-keys        # cheat sheet popup
├── themes/tessera/       # design tokens, wallpaper
├── Makefile              # make iso / make test-vm
└── docs/
```

## 8. Milestones

| Phase | Nội dung | Tiêu chí xong |
| --- | --- | --- |
| M1 — MVP live ISO | archiso profile + Hyprland + terminal theme + keybindings + Chrome + mpv + wf-recorder | Boot ISO trong QEMU, mở terminal/browser/quay màn hình được, đúng theme |
| M2 — Installer | `bambo-install` TUI, cài lên ổ thật | Cài thành công trên VM sạch, reboot vào desktop |
| M3 — Polish | waybar hoàn chỉnh, cheat sheet, wallpaper, docs | Không cần đọc docs vẫn dùng được trong 10 phút |
| M4 — Agent mode | `bambo-agent`, docker, runtimes | Chạy được Claude Code trong VM headless |
| M5 — Public | Website tải ISO, checksum, hướng dẫn flash USB | Người lạ tải về dùng thử được không cần hỏi |

## 9. Rủi ro & câu hỏi mở

- Terminal: kitty vs foot vs ghostty? Đề xuất: kitty cho v0.1.
- Chrome vs Chromium? Đề xuất: Chromium cho ISO, hướng dẫn cài Chrome sau.
- NVIDIA — v0.1 bỏ qua, ghi rõ trong docs.
- Secure Boot — bỏ qua v0.1, hướng dẫn tắt trong BIOS.
- Duy trì dài hạn — Arch rolling có thể vỡ config Hyprland khi update; cần pin version trong CI test.

## 10. Definition of Done (v0.1)

- `make iso` build ra ISO boot được trong QEMU
- Live session: Super+Enter mở terminal đúng theme, Super+B mở browser
- Quay + chụp màn hình hoạt động, file lưu đúng chỗ
- `bambo-install` cài thành công trên VM sạch
- Toàn bộ thao tác P0 làm được không cần chuột
- Idle RAM ≤ 800 MB, ISO ≤ 2.5 GB
- README có ảnh chụp màn hình + hướng dẫn 5 phút

Ghi chú triển khai: những chỗ bản v0.1 làm khác PRD được ghi trong [decisions.md](decisions.md).
