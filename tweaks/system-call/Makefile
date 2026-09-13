SHELL := /bin/sh
HERE  := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
ROOT  := $(abspath $(HERE)/../..)
OUT   := $(HERE)/out
SRC   := $(HERE)/src

DYLIB := $(OUT)/TelegramSystemCall.dylib

XCODE_DEV := $(shell xcode-select -p)
CLANG     := $(XCODE_DEV)/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang

SDK ?= $(ROOT)/build/sdks/iPhoneOS12.4.sdk
ifeq ($(wildcard $(SDK)),)
  SDK := $(ROOT)/build/sdks/iPhoneOS9.3.sdk
endif
ifeq ($(wildcard $(SDK)),)
  SDK := $(XCODE_DEV)/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk
endif

ARCH := -arch armv7
MIN  := -miphoneos-version-min=6.0
WARN := -Wall -Wextra -Wno-unused-parameter -Wno-deprecated-declarations
CFLAGS := $(ARCH) -isysroot $(SDK) $(MIN) $(WARN) -O2 -fno-objc-arc \
          -fobjc-exceptions -I$(SRC)
FRAMEWORKS := -framework Foundation

LDID := $(shell command -v ldid 2>/dev/null)

.PHONY: all dylib deb check clean distclean help

all: dylib

dylib: $(DYLIB)

$(OUT):
	@mkdir -p $(OUT)

$(DYLIB): $(SRC)/TSCTweak.m | $(OUT)
	@echo "  dylib   $(notdir $@)  (sdk $(notdir $(SDK)))"
	@$(CLANG) $(CFLAGS) -dynamiclib \
		-install_name /Library/MobileSubstrate/DynamicLibraries/TelegramSystemCall.dylib \
		$(FRAMEWORKS) -o $@ $(SRC)/TSCTweak.m
	@if [ -n "$(LDID)" ]; then $(LDID) -S $@; else echo "  warning: ldid not found, $(notdir $@) is unsigned"; fi

deb: all
	@$(HERE)/mkdeb.sh

check: $(DYLIB)
	@lipo -info $(DYLIB) | grep -q armv7 || { echo "no armv7 slice" >&2; exit 1; }
	@otool -L $(DYLIB) | grep -q UIKit && { echo "links UIKit; it must not" >&2; exit 1; } || true
	@otool -L $(DYLIB) | grep -q libsubstrate && { echo "links substrate; it must not" >&2; exit 1; } || true
	@echo "check: $(notdir $(DYLIB)) is armv7, links neither UIKit nor substrate"

clean:
	@rm -rf $(HERE)/work $(OUT)/*.deb

distclean:
	@rm -rf $(HERE)/work $(OUT)

help:
	@echo "make            build the SpringBoard dylib"
	@echo "make deb        also package it as a .deb"
	@echo "make check      static checks on the built dylib"
	@echo "make clean      drop the .deb staging tree and built .deb files"
	@echo "make distclean  drop out/ and work/ entirely"
	@echo ""
	@echo "SDK=<path>      override the iOS SDK (needs an armv7 slice)"
