SHELL := /bin/bash

TOOLCHAIN_ROOT ?= $(HOME)/.local/share/momcozy-toolchains
FLUTTER_BIN := $(TOOLCHAIN_ROOT)/flutter/bin
JAVA_HOME ?= $(TOOLCHAIN_ROOT)/jdk/jdk-17.0.19+10/Contents/Home
ANDROID_SDK_ROOT ?= $(TOOLCHAIN_ROOT)/android-sdk
ANDROID_HOME ?= $(ANDROID_SDK_ROOT)
TOOLCHAIN_PATH := $(FLUTTER_BIN):$(JAVA_HOME)/bin:$(ANDROID_SDK_ROOT)/cmdline-tools/latest/bin:$(ANDROID_SDK_ROOT)/platform-tools:$(ANDROID_SDK_ROOT)/emulator:$(PATH)

export JAVA_HOME
export ANDROID_SDK_ROOT
export ANDROID_HOME
export PATH := $(TOOLCHAIN_PATH)

.PHONY: \
	flutter-check \
	local-dev-init \
	local-dev-up \
	local-dev-start \
	local-dev-app \
	local-dev-account \
	local-dev-verify \
	local-dev-status \
	local-dev-logs \
	local-dev-down \
	flutter-invite-dev \
	flutter-packaging-check \
	flutter-security-check \
	flutter-platform-smoke \
	flutter-emulator-smoke \
	flutter-apk-download-site \
	flutter-release-gate \
	backend-contract-validate

flutter-check:
	node scripts/check-flutter-toolchain.mjs

local-dev-init:
	node scripts/local-dev-stack.mjs init

local-dev-up:
	node scripts/local-dev-stack.mjs up

local-dev-start:
	node scripts/local-dev-stack.mjs start

local-dev-app:
	node scripts/local-dev-stack.mjs app

local-dev-account:
	node scripts/local-dev-stack.mjs account

local-dev-verify:
	node scripts/local-dev-stack.mjs verify

local-dev-status:
	node scripts/local-dev-stack.mjs status

local-dev-logs:
	node scripts/local-dev-stack.mjs logs

local-dev-down:
	node scripts/local-dev-stack.mjs down

flutter-invite-dev:
	node scripts/run-flutter-invite-dev.mjs

flutter-packaging-check:
	node scripts/check-flutter-android-packaging.mjs

flutter-security-check:
	node scripts/check-flutter-security-privacy.mjs

flutter-platform-smoke:
	node scripts/run-flutter-platform-smoke.mjs

flutter-emulator-smoke:
	node scripts/run-flutter-emulator-smoke.mjs

flutter-apk-download-site:
	node scripts/build-flutter-apk-download-site.mjs

flutter-release-gate:
	node scripts/run-flutter-release-gate.mjs

backend-contract-validate:
	python3 scripts/validate_backend_contract.py
