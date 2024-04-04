SHELL := bash

ADMIN ?= an.romanov
ADMIN_DB ?= postgres
ADMIN_PASSWORD ?= postgres
AUTH_METHOD ?= remote
# CNT abbreviation for CoNTainer name. So, you can run postgres inside container.
CNT = 
EXIT_IF_DB_EXISTS = no
EXIT_IF_USER_EXISTS = no
HOST ?= localhost
PORT ?= 5432
USER_ATTRIBUTES ?= SUPERUSER CREATEDB
USER_DB ?= example_api_db
USER_NAME ?= example_api_user
USER_PASSWORD ?= 12345
PG_DUMP ?= /tmp/.dumps/$(USER_DB).sql

CONN_URL ?= postgres://$(ADMIN):$(ADMIN_PASSWORD)@$(HOST):$(PORT)/$(ADMIN_DB)
USER_CONN_URL ?= postgres://$(USER_NAME):$(USER_PASSWORD)@$(HOST):$(PORT)/$(USER_DB)
 
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

define select_user
SELECT '$1' FROM pg_roles WHERE rolname = '$1'
endef

define select_db
SELECT '$1' FROM pg_database WHERE datname = '$1'
endef

define check
$$($(PSQL) -tXAc $$'$(subst ',\',$(call select_$1,$2))')
endef

ATTRIBUTES ?= 

#
ifdef CNT
    PSQL ?= docker exec $(TI) $(CNT) psql -U $(ADMIN) -d $(ADMIN_DB)
    PSQL_USER ?= docker exec $(TI) $(CNT) psql -U $(USER_NAME) -d $(USER_DB)
else ifeq ($(AUTH_METHOD),remote)
    PSQL = psql $(CONN_URL)
    PSQL_USER ?= psql $(USER_CONN_URL)
else ifeq ($(AUTH_METHOD),peer)
    PSQL ?= $(SUDO) -iu $(ADMIN) PGDATABASE=$(ADMIN_DB) psql
    PSQL_USER ?= $(SUDO) -iu $(USER_NAME) PGDATABASE=$(USER_DB) psql
else
    $(error Unsupported value '$(AUTH_METHOD)' for 'AUTH_METHOD' variable. SECTION=$(SECTION))
endif

# Targets

.PHONY: init create-user create-db grant revoke connect connect-admin clear clean dump distclean import

create-user:
ifeq ($(EXIT_IF_USER_EXISTS),yes)
	[ -z "$(call check,user,$(USER_NAME))" ] || false
endif
	[ -n "$(call check,user,$(USER_NAME))" ] || $(PSQL) -c "CREATE USER $(USER_NAME) WITH ENCRYPTED PASSWORD '$(USER_PASSWORD)' $(USER_ATTRIBUTES);"

create-db: create-user
ifeq ($(EXIT_IF_DB_EXISTS),yes)
	[ -z "$(call check,db,$(USER_DB))" ] || false
endif
	[ -n "$(call check,db,$(USER_DB))" ] || $(PSQL) -c "CREATE DATABASE $(USER_DB) WITH OWNER=$(USER_NAME);"

grant: create-db
	# Assign priviliges to user '$(USER_NAME)'
	$(PSQL) -c "GRANT ALL PRIVILEGES ON DATABASE $(USER_DB) TO $(USER_NAME);"
	$(PSQL) -c "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO $(USER_NAME);"

revoke:
	$(foreach A,$(ATTRIBUTES),$(PSQL) -c "ALTER USER $(USER_NAME) WITH NO$(ATTRIBUTE);" $(LF))

init: create-user create-db grant

connect: override TI = -ti
connect:
	$(PSQL_USER)

connect-admin: override TI = -ti
connect-admin:
	$(PSQL)

dump:
	PGPASSWORD=$(USER_PASSWORD) pg_dump -h $(HOST) -p $(PORT) -U $(USER_NAME) -d $(USER_DB) --file=$(PG_DUMP)

import: clean init
	$(USER_URL) --set ON_ERROR_STOP=on -f "$(PG_DUMP)"

clear:
	$(PSQL_USER) -c "DROP SCHEMA IF EXISTS public CASCADE;"
	$(PSQL_USER) -c "CREATE schema public;"

clean:
	$(PSQL) -c "DROP DATABASE IF EXISTS $(USER_DB);"
	$(PSQL) -c "DROP USER IF EXISTS $(USER_NAME);"

distclean: clean

lsof:
ifneq ($(HOST),0.0.0.0)
	sudo lsof -nP -i4TCP@0.0.0.0:$(PORT) || true
endif
ifneq ($(HOST),localhost)
	sudo lsof -nP -i4TCP@localhost:$(PORT) || true
endif
	sudo lsof -nP -i4TCP@$(HOST):$(PORT) || true