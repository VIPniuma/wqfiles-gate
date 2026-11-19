# DoroSB SpringBoard tweak 编译（macOS + Xcode 命令行工具）
SDK     := $(shell xcrun --sdk iphoneos --show-sdk-path)
CC      := xcrun -sdk iphoneos clang
OUT     := libDoroSB.dylib

SRC := DoroSBEntry.m DoroSBBall.m DoroSBWriter.m DoroSBCardBridge.m DoroSBAppExit.m
CFLAGS := -arch arm64 -miphoneos-version-min=15.0 -isysroot $(SDK) -fobjc-arc -O2 \
          -dynamiclib -Wl,-install_name,/Library/MobileSubstrate/DynamicLibraries/$(OUT) \
          -framework Foundation -framework UIKit -framework Security \
          -Wl,-no_adhoc_codesign

all:
	$(CC) $(CFLAGS) -I. $(SRC) -o $(OUT)
	ldid -S $(OUT) || true
	@echo "built: $(OUT)"

clean:
	rm -f $(OUT)

.PHONY: all clean
