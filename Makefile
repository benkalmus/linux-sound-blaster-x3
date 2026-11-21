PYTHON_SCRIPTS := bin/bluetooth-auto-agent bluetooth/*.py

.DEFAULT_GOAL := host

.PHONY: host sender bluetooth vinyl all doctor revert revert-host revert-sender revert-bluetooth revert-vinyl lint test check help

host: ; scripts/install-host.sh
sender: ; scripts/install-sender.sh
bluetooth: ; scripts/install-bluetooth.sh
vinyl: ; scripts/install-vinyl.sh
all: host bluetooth vinyl
doctor: ; scripts/doctor.sh

revert: revert-host revert-sender revert-bluetooth revert-vinyl
revert-host: ; scripts/revert.sh host
revert-sender: ; scripts/revert.sh sender
revert-bluetooth: ; scripts/revert.sh bluetooth
revert-vinyl: ; scripts/revert.sh vinyl

help:
	@echo "Setup targets (run with sudo):"
	@echo "  host              VBAN receiver on the X3 machine (default)"
	@echo "  sender            VBAN sender on the source machine"
	@echo "  bluetooth         Bluetooth auto-accept agent and routing"
	@echo "  vinyl             Install vinyl-toggle into ~/bin"
	@echo "  all               host + bluetooth + vinyl"
	@echo "  doctor            Check the installed state (no changes)"
	@echo "Revert targets (run with sudo):"
	@echo "  revert            Undo all targets that have a manifest"
	@echo "  revert-host       Undo host"
	@echo "  revert-sender     Undo sender"
	@echo "  revert-bluetooth  Undo bluetooth"
	@echo "  revert-vinyl      Undo vinyl"
	@echo "Checks (no sudo):"
	@echo "  lint test check"

check: lint test

lint:
	ruff check $(PYTHON_SCRIPTS)
	pyright

test:
	bluetooth/run-tests.sh
