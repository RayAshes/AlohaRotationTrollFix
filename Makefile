THEOS_PACKAGE_SCHEME ?= roothide
TARGET := iphone:clang:16.5:15.0

include $(THEOS)/makefiles/common.mk

ARCHS = arm64e

TWEAK_NAME = AlohaRotationTrollFix
AlohaRotationTrollFix_FILES = Tweak.xm
AlohaRotationTrollFix_CFLAGS = -fobjc-arc -O2
AlohaRotationTrollFix_FRAMEWORKS = CoreMotion
AlohaRotationTrollFix_LIBRARIES = substrate
AlohaRotationTrollFix_INSTALL_TARGET_PROCESSES = Aloha

include $(THEOS_MAKE_PATH)/tweak.mk