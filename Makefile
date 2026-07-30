SWIFTFORMAT_ARGS = \
	--maxwidth 110 \
	--swiftversion 5.9 \
	--disable docComments \
	--ifdef no-indent
SWIFTLINT_ARGS = --strict --quiet
CODESPELL_ARGS = \
	--ignore-words-list "inout,froms,soop,medias,deactive,upto,datas,ro,lightyears"

CODE_DIRS += "Frameworks"
CODE_DIRS += "MetalPetalExamples"

SHELL = /usr/bin/env bash

.PHONY: build test

default:

style:
	swiftformat $(CODE_DIRS) $(SWIFTFORMAT_ARGS)

style-check:
	swiftformat $(CODE_DIRS) $(SWIFTFORMAT_ARGS) --lint

lint:
	swiftlint lint $(SWIFTLINT_ARGS) $(CODE_DIRS)

spell-check:
	codespell $(CODESPELL_ARGS) $(CODE_DIRS)

build:
	swift build

test:
	swift test

build-all: build
	xcodebuild build -scheme MetalPetal -destination 'platform=iOS Simulator,name=iPhone 17' -workspace .
	xcodebuild build -scheme MetalPetal -destination 'platform=macOS,variant=Mac Catalyst' -workspace .
	xcodebuild build -scheme MetalPetal -destination 'platform=tvOS Simulator,name=Apple TV' -workspace .
	xcodebuild build -scheme MetalPetal -destination generic/platform=iOS -workspace .
	xcodebuild build -scheme MetalPetal -destination generic/platform=tvOS -workspace .

test-all: test
	xcodebuild test -scheme MetalPetal -destination 'platform=iOS Simulator,name=iPhone 17' -workspace .
	xcodebuild test -scheme MetalPetal -destination 'platform=macOS,variant=Mac Catalyst' -workspace .
	xcodebuild test -scheme MetalPetal -destination 'platform=tvOS Simulator,name=Apple TV' -workspace .
