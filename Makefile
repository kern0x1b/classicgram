export THEOS_PACKAGE_SCHEME =

TARGET := iphone:clang:9.3:6.0
ARCHS := armv7 arm64
INSTALL_TARGET_PROCESSES = Telegram

PACKAGE_VERSION ?= 1.16.48

SYSROOT ?= $(CURDIR)/build/sdks/iPhoneOS12.4.sdk
ifeq ($(wildcard $(SYSROOT)),)
SYSROOT := $(CURDIR)/build/sdks/iPhoneOS9.3.sdk
endif
ISYSROOT := $(SYSROOT)

include $(THEOS)/makefiles/common.mk

MODULESFLAGS :=
_THEOS_INTERNAL_IFLAGS_BASE = -I$(THEOS_TARGET_INCLUDE_PATH)

APPLICATION_NAME = Telegram

ROOT := $(THEOS_PROJECT_DIR)

SRC_INCLUDES := $(addprefix -I$(ROOT)/,\
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
	third_party third_party/openssl/prebuilt/include third_party/webp/prebuilt third_party/ogg third_party/ogg/ogg \
	third_party/opus/prebuilt/include third_party/opus/prebuilt/include/opus \
	third_party/opusenc third_party/opusfile third_party/libvpx third_party/libtgvoip \
	third_party/tdlib/td) \
	-I$(ROOT)/build/$(THEOS_CURRENT_ARCH)/tdlib/include

CXX_STDLIB_INC := -isystem $(shell xcode-select -p)/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/usr/include/c++/v1

APP_SRC_M := $(shell find $(ROOT)/src -name '*.m' -not -path '$(ROOT)/src/Resources/*' | sort)
ifneq ($(DEBUG_HARNESS),1)
APP_SRC_M := $(filter-out $(ROOT)/src/App/AppDelegate+DebugHarness.m,$(APP_SRC_M))
APP_SRC_M := $(filter-out $(ROOT)/src/App/AppDelegate+I18nDump.m,$(APP_SRC_M))
endif
APP_SRC_C := $(shell find $(ROOT)/src -name '*.c' -not -path '$(ROOT)/src/Resources/*' | sort)

THIRD_PARTY_SRC_C := $(addprefix third_party/,\
	quirc/quirc.c quirc/identify.c quirc/decode.c quirc/version_db.c \
	opusfile/internal.c opusfile/opusfile.c opusfile/info.c opusfile/stream.c \
	ogg/ogg/framing.c ogg/ogg/bitwise.c opusenc/opus_header.c)

VOIP_SRC := $(addprefix third_party/libtgvoip/,\
	VoIPController.cpp VoIPServerConfig.cpp logging.cpp json11.cpp \
	video/ScreamCongestionController.cpp video/VideoSource.cpp video/TGVP8Codec.cpp \
	os/darwin/TGCallVideoSource.cpp os/darwin/TGCallVideoRenderer.cpp \
	JitterBuffer.cpp OpusEncoder.cpp OpusDecoder.cpp NetworkSocket.cpp \
	CongestionControl.cpp EchoCanceller.cpp MessageThread.cpp Buffers.cpp \
	BlockingQueue.cpp MediaStreamItf.cpp PacketReassembler.cpp \
	audio/AudioIO.cpp audio/AudioInput.cpp audio/AudioOutput.cpp audio/Resampler.cpp \
	os/darwin/AudioUnitIO.cpp os/darwin/AudioInputAudioUnit.cpp \
	os/darwin/AudioOutputAudioUnit.cpp os/posix/NetworkSocketPosix.cpp \
	os/darwin/DarwinSpecific.mm os/darwin/TGVTDynamic.mm)

VOIP_SRC_MM := src/Calls/TGCall.mm src/Utilities/TGDateUtils.mm \
	src/Media/TGVideoCapture.mm src/Media/TGVideoLoopback.mm

Telegram_FILES = $(APP_SRC_M) $(APP_SRC_C) $(THIRD_PARTY_SRC_C) $(VOIP_SRC) $(VOIP_SRC_MM)

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
	-L$(ROOT)/build/$(THEOS_CURRENT_ARCH)/libs -L$(ROOT)/build/$(THEOS_CURRENT_ARCH)/tdlib/lib \
	-L$(ROOT)/third_party/opus/prebuilt/lib -L$(ROOT)/build/$(THEOS_CURRENT_ARCH)/libvpx-obj \
	-F$(ROOT)/third_party/webp/prebuilt -framework WebP \
	-lvpx -lopus -lstdc++ -lz -lcrypto -lpthread

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
	@scripts/build-libvpx.sh armv7
	@$(foreach a,$(filter-out armv7,$(ARCHS)),scripts/build-libvpx.sh $(a);)

after-stage::
	@cp -f $(ROOT)/src/Resources/Info.plist $(BUNDLE)/Info.plist
	@cp -rf $(ROOT)/src/Resources/images/* $(BUNDLE)/
	@cp -rf $(ROOT)/src/Resources/Localization/*.lproj $(BUNDLE)/
	@if [ -f $(ROOT)/build/armv7/tdlib/lib/libtdjson.dylib ] && \
		[ -f $(ROOT)/build/arm64/tdlib/lib/libtdjson.dylib ]; then \
		lipo -create $(ROOT)/build/armv7/tdlib/lib/libtdjson.dylib \
			$(ROOT)/build/arm64/tdlib/lib/libtdjson.dylib \
			-output $(BUNDLE)/libtdjson.dylib 2>/dev/null \
		|| cp -f $(ROOT)/build/armv7/tdlib/lib/libtdjson.dylib $(BUNDLE)/; \
	elif [ -f $(ROOT)/build/armv7/tdlib/lib/libtdjson.dylib ]; then \
		cp -f $(ROOT)/build/armv7/tdlib/lib/libtdjson.dylib $(BUNDLE)/; \
	else \
		echo "$(ECHO_PREFIX) no libtdjson.dylib yet - run scripts/build-tdlib-dylib.sh"; \
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
