PYTHON_SCRIPTS := bin/bluetooth-auto-agent bluetooth/*.py

.PHONY: check lint test

check: lint test

lint:
	ruff check $(PYTHON_SCRIPTS)
	pyright

test:
	bluetooth/run-tests.sh
