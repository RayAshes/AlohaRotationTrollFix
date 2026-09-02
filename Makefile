ARCHS = arm64e
TARGET = iphone:clang:15.0:15.0
INSTALL_TARGET_PROCESSES = Aloha
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AlohaRotationTrollFix

AlohaRotationTrollFix_FILES = Tweak.xm
AlohaRotationTrollFix_CFLAGS = -fobjc-arc -O2
AlohaRotationTrollFix_FRAMEWORKS = CoreMotion
AlohaRotationTrollFix_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk