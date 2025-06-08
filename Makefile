ARCHS := arm64
PACKAGE_FORMAT := ipa
TARGET := iphone:clang:latest:15.0
include $(THEOS)/makefiles/common.mk

ADDITIONAL_LDFLAGS = -rpath @loader_path/Frameworks
THEOS_PACKAGE_SCHEME = rootless

TWEAK_NAME = SpringBoardTweak
SpringBoardTweak_FILES = Tweak.x
SpringBoardTweak_CFLAGS = -fobjc-arc
SpringBoardTweak_INSTALL_PATH = /Applications/SpringBoard.app
SpringBoardTweak_FRAMEWORKS = CoreServices UIKit
#SpringBoardTweak_PRIVATE_FRAMEWORKS = CommonUtilities UIKitServices WatchdogClient FrontBoard
include $(THEOS_MAKE_PATH)/tweak.mk

APPLICATION_NAME = SpringBoard
# $(APPLICATION_NAME)_FRAMEWORKS = CydiaSubstrate
# $(APPLICATION_NAME)_PRIVATE_FRAMEWORKS = ChronoServices FrontBoard
$(APPLICATION_NAME)_BUNDLE_NAME = SpringBoard
$(APPLICATION_NAME)_FILES = \
  hook.m \
  main.m \
  SBLCSceneDelegate.m \
  IgnoredAssertionHandler.m \
  fishhook/fishhook.c \
  ellekit/mach_excServer.c \
  ellekit/ElleKitJITLessHook.m
$(APPLICATION_NAME)_CFLAGS = -fcommon -fobjc-arc -Wno-error
$(APPLICATION_NAME)_CODESIGN_FLAGS = -Sentitlements.plist -Icom.apple.springboardts

include $(THEOS_MAKE_PATH)/application.mk

before-package::
	@# can't use simforge now
	@if [[ "$(SIMULATOR)" == 1 ]]; then \
	vtool -arch arm64 -set-build-version 7 14.0 14.0 -replace -output $(THEOS_STAGING_DIR)/Applications/SpringBoard.app/SpringBoard $(THEOS_STAGING_DIR)/Applications/SpringBoard.app/SpringBoard; \
	vtool -arch arm64 -set-build-version 7 14.0 14.0 -replace -output $(THEOS_STAGING_DIR)/Applications/SpringBoard.app/SpringBoardTweak.dylib $(THEOS_STAGING_DIR)/Applications/SpringBoard.app/SpringBoardTweak.dylib; \
	vtool -arch arm64 -set-build-version 7 14.0 14.0 -replace -output $(THEOS_STAGING_DIR)/Applications/SpringBoard.app/Frameworks/CydiaSubstrate.framework/CydiaSubstrate $(THEOS_STAGING_DIR)/Applications/SpringBoard.app/Frameworks/CydiaSubstrate.framework/CydiaSubstrate; \
	ldid -S -M $(THEOS_STAGING_DIR)/Applications/SpringBoard.app; \
	fi
