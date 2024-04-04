SHELL := bash
SELF := $(realpath $(lastword $(MAKEFILE_LIST)))
SELFDIR := $(realpath $(dir $(SELF)))
WORKSPACE := $(realpath $(SELFDIR)/..)

CARGO_TOML ?= $(WORKSPACE)/Cargo.toml
BINS ?= hello-axum
CLIPPY_FORMAT ?= json
CLIPPY_REPORT ?= clippy-report.json
FEATURES ?= 
LINTS ?= 
PROFILE ?= dev
TARGET_ARCH ?= aarch64-apple-darwin
TARGET_DIR ?= $(WORKSPACE)/target
INSTALL_DIR ?= /usr/local/bin

HOST ?= localhost
PORT ?= 5432
USER_DB ?= example_api_db
USER_NAME ?= example_api_user
USER_PASSWORD ?= 12345

# Use 'abspath' instead 'realpath' because TARGET_DIR is not exists, but 'realpath' checks its existance
# $1:profile,$2:TARGET_DIR,$3:TARGET_ARCH
# EXAMPLE = $(call cargo_bins,dev,target,aarch64-apple-darwin)
define cargo_bins
$(eval 
ifeq ($1,dev)
x__PROFILE_DIR = debug
else
x__PROFILE_DIR = $1
endif)$2/$3/$(x__PROFILE_DIR)
endef

BINS_DIR = $(call cargo_bins,$(PROFILE),$(TARGET_DIR),$(TARGET_ARCH))

# SUDO
SUDO_BIN ?= 
SUDO_USR ?= 

# $(and ..., ..., ...) 
# - each argument is expanded, in order;
# - if an argument expands to an empty string the processing stops and the result of the expansion is the empty string;
# - if all arguments expand to a non-empty string then the result of the expansion is the expansion of the last argument;
ifneq ($(strip $(and $(SUDO_BIN),$(SUDO_USR))),)
    SUDO = $(SUDO_BIN) -u $(SUDO_USR)
else ifneq ($(strip $(SUDO_BIN)),)
    SUDO = $(SUDO_BIN)
else
    SUDO = 
endif

define LF


endef

# RUSTFLAGS = -C target-feature=-crt-static
DATABASE_URL = postgres://$(USER_NAME):$(USER_PASSWORD)@$(HOST):$(PORT)/$(USER_DB)
BUILD_VERSION = $(shell git log -1 --pretty=format:"%h")

BUILD_ENVS ?= \
    RUSTFLAGS='$(RUSTFLAGS)' \
    BUILD_VERSION='$(BUILD_VERSION)' \
    DATABASE_URL='$(DATABASE_URL)'


HOST ?= localhost
PORT ?= 5432
USER_DB ?= example_api_db
USER_NAME ?= example_api_user
USER_PASSWORD ?= 12345

SEVERITY = debug
RUST_LOG = actix=$(SEVERITY),actix_web=$(SEVERITY),example_api_sqlx=$(SEVERITY),sqlx=$(SEVERITY)

# ENVS
ENVS ?= \
    PG_HOST='$(HOST)' \
    PG_PORT='$(PORT)' \
    PG_DB='$(USER_DB)' \
    PG_USER='$(USER_NAME)' \
    PG_PASSWORD='$(USER_PASSWORD)' \
    RUST_LOG='$(RUST_LOG)'

OPT_BINS = $(foreach BIN,$(BINS), --bin $(BIN))

# OPT_PROFILE
ifeq ($(PROFILE),release)
    OPT_PROFILE = --profile release
else
    OPT_PROFILE = --profile dev
endif

# OPT_FEATURES
ifdef FEATURES
    OPT_FEATURES = --features $(FEATURES)
else
    OPT_FEATURES =
endif

# CARGO_OPTS
CARGO_OPTS ?= $(OPT_PROFILE) $(OPT_BINS) $(OPT_FEATURES) --manifest-path $(CARGO_TOML) \
    --target-dir $(TARGET_DIR) \
    --target $(TARGET_ARCH)

CARGO_TEST_OPTS ?= $(OPT_PROFILE) $(OPT_FEATURES) --manifest-path $(CARGO_TOML) \
    --target-dir $(TARGET_DIR) \
    --target $(TARGET_ARCH) \
    --package hello-axum

ifdef BINS
CMD_BUILD ?= $(BUILD_ENVS) cargo build $(CARGO_OPTS)
CMD_CLIPPY ?= $(BUILD_ENVS) cargo clippy $(CARGO_OPTS) --message-format $(CLIPPY_FORMAT) -- $(LINTS) 1>$(CLIPPY_REPORT)
CMD_CLIPPY_FIX ?= $(BUILD_ENVS) cargo clippy --fix $(CARGO_OPTS)
CMD_FMT ?=  $(BUILD_ENVS) cargo +nightly fmt
CMD_FMT_CHECK ?= $(BUILD_ENVS) $(CMD_FMT) -- --check
CMD_DOC ?= $(BUILD_ENVS) cargo doc --no-deps --document-private-items --package hello-axum --open
CMD_TEST ?= $(BUILD_ENVS) $(ENVS) cargo test $(CARGO_TEST_OPTS)
CMD_CLEAN ?= $(ENVS) cargo clean --manifest-path $(CARGO_TOML)
endif

.PHONY: all build clippy clippy-fix lint test fmt fmt-check doc install uninstall clean distclean

all: fmt clippy build test

build:
	cd $(WORKSPACE) && $(CMD_BUILD)

clippy:
	cd $(WORKSPACE) && $(CMD_CLIPPY)

clippy-fix:
	cd $(WORKSPACE) && $(CMD_CLIPPY_FIX)

lint: clippy

test:
	cd $(WORKSPACE) && $(CMD_TEST)

fmt:
	cd $(WORKSPACE) && $(CMD_FMT)

fmt-check:
	cd $(WORKSPACE) && $(CMD_FMT_CHECK)

doc:
	cd $(WORKSPACE) && $(CMD_DOC)

clean:
	cd $(WORKSPACE) && $(CMD_CLEAN)

distclean: clean

install:
	$(SUDO) install -d $(INSTALL_DIR)
	$(foreach BIN,$(BINS),$(SUDO) install -m 755 -t $(INSTALL_DIR) $(BINS_DIR)/$(BIN) $(LF))

uninstall:
	$(foreach BIN,$(BINS),$(SUDO) rm $(INSTALL_DIR)/$(BIN) $(LF))