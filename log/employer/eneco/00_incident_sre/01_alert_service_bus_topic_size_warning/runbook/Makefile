BIN := ./target/release/diagnose

# Default env (dev). Override: make run NAMESPACE=vpp-sbus-p MESSAGING_RG=mcdta-rg-vpp-p-messaging
NAMESPACE       ?= vpp-sbus-d
MESSAGING_RG    ?= mcdta-rg-vpp-d-messaging
SUBSCRIPTION_ID ?= 839af51e-c8dd-4bd2-944b-a7799eb2e1e4

.PHONY: build run run-dev run-prd clean fmt check

## Build release binary
build:
	cargo build --release

## Run triage against dev (default)
run: build
	$(BIN) \
	  --namespace $(NAMESPACE) \
	  --resource-group $(MESSAGING_RG) \
	  --subscription $(SUBSCRIPTION_ID)

## Explicit dev shorthand
run-dev: build
	$(BIN) \
	  --namespace vpp-sbus-d \
	  --resource-group mcdta-rg-vpp-d-messaging \
	  --subscription 839af51e-c8dd-4bd2-944b-a7799eb2e1e4

## Explicit prd shorthand (update SUBSCRIPTION_ID for prd)
run-prd: build
	$(BIN) \
	  --namespace vpp-sbus-p \
	  --resource-group mcdta-rg-vpp-p-messaging \
	  --subscription $(SUBSCRIPTION_ID)

## Format source
fmt:
	cargo fmt

## Clippy + fmt check (CI gate)
check:
	cargo fmt --check
	cargo clippy -- -D warnings

## Remove build artifacts
clean:
	cargo clean
