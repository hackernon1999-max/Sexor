TARGET := iphone:clang:14.5:14.0
ARCHS = arm64
DEBUG = 0
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Outlaw

Outlaw_FILES = Tweak.xm
Outlaw_FRAMEWORKS = UIKit Foundation
Outlaw_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/tweak.mk
