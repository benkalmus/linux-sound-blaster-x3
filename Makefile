# Setup targets. Run as root: sudo make [target]
# Default target: host (VBAN receiver on the machine with the X3 card).

REPO := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))

# sudo keeps the invoking user in SUDO_USER. Session commands (pactl,
# wpctl, systemctl --user) must run as that user, not as root.
USER_NAME ?= $(or $(SUDO_USER),$(USER))
USER_UID  ?= $(or $(SUDO_UID),$(shell id -u $(USER_NAME)))
USER_HOME ?= $(shell getent passwd $(USER_NAME) | cut -d: -f6)

ifeq ($(shell id -u),0)
AS_USER := runuser -u $(USER_NAME) -- env XDG_RUNTIME_DIR=/run/user/$(USER_UID)
else
AS_USER :=
endif

CARD_ID ?= X3
X3_SINK ?= alsa_output.usb-Creative_Technology_Ltd_Sound_Blaster_X3_9E42D45FF9ACC811-03.pro-output-0

PW      := /etc/pipewire
WP      := /etc/wireplumber
SYSTEMD := /etc/systemd/system

.DEFAULT_GOAL := host

.PHONY: host sender bluetooth vinyl all doctor lint test check help require-root dirs

help:
	@echo "Setup targets (run with sudo):"
	@echo "  host       VBAN receiver on the X3 machine (default)"
	@echo "  sender     VBAN sender on the source machine"
	@echo "  bluetooth  Bluetooth auto-accept agent and routing"
	@echo "  vinyl      Install vinyl-toggle into $(USER_HOME)/bin"
	@echo "  all        host + bluetooth + vinyl"
	@echo "  doctor     Check the installed state (no changes)"
	@echo "  lint test  Python checks (no sudo needed)"

require-root:
	@test "$$(id -u)" = "0" || { echo "Run: sudo make $(or $(MAKECMDGOALS),host)"; exit 1; }

dirs: require-root
	install -d $(PW)/pipewire.conf.d $(PW)/client.conf.d $(PW)/pipewire-pulse.conf.d
	install -d $(WP)/wireplumber.conf.d

# Link a repo file into place. Move a regular file aside first.
define link
	@if [ -e "$(2)" ] && [ ! -L "$(2)" ]; then \
		mv "$(2)" "$(2).bak.$$(date +%Y%m%d-%H%M%S)"; \
	fi
	ln -snf "$(1)" "$(2)"
endef

host: dirs
	@card=$$($(AS_USER) pactl list cards short | awk '/Creative/ {print $$2; exit}'); \
	test -n "$$card" || { echo "Creative card not found"; exit 1; }; \
	$(AS_USER) pactl set-card-profile "$$card" pro-audio
	$(call link,$(REPO)/configs/unified-upmix-sink.conf,$(PW)/pipewire.conf.d/unified-upmix-sink.conf)
	$(call link,$(REPO)/configs/vban-recv.conf,$(PW)/pipewire.conf.d/vban-recv.conf)
	$(call link,$(REPO)/configs/pipewire-pulse-upmix.conf,$(PW)/pipewire-pulse.conf.d/upmix.conf)
	$(call link,$(REPO)/configs/client-upmix.conf,$(PW)/client.conf.d/upmix.conf)
	$(call link,$(REPO)/configs/61-vban-route.conf,$(WP)/wireplumber.conf.d/61-vban-route.conf)
	install -d /var/lib/sddm/.config/wireplumber/wireplumber.conf.d
	install -m 644 $(REPO)/configs/51-sddm-no-bluetooth.conf /var/lib/sddm/.config/wireplumber/wireplumber.conf.d/51-no-bluetooth.conf
	$(call link,$(REPO)/configs/alsa-restore-delayed.service,$(SYSTEMD)/alsa-restore-delayed.service)
	$(call link,$(REPO)/configs/alsa-restore-delayed.timer,$(SYSTEMD)/alsa-restore-delayed.timer)
	$(call link,$(REPO)/configs/x3-mixer.service,$(SYSTEMD)/x3-mixer.service)
	$(call link,$(REPO)/configs/x3-mixer.timer,$(SYSTEMD)/x3-mixer.timer)
	install -d /etc/NetworkManager/dispatcher.d
	sed -e "s/benkalmus/$(USER_NAME)/g" -e "s|/run/user/1000|/run/user/$(USER_UID)|g" \
		$(REPO)/configs/99-restart-pipewire > /etc/NetworkManager/dispatcher.d/99-restart-pipewire
	chmod 755 /etc/NetworkManager/dispatcher.d/99-restart-pipewire
	systemctl daemon-reload
	systemctl enable --now alsa-restore-delayed.timer x3-mixer.timer
	systemctl start x3-mixer.service
	$(AS_USER) systemctl --user restart pipewire pipewire-pulse wireplumber
	sleep 2
	$(AS_USER) pactl set-default-sink unified-upmix
	$(AS_USER) wpctl set-volume unified-upmix 1.0
	@echo "Host setup complete. Run: make doctor"

sender: dirs
	$(call link,$(REPO)/configs/vban-send.conf,$(PW)/pipewire.conf.d/vban-send.conf)
	$(call link,$(REPO)/configs/pipewire-pulse-upmix.conf,$(PW)/pipewire-pulse.conf.d/upmix.conf)
	$(call link,$(REPO)/configs/client-upmix.conf,$(PW)/client.conf.d/upmix.conf)
	install -d $(USER_HOME)/.config/systemd/user/pipewire.service.d
	ln -snf $(REPO)/configs/pipewire-recovery.conf $(USER_HOME)/.config/systemd/user/pipewire.service.d/override.conf
	chown -R $(USER_NAME):$(USER_NAME) $(USER_HOME)/.config/systemd/user/pipewire.service.d
	$(AS_USER) systemctl --user daemon-reload
	$(AS_USER) systemctl --user restart pipewire
	@echo "Sender setup complete. Route audio to 'Opti VBAN 5.1'."

bluetooth: dirs
	$(call link,$(REPO)/configs/bluetooth-main.conf,/etc/bluetooth/main.conf)
	$(call link,$(REPO)/configs/51-no-seat-monitoring.conf,$(WP)/wireplumber.conf.d/51-no-seat-monitoring.conf)
	$(call link,$(REPO)/configs/60-bluetooth-route.conf,$(WP)/wireplumber.conf.d/60-bluetooth-route.conf)
	install -d /var/lib/sddm/.config/wireplumber/wireplumber.conf.d
	install -m 644 $(REPO)/configs/51-sddm-no-bluetooth.conf /var/lib/sddm/.config/wireplumber/wireplumber.conf.d/51-no-bluetooth.conf
	$(call link,$(REPO)/bin/bluetooth-auto-agent,/usr/local/bin/bluetooth-auto-agent)
	$(call link,$(REPO)/bin/bluetooth-toggle,/usr/local/bin/bluetooth-toggle)
	$(call link,$(REPO)/configs/bluetooth-auto-agent.service,$(SYSTEMD)/bluetooth-auto-agent.service)
	systemctl daemon-reload
	systemctl enable --now bluetooth-auto-agent
	systemctl restart bluetooth
	$(AS_USER) systemctl --user restart wireplumber
	@echo "Bluetooth setup complete. Toggle with: bluetooth-toggle"

vinyl:
	install -d $(USER_HOME)/bin
	install -m 755 $(REPO)/bin/vinyl-toggle $(USER_HOME)/bin/vinyl-toggle
	chown $(USER_NAME):$(USER_NAME) $(USER_HOME)/bin/vinyl-toggle
	@echo "Installed $(USER_HOME)/bin/vinyl-toggle"

all: host bluetooth vinyl

doctor:
	@echo "== card =="; $(AS_USER) pactl list cards short 2>/dev/null | grep -i creative || echo "not found"
	@echo "== sinks =="; $(AS_USER) pactl list short sinks 2>/dev/null
	@echo "== default sink =="; $(AS_USER) pactl info 2>/dev/null | grep "Default Sink"
	@echo "== expected output =="; $(AS_USER) pactl list short sinks 2>/dev/null | grep -F "$(X3_SINK)" || echo "missing: $(X3_SINK)"
	@echo "== speaker volume =="; amixer -c $(CARD_ID) cget numid=13 2>/dev/null | sed -n "3p"
	@echo "== links =="; $(AS_USER) pw-link -l 2>/dev/null | grep -A1 "unified-upmix-output" || true
	@echo "== units =="; systemctl is-active alsa-restore-delayed.timer x3-mixer.timer 2>/dev/null || true

# Python checks
PYTHON_SCRIPTS := bin/bluetooth-auto-agent bluetooth/*.py

check: lint test

lint:
	ruff check $(PYTHON_SCRIPTS)
	pyright

test:
	bluetooth/run-tests.sh
