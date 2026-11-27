# BamboOS build entry points.
#   make iso       build out/bambo-os-<date>-x86_64.iso (native on Arch, Docker elsewhere)
#   make lint      shellcheck + bash -n + Lua syntax + JSON checks
#   make arm64     build out/bambo-os-*-aarch64.qcow2, a ready-to-boot image for Apple Silicon (needs Docker)
#   make app       macOS: build and open "out/Try BamboOS.app", a window to start the VM and share a folder
#   make try       boot BamboOS full screen in QEMU: the arm64 image on Apple Silicon, else the ISO
#   make test-vm   boot the newest ISO in QEMU with a window
#   make iso-test  build out/test/*.iso with the bambo-smoke test service included
#   make smoke     headless QEMU tests on the test ISO: live session, then bambo-install
#   make wallpaper regenerate themes/tessera/wallpaper.png
#   make clean

SHELL := /bin/bash
ISO = $(shell ls -t out/bambo-os-*.iso 2>/dev/null | head -n1)
IS_ARCH := $(shell command -v mkarchiso >/dev/null 2>&1 && echo yes)
HOST_ARCH := $(shell uname -m)
# Shell scripts only: scripts/ also holds Python (bambo-clipboard, clipboard-host.py).
SCRIPTS := $(shell grep -lE '^\#!.*\bbash' scripts/bambo-* scripts/*.sh)
PYTHON_SCRIPTS := scripts/bambo-clipboard scripts/clipboard-host.py

.PHONY: iso iso-test arm64 app lint try test-vm smoke wallpaper clean

TEST_ISO = $(shell ls -t out/test/bambo-os-*.iso 2>/dev/null | head -n1)
SMOKE ?= 0
OUT ?= out

iso:
ifeq ($(IS_ARCH),yes)
	sudo BAMBO_SMOKE=$(SMOKE) BAMBO_OUT_DIR="$(CURDIR)/$(OUT)" scripts/build-iso.sh
else
	docker run --rm --privileged --platform linux/amd64 \
		-v "$(CURDIR)":/src -w /src \
		-e BAMBO_SMOKE=$(SMOKE) -e BAMBO_OUT_DIR=/src/$(OUT) \
		-e BAMBO_DISABLE_SANDBOX=$(if $(filter x86_64,$(HOST_ARCH)),0,1) \
		archlinux:latest bash -c '\
			pacman -Syu --noconfirm $(if $(filter x86_64,$(HOST_ARCH)),,--disable-sandbox) archiso && \
			scripts/build-iso.sh'
endif

iso-test:
	$(MAKE) iso SMOKE=1 OUT=out/test

lint:
	@for f in $(SCRIPTS); do bash -n "$$f" || exit 1; done; echo "bash -n: ok"
	@if command -v shellcheck >/dev/null; then shellcheck $(SCRIPTS) iso/profiledef.sh && echo "shellcheck: ok"; \
	 else docker run --rm -v "$(CURDIR)":/mnt -w /mnt koalaman/shellcheck:stable $(SCRIPTS) iso/profiledef.sh && echo "shellcheck: ok"; fi
	@python3 -c "import ast,sys; [ast.parse(open(f).read(), f) for f in sys.argv[1:]]; print('python: ok')" $(PYTHON_SCRIPTS)
	@if command -v luac >/dev/null; then luac -p config/hypr/*.lua && echo "luac: ok"; else echo "luac: skipped (not installed)"; fi
	@python3 -c "import json,re,sys; s=open('config/waybar/config.jsonc').read(); json.loads(re.sub(r'^\s*//.*$$','',s,flags=re.M)); print('waybar json: ok')"
	@dups=$$(grep -hv '^\s*#' iso/packages.x86_64 iso/packages.live | sed '/^\s*$$/d' | sort | uniq -d); \
	 [ -z "$$dups" ] && echo "package list: ok" || { echo "duplicate packages: $$dups"; exit 1; }

arm64:
	scripts/build-arm64.sh

try:
	scripts/try-bambo.sh

app:
	scripts/build-app.sh
	@open "out/Try BamboOS.app"

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
	@[ -n "$(TEST_ISO)" ] || { echo "No test ISO in out/test/. Run: make iso-test"; exit 1; }
	scripts/smoke-test.sh "$(TEST_ISO)" live
	scripts/smoke-test.sh "$(TEST_ISO)" install

wallpaper:
	python3 themes/tessera/make-wallpaper.py themes/tessera/wallpaper.png

clean:
	rm -rf out
