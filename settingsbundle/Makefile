TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e
include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = AutoLowPowerSettings

AutoLowPowerSettings_FILES = RootListController.m
AutoLowPowerSettings_FRAMEWORKS = UIKit
AutoLowPowerSettings_PRIVATE_FRAMEWORKS = Preferences
AutoLowPowerSettings_INSTALL_PATH = /Library/PreferenceBundles
AutoLowPowerSettings_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/AutoLowPowerSettings.plist$(ECHO_END)
