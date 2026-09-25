APP     := SayRight
CONFIG  ?= debug
BUNDLE  := build/$(APP).app
BIN      = $(shell swift build -c $(CONFIG) --show-bin-path)/$(APP)
SIGN_ID ?= SayRight Self Signed
# Command Line Tools hide the swift-testing macro plugin in a subdirectory that
# is not on the default plugin search path, so point the compiler at it.
DEVELOPER_DIR := $(shell xcode-select -p)
TESTING_MACROS = $(shell find $(DEVELOPER_DIR)/usr/lib/swift/host/plugins \
	$(DEVELOPER_DIR)/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins \
	-name 'libTestingMacros.dylib' 2>/dev/null | head -1)

.PHONY: build bundle sign run test install clean cert

build:
	swift build -c $(CONFIG)

bundle: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	cp Resources/Info.plist $(BUNDLE)/Contents/Info.plist
	cp $(BIN) $(BUNDLE)/Contents/MacOS/$(APP)
	@$(MAKE) --no-print-directory sign

# A self-signed cert keeps the code signature stable across rebuilds, so macOS
# does not revoke the Accessibility grant every time. `make cert` creates it.
sign:
	@if security find-identity -v -p codesigning | grep -q "$(SIGN_ID)"; then \
		codesign --force --sign "$(SIGN_ID)" $(BUNDLE); \
	else \
		echo "warn: no '$(SIGN_ID)' certificate found - ad-hoc signing."; \
		echo "      Accessibility permission will reset on every rebuild. See README."; \
		codesign --force --sign - $(BUNDLE); \
	fi

cert:
	@./Scripts/make-cert.sh

run: bundle
	@pkill -x $(APP) || true
	open $(BUNDLE)

install: CONFIG := release
install: bundle
	rm -rf /Applications/$(APP).app
	cp -R $(BUNDLE) /Applications/

test:
	swift test $(if $(TESTING_MACROS),-Xswiftc -load-plugin-library -Xswiftc $(TESTING_MACROS),)

clean:
	rm -rf .build build
