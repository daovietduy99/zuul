SOURCES := sources.tar
VIRTUALENV ?= /usr/bin/virtualenv
VENV_DIR := .venv
VENV_ACTIVATE := . $(VENV_DIR)/bin/activate
PWD := $(shell pwd)
WEBAPP_DIR := etc/status
IS_PYTHON3 ?= false
ifeq ($(IS_PYTHON3),true)
	PIP_REQ = requirements-py3.txt
else
	PIP_REQ = requirements.txt
endif
# Create source archive
.PHONY: tarball
tarball:
	git archive --format=tar HEAD^{tree} > $(SOURCES)

# Build zuul bundle
.PHONY: build
build: build.state

build.state:
	$(VIRTUALENV) $(VENV_DIR)
	$(VENV_ACTIVATE) && pip install -U pip
	$(VENV_ACTIVATE) && pip install -r $(PIP_REQ)
	$(VENV_ACTIVATE) && ./etc/status/fetch-dependencies.sh # web assets fetch
	$(VENV_ACTIVATE) && python setup.py install
	rm -f $(VENV_DIR)/pip-selfcheck.json
	$(VIRTUALENV) --relocatable $(VENV_DIR)
	touch $@

# Install zuul bundle into DESTDIR
.PHONY: install
install:
	install -d -m 755 '$(DESTDIR)'
	cp -a $(VENV_DIR)/* '$(DESTDIR)'
	cp -a $(WEBAPP_DIR) '$(DESTDIR)'

.PHONY: clean
clean:
	rm -rf $(SOURCES) $(PIP_DEPS_DIR) $(VENV_DIR)

.PHONY: test-logging
test-logging:
	rm -f integration/.test/log/*
	tox -e venv -- timeout --preserve-status 10 zuul-server -c integration/config/zuul.conf -d
	grep -F 'zuul.GithubConnection' integration/.test/log/zuul.log

.PHONY: check
check: build.state
	$(VENV_ACTIVATE) && \
		pip install --requirement test-requirements.txt
	$(VENV_ACTIVATE) && \
        OS_TEST_TIMEOUT=200 python setup.py testr --slowest
