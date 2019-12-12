# Makefile for Plenum Cyber-Physical Digital Twin Engine

.PHONY: all build test simulate dashboard benchmark stats verify clean

all: verify build test

build:
	cargo build --release

test:
	cargo test
	cargo run -- --test

simulate:
	cargo run -- --simulate 10.0

dashboard:
	cargo run -- --dashboard

benchmark:
	cargo run -- --benchmark

stats:
	cargo run -- --stats

verify:
	python3 scripts/check_no_em_dashes.py

clean:
	cargo clean
