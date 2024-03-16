ARCHS := arm64
PACKAGE_FORMAT := ipa
TARGET := iphone:clang:latest:15.0
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SpringBoardTweak
SpringBoardTweak_FILES = Tweak.x
SpringBoardTweak_CFLAGS = -fobjc-arc
SpringBoardTweak_INSTALL_PATH = /Applications/SpringBoardTS.app
SpringBoardTweak_FRAMEWORKS = UIKit
SpringBoardTweak_PRIVATE_FRAMEWORKS = CommonUtilities UIKitServices WatchdogClient
# CommonUtilities UIKitServices SpringBoard ToneLibrary WatchdogClient
include $(THEOS_MAKE_PATH)/tweak.mk

APPLICATION_NAME = SpringBoardTS
$(APPLICATION_NAME)_FRAMEWORKS = CydiaSubstrate
# $(APPLICATION_NAME)_PRIVATE_FRAMEWORKS = ChronoServices FrontBoard
$(APPLICATION_NAME)_FILES = main.m InternalHook.x
$(APPLICATION_NAME)_CFLAGS = -fcommon -fobjc-arc -Wno-error
$(APPLICATION_NAME)_CODESIGN_FLAGS = -Sentitlements.plist -Icom.apple.springboardts

include $(THEOS_MAKE_PATH)/application.mk
