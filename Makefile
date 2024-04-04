SHELL := bash
SELF := $(realpath $(lastword $(MAKEFILE_LIST)))
SELFDIR := $(realpath $(dir $(SELF)))

MK := $(SELFDIR)/mk

init-db:
	make -f $(MK)/psql.mk init && make -f $(MK)/sqlx.mk run

clean-db:
	make -f $(MK)/psql.mk clean

build: init-db
	make -f $(MK)/cargo.mk build

run: build
	make -f $(MK)/app.mk run

stop:
	make -f $(MK)/app.mk stop

tests: stop clean-db init-db
	make -f $(MK)/app.mk daemon
	sleep 5
	make -f $(MK)/cargo.mk test
