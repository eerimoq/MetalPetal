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
