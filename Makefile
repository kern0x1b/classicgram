export THEOS_PACKAGE_SCHEME =

TARGET := iphone:clang:9.3:6.0
ARCHS := armv7 arm64
INSTALL_TARGET_PROCESSES = Telegram

PACKAGE_VERSION ?= 1.0.2

SYSROOT ?= $(CURDIR)/build/sdks/iPhoneOS12.4.sdk
ifeq ($(wildcard $(SYSROOT)),)
SYSROOT := $(CURDIR)/build/sdks/iPhoneOS9.3.sdk
endif
ifeq ($(wildcard $(SYSROOT)),)
$(error no iPhoneOS SDK under build/sdks - run scripts/fetch-ios-sdk.sh, or point SYSROOT at one)
endif
ISYSROOT := $(SYSROOT)

include $(THEOS)/makefiles/common.mk

MODULESFLAGS :=
_THEOS_INTERNAL_IFLAGS_BASE = -I$(THEOS_TARGET_INCLUDE_PATH)

APPLICATION_NAME = Telegram

ROOT := $(THEOS_PROJECT_DIR)

IOS6_DEPS_CONANFILES := $(ROOT)/packaging/deps/conanfile.py $(ROOT)/packaging/tdlib/conanfile.py \
	$(ROOT)/packaging/openssl/conanfile.py $(ROOT)/packaging/ogg/conanfile.py \
	$(ROOT)/packaging/quirc/conanfile.py $(ROOT)/packaging/opusenc/conanfile.py \
	$(ROOT)/packaging/opusfile/conanfile.py $(ROOT)/packaging/opus/conanfile.py \
	$(ROOT)/packaging/libvpx/conanfile.py $(ROOT)/packaging/libtgvoip/conanfile.py

$(ROOT)/packaging/deps/build/conan/armv7/ios6-deps.env: $(IOS6_DEPS_CONANFILES)
	ITGLEGACY_ROOT=$(ROOT) conan install $(ROOT)/packaging/deps -pr:h ios6-armv7 -pr:b default --build=missing

$(ROOT)/packaging/deps/build/conan/armv8/ios6-deps.env: $(IOS6_DEPS_CONANFILES)
	ITGLEGACY_ROOT=$(ROOT) conan install $(ROOT)/packaging/deps -pr:h $(ROOT)/packaging/profiles/arm64 -pr:b default --build=missing

IOS6_DEPS := TDLIB OPENSSL OGG QUIRC OPUSENC OPUSFILE OPUS LIBVPX LIBTGVOIP

include $(ROOT)/packaging/deps/build/conan/armv7/ios6-deps.env
$(foreach d,$(IOS6_DEPS),$(eval IOS6_HOST_$(d)_armv7 := $(IOS6_HOST_$(d))))

include $(ROOT)/packaging/deps/build/conan/armv8/ios6-deps.env
$(foreach d,$(IOS6_DEPS),$(eval IOS6_HOST_$(d)_arm64 := $(IOS6_HOST_$(d))))

$(foreach d,$(IOS6_DEPS),$(eval IOS6_HOST_$(d) = $$(IOS6_HOST_$(d)_$$(THEOS_CURRENT_ARCH))))

SRC_INCLUDES = $(addprefix -I$(ROOT)/,\
	src/Resources/Config app src/App src/TDLibClient src/Model src/Layout src/Theme \
	src/Storage src/Calls src/Wire src/Wire/Types src/Wire/Flatten src/Wire/Decode \
	src/Wire/Encode src/Media src/Stores src/Services src/Companions src/Utilities \
	src/Views src/Views/Cells \
	src/Screens/Chat src/Screens/Chat/Cells src/Screens/Chat/Items src/Screens/Chat/Layout \
	src/Screens/ChatList src/Screens/ChatList/Cells src/Screens/ChatList/Items \
	src/Screens/Settings src/Screens/Settings/Cells src/Screens/Settings/Items \
	src/Screens/Profile src/Screens/Profile/Cells src/Screens/Profile/Items \
	src/Screens/Contacts src/Screens/Contacts/Cells src/Screens/Contacts/Items \
	src/Screens/Groups src/Screens/Groups/Cells src/Screens/Groups/Items \
	src/Screens/Calls src/Screens/Calls/Items \
	src/Screens/Stories src/Screens/Stories/Cells src/Screens/Stories/Items \
	src/Screens/Stickers src/Screens/Stickers/Cells src/Screens/Stickers/Items \
	src/Screens/Stars src/Screens/Stars/Cells src/Screens/Stars/Items \
	src/Screens/Business src/Screens/Login src/Screens/Search src/Screens/Search/Items \
	src/Screens/Media src/Screens/Media/Cells src/Screens/Media/Items \
	src/Screens/Storage src/Screens/Storage/Cells src/Screens/Storage/Items \
	src/Screens/Payments src/Screens/Misc \
	third_party/webp/prebuilt) \
	-I$(IOS6_HOST_OPENSSL)/include \
	-I$(IOS6_HOST_OGG)/include \
	-I$(IOS6_HOST_QUIRC)/include \
	-I$(IOS6_HOST_OPUSENC)/include -I$(IOS6_HOST_OPUSENC)/include/opusenc \
	-I$(IOS6_HOST_OPUSFILE)/include \
	-I$(IOS6_HOST_OPUS)/include -I$(IOS6_HOST_OPUS)/include/opus \
	-I$(IOS6_HOST_LIBVPX)/include \
	-I$(IOS6_HOST_LIBTGVOIP)/include

CXX_STDLIB_SDK := $(firstword $(wildcard $(ROOT)/build/sdks/iPhoneOS16.5.sdk/usr/include/c++/v1) \
	$(wildcard $(ROOT)/build/sdks/iPhoneOS15.6.sdk/usr/include/c++/v1) \
	$(wildcard $(shell xcode-select -p)/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/usr/include/c++/v1))
CXX_STDLIB_INC := -isystem $(CXX_STDLIB_SDK)

APP_SRC_M := $(shell find $(ROOT)/src -name '*.m' -not -path '$(ROOT)/src/Resources/*' | sort)
ifneq ($(DEBUG_HARNESS),1)
APP_SRC_M := $(filter-out $(ROOT)/src/App/AppDelegate+DebugHarness.m,$(APP_SRC_M))
APP_SRC_M := $(filter-out $(ROOT)/src/App/AppDelegate+I18nDump.m,$(APP_SRC_M))
endif
APP_SRC_C := $(shell find $(ROOT)/src -name '*.c' -not -path '$(ROOT)/src/Resources/*' | sort)

VOIP_SRC_MM := src/Calls/TGCall.mm src/Utilities/TGDateUtils.mm \
	src/Media/TGVideoCapture.mm src/Media/TGVideoLoopback.mm

Telegram_FILES = $(APP_SRC_M) $(APP_SRC_C) $(VOIP_SRC_MM)

Telegram_CFLAGS = -O2 -fPIC -fno-modules -DTHEOS_LEAN_AND_MEAN $(SRC_INCLUDES) \
	-DTGVOIP_NO_DSP -DWEBRTC_POSIX -DTGVOIP_USE_CUSTOM_CRYPTO \
	-Wall -Wconditional-uninitialized -Wunreachable-code -Wobjc-missing-super-calls \
	-Wno-macro-redefined -Wno-deprecated-declarations -Wno-error
armv7_CFLAGS = -mthumb
Telegram_OBJCFLAGS = -fobjc-arc
Telegram_CCFLAGS = $(CXX_STDLIB_INC) -fno-cxx-modules -std=c++14 -fno-use-cxa-atexit -fno-threadsafe-statics -Wno-everything
Telegram_OBJCCFLAGS = $(CXX_STDLIB_INC) -fno-cxx-modules -std=c++14 -fno-use-cxa-atexit -fno-threadsafe-statics -fobjc-arc -Wno-everything

Telegram_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore AudioToolbox CoreMedia \
	CoreVideo AddressBook AddressBookUI MobileCoreServices CoreTelephony ImageIO \
	CoreText CFNetwork SystemConfiguration Security MapKit CoreLocation

Telegram_LDFLAGS = -Wl,-dead_strip -ObjC -Wl,-pagezero_size,0x1000 \
	-L$(IOS6_HOST_OPENSSL)/lib \
	-L$(IOS6_HOST_OGG)/lib -L$(IOS6_HOST_QUIRC)/lib -L$(IOS6_HOST_OPUSENC)/lib \
	-L$(IOS6_HOST_OPUSFILE)/lib -L$(IOS6_HOST_OPUS)/lib -L$(IOS6_HOST_LIBVPX)/lib \
	-L$(IOS6_HOST_LIBTGVOIP)/lib \
	-F$(ROOT)/third_party/webp/prebuilt -framework WebP \
	-ltgvoip -lopusfile -lopusenc -lquirc -lopus -lvpx -logg -lstdc++ -lz -lcrypto -lpthread

Telegram_INSTALL_PATH = /Applications
Telegram_CODESIGN_FLAGS = -S$(ROOT)/src/Resources/entitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

MACHOFIX := $(ROOT)/build/tools/machofix
BUNDLE := $(THEOS_STAGING_DIR)/Applications/Telegram.app

$(MACHOFIX): scripts/fix-armv7-macho.c
	@mkdir -p $(ROOT)/build/tools
	@cc -O2 -Wall -o $@ $<

before-all::
	@$(MAKE) --no-print-directory $(MACHOFIX)

after-stage::
	@cp -f $(ROOT)/src/Resources/Info.plist $(BUNDLE)/Info.plist
	@cp -rf $(ROOT)/src/Resources/images/* $(BUNDLE)/
	@if [ -d $(ROOT)/src/Resources/AppIcon ]; then \
		cp -f $(ROOT)/src/Resources/AppIcon/*.png $(BUNDLE)/; \
		/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Telegram" $(BUNDLE)/Info.plist; \
		/usr/libexec/PlistBuddy -c "Set :CFBundleName Telegram" $(BUNDLE)/Info.plist; \
	fi
	@cp -rf $(ROOT)/src/Resources/Localization/*.lproj $(BUNDLE)/
	@if [ -f $(IOS6_HOST_TDLIB_armv7)/lib/libtdjson.dylib ] && \
		[ -f $(IOS6_HOST_TDLIB_arm64)/lib/libtdjson.dylib ]; then \
		lipo -create $(IOS6_HOST_TDLIB_armv7)/lib/libtdjson.dylib \
			$(IOS6_HOST_TDLIB_arm64)/lib/libtdjson.dylib \
			-output $(BUNDLE)/libtdjson.dylib 2>/dev/null \
		|| cp -f $(IOS6_HOST_TDLIB_armv7)/lib/libtdjson.dylib $(BUNDLE)/; \
	elif [ -f $(IOS6_HOST_TDLIB_armv7)/lib/libtdjson.dylib ]; then \
		cp -f $(IOS6_HOST_TDLIB_armv7)/lib/libtdjson.dylib $(BUNDLE)/; \
	else \
		echo "$(ECHO_PREFIX) no libtdjson.dylib - conan install packaging/deps failed to produce one"; \
	fi
ifeq ($(DEBUG_HARNESS),1)
	@cp -f $(ROOT)/src/Resources/CustomKeys.txt $(BUNDLE)/
endif
	@if lipo -info $(BUNDLE)/Telegram 2>/dev/null | grep -q "Architectures in the fat file"; then \
		lipo -thin armv7 $(BUNDLE)/Telegram -output $(BUNDLE)/Telegram.armv7; \
		$(MACHOFIX) $(BUNDLE)/Telegram.armv7; \
		lipo -replace armv7 $(BUNDLE)/Telegram.armv7 $(BUNDLE)/Telegram \
			-output $(BUNDLE)/Telegram.fat; \
		mv -f $(BUNDLE)/Telegram.fat $(BUNDLE)/Telegram; \
		rm -f $(BUNDLE)/Telegram.armv7; \
	else \
		$(MACHOFIX) $(BUNDLE)/Telegram; \
	fi
	@ldid -S$(ROOT)/src/Resources/entitlements.plist $(BUNDLE)/Telegram
	@ldid -e $(BUNDLE)/Telegram | grep -q keychain-access-groups \
		|| { echo "error: entitlements missing from the binary - the keychain will refuse the passcode"; exit 1; }
