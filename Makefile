# BamboOS build entry points.
#   make iso       build out/bambo-os-<date>-x86_64.iso (native on Arch, Docker elsewhere)
#   make lint      shellcheck + bash -n + Lua syntax + JSON checks
#   make test-vm   boot the newest ISO in QEMU with a window
#   make smoke     headless boot test with serial markers and a screenshot
#   make wallpaper regenerate themes/tessera/wallpaper.png
#   make clean

SHELL := /bin/bash
ISO = $(shell ls -t out/bambo-os-*.iso 2>/dev/null | head -n1)
IS_ARCH := $(shell command -v mkarchiso >/dev/null 2>&1 && echo yes)
HOST_ARCH := $(shell uname -m)
SCRIPTS := $(wildcard scripts/bambo-*) $(wildcard scripts/*.sh)

.PHONY: iso lint test-vm smoke wallpaper clean

iso:
ifeq ($(IS_ARCH),yes)
	sudo scripts/build-iso.sh
else
	docker run --rm --privileged --platform linux/amd64 \
		-v "$(CURDIR)":/src -w /src \
		-e BAMBO_DISABLE_SANDBOX=$(if $(filter x86_64,$(HOST_ARCH)),0,1) \
		archlinux:latest bash -c '\
			pacman -Syu --noconfirm $(if $(filter x86_64,$(HOST_ARCH)),,--disable-sandbox) archiso && \
			scripts/build-iso.sh'
endif

lint:
	@for f in $(SCRIPTS); do bash -n "$$f" || exit 1; done; echo "bash -n: ok"
	@if command -v shellcheck >/dev/null; then shellcheck $(SCRIPTS) iso/profiledef.sh && echo "shellcheck: ok"; \
	 else docker run --rm -v "$(CURDIR)":/mnt -w /mnt koalaman/shellcheck:stable $(SCRIPTS) iso/profiledef.sh && echo "shellcheck: ok"; fi
	@if command -v luac >/dev/null; then luac -p config/hypr/*.lua && echo "luac: ok"; else echo "luac: skipped (not installed)"; fi
	@python3 -c "import json,re,sys; s=open('config/waybar/config.jsonc').read(); json.loads(re.sub(r'^\s*//.*$$','',s,flags=re.M)); print('waybar json: ok')"
	@dups=$$(grep -hv '^\s*#' iso/packages.x86_64 iso/packages.live | sed '/^\s*$$/d' | sort | uniq -d); \
	 [ -z "$$dups" ] && echo "package list: ok" || { echo "duplicate packages: $$dups"; exit 1; }

test-vm:
	@[ -n "$(ISO)" ] || { echo "No ISO in out/. Run: make iso"; exit 1; }
	qemu-system-x86_64 -enable-kvm -cpu host -m 4096 -smp 4 \
		-device virtio-vga-gl -display gtk,gl=on \
		-device qemu-xhci -device usb-tablet \
		-drive file=out/test-disk.qcow2,if=virtio,format=qcow2 \
		-cdrom "$(ISO)" -boot d

out/test-disk.qcow2:
	mkdir -p out && qemu-img create -f qcow2 $@ 32G
test-vm: out/test-disk.qcow2

smoke:
	@[ -n "$(ISO)" ] || { echo "No ISO in out/. Run: make iso"; exit 1; }
	scripts/smoke-test.sh "$(ISO)"

wallpaper:
	python3 themes/tessera/make-wallpaper.py themes/tessera/wallpaper.png

clean:
	rm -rf out
