export THEOS_PACKAGE_SCHEME = rootless

ARCHS = arm64 arm64e
# "latest" instead of a hardcoded SDK point release (e.g. 16.5) - this is
# Theos's own recommended pattern (see theos.dev/docs/rootless) and avoids
# build failures when the build machine has a different SDK point release
# installed than whoever last touched this Makefile.
TARGET := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = NoStrongPass

NoStrongPass_FILES = Tweak.xm
NoStrongPass_CFLAGS = -fobjc-arc
NoStrongPass_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
