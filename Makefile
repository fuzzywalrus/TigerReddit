# Makefile for TigerReddit - Native C/Objective-C build
# No Python dependency - uses libcurl + cJSON for Reddit API access
#
# Targets Mac OS X 10.4 Tiger (PowerPC) with GCC 4.0
# Requires: Xcode 2.x Developer Tools, Tigerbrew curl & openssl
#
# Usage:
#   make          - build TigerReddit.app
#   make clean    - remove build artifacts
#   make debug    - run from command line with console output
#   make run      - open the app bundle

# ---- Compiler settings ------------------------------------------------
# On Tiger with Xcode 2.x, use gcc-4.0 explicitly:
#   CC = gcc-4.0
# On modern macOS for cross-testing, plain gcc works:
CC = gcc

# Architecture: ppc for PowerPC G3/G4/G5, i386 for Intel, or both
ARCH = ppc

CFLAGS = -arch $(ARCH) -mmacosx-version-min=10.4 -O2 -Wall
OBJCFLAGS = $(CFLAGS) -fobjc-exceptions

# ---- Frameworks -------------------------------------------------------
FRAMEWORKS = -framework Cocoa -framework Foundation

# ---- libcurl + OpenSSL (via Tigerbrew) --------------------------------
# Tigerbrew installs to /usr/local. Adjust if your setup differs.
#
# We prefer static linking so the app has no runtime deps beyond
# system frameworks. If static libs aren't available, fall back
# to dynamic linking (the user will need curl/openssl installed).
#
# Tigerbrew Cellar paths - adjust versions if yours differ.
# Run `ls /usr/local/Cellar/curl/ /usr/local/Cellar/openssl3/` to check.
CURL_VERSION    = 8.16.0
OPENSSL_VERSION = 3.5.0
CURL_PREFIX    = /usr/local/Cellar/curl/$(CURL_VERSION)
OPENSSL_PREFIX = /usr/local/Cellar/openssl3/$(OPENSSL_VERSION)

CURL_CFLAGS  = -I$(CURL_PREFIX)/include -I$(OPENSSL_PREFIX)/include
CURL_LDFLAGS = -L$(CURL_PREFIX)/lib -L$(OPENSSL_PREFIX)/lib

# Tigerbrew dependency paths (from `curl-config --static-libs`)
# Adjust versions to match your Cellar. Run:
#   ls /usr/local/Cellar/curl/ /usr/local/Cellar/openssl3/ etc.
NGHTTP2_PREFIX    = /usr/local/Cellar/libnghttp2/1.66.0
IDN2_PREFIX       = /usr/local/Cellar/libidn2/2.3.8
PSL_PREFIX        = /usr/local/Cellar/libpsl/0.21.5
ZLIB_PREFIX       = /usr/local/Cellar/zlib/1.3.1
UNISTRING_PREFIX  = /usr/local/Cellar/libunistring/1.3
ICONV_PREFIX      = /usr/local/Cellar/libiconv/1.18

# Static libraries for a fully self-contained binary
STATIC_CURL      = $(CURL_PREFIX)/lib/libcurl.a
STATIC_SSL       = $(OPENSSL_PREFIX)/lib/libssl.a
STATIC_CRYPTO    = $(OPENSSL_PREFIX)/lib/libcrypto.a
STATIC_NGHTTP2   = $(NGHTTP2_PREFIX)/lib/libnghttp2.a
STATIC_IDN2      = $(IDN2_PREFIX)/lib/libidn2.a
STATIC_PSL       = $(PSL_PREFIX)/lib/libpsl.a
STATIC_ZLIB      = $(ZLIB_PREFIX)/lib/libz.a
STATIC_UNISTRING = $(UNISTRING_PREFIX)/lib/libunistring.a
STATIC_ICONV     = $(ICONV_PREFIX)/lib/libiconv.a

# Check for static libs at build time
HAVE_STATIC = $(shell test -f $(STATIC_CURL) && test -f $(STATIC_SSL) && test -f $(STATIC_CRYPTO) && echo yes || echo no)

ifeq ($(HAVE_STATIC),yes)
    # Static link: bundle everything into the binary.
    # Full dependency chain: curl -> ssl/crypto, nghttp2, idn2, psl, z
    #                        idn2 -> unistring
    #                        psl  -> unistring, iconv
    CURL_LIBS = $(STATIC_CURL) $(STATIC_SSL) $(STATIC_CRYPTO) \
                $(STATIC_NGHTTP2) $(STATIC_IDN2) $(STATIC_PSL) \
                $(STATIC_UNISTRING) $(STATIC_ICONV) $(STATIC_ZLIB) \
                -framework CoreFoundation -framework CoreServices \
                -framework SystemConfiguration -framework LDAP \
                -liconv -lgcc
    LINK_MODE = static
else
    # Dynamic link fallback
    CURL_LIBS = -L$(CURL_PREFIX)/lib -L$(OPENSSL_PREFIX)/lib \
                -lcurl -lssl -lcrypto -lz
    LINK_MODE = dynamic
endif

# ---- Source files ------------------------------------------------------
APP_NAME    = TigerReddit
BUILD_DIR   = TigerReddit
BUNDLE_NAME = $(BUILD_DIR)/$(APP_NAME).app

OBJC_SOURCES = RedditViewer.m
C_SOURCES    = cJSON.c reddit_fetcher.c

OBJC_OBJECTS = $(OBJC_SOURCES:.m=.o)
C_OBJECTS    = $(C_SOURCES:.c=.o)
ALL_OBJECTS  = $(OBJC_OBJECTS) $(C_OBJECTS)

# ---- Targets -----------------------------------------------------------

all: check-cjson $(BUNDLE_NAME)
	@echo ""
	@echo "=== Build complete ($(LINK_MODE) curl) ==="
	@echo "Run with: open $(BUNDLE_NAME)"
	@echo "  or:     $(BUNDLE_NAME)/Contents/MacOS/$(APP_NAME)"

# Check if cJSON files exist
check-cjson:
	@if [ ! -f cJSON.c ] || [ ! -f cJSON.h ]; then \
		echo "ERROR: cJSON files not found!"; \
		echo "Download them:"; \
		echo "  curl -o cJSON.c https://raw.githubusercontent.com/DaveGamble/cJSON/v1.7.15/cJSON.c"; \
		echo "  curl -o cJSON.h https://raw.githubusercontent.com/DaveGamble/cJSON/v1.7.15/cJSON.h"; \
		exit 1; \
	fi

# Build the application bundle
$(BUNDLE_NAME): $(ALL_OBJECTS)
	@echo "Creating application bundle..."
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(BUNDLE_NAME)/Contents/MacOS
	@mkdir -p $(BUNDLE_NAME)/Contents/Resources
	$(CC) $(OBJCFLAGS) $(FRAMEWORKS) $(CURL_LDFLAGS) \
		-o $(BUNDLE_NAME)/Contents/MacOS/$(APP_NAME) \
		$(ALL_OBJECTS) $(CURL_LIBS)
	@echo '<?xml version="1.0" encoding="UTF-8"?>' > $(BUNDLE_NAME)/Contents/Info.plist
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> $(BUNDLE_NAME)/Contents/Info.plist
	@echo '<plist version="1.0">' >> $(BUNDLE_NAME)/Contents/Info.plist
	@echo '<dict>' >> $(BUNDLE_NAME)/Contents/Info.plist
	@echo '    <key>CFBundleExecutable</key>' >> $(BUNDLE_NAME)/Contents/Info.plist
	@echo '    <string>$(APP_NAME)</string>' >> $(BUNDLE_NAME)/Contents/Info.plist
	@echo '    <key>CFBundleIdentifier</key>' >> $(BUNDLE_NAME)/Contents/Info.plist
	@echo '    <string>com.tigerreddit.app</string>' >> $(BUNDLE_NAME)/Contents/Info.plist
	@echo '    <key>CFBundleName</key>' >> $(BUNDLE_NAME)/Contents/Info.plist
	@echo '    <string>$(APP_NAME)</string>' >> $(BUNDLE_NAME)/Contents/Info.plist
	@echo '    <key>CFBundlePackageType</key>' >> $(BUNDLE_NAME)/Contents/Info.plist
	@echo '    <string>APPL</string>' >> $(BUNDLE_NAME)/Contents/Info.plist
	@echo '    <key>CFBundleVersion</key>' >> $(BUNDLE_NAME)/Contents/Info.plist
	@echo '    <string>2.0.1</string>' >> $(BUNDLE_NAME)/Contents/Info.plist
	@echo '    <key>CFBundleIconFile</key>' >> $(BUNDLE_NAME)/Contents/Info.plist
	@echo '    <string>reddit.icns</string>' >> $(BUNDLE_NAME)/Contents/Info.plist
	@echo '    <key>LSMinimumSystemVersion</key>' >> $(BUNDLE_NAME)/Contents/Info.plist
	@echo '    <string>10.4.0</string>' >> $(BUNDLE_NAME)/Contents/Info.plist
	@echo '</dict>' >> $(BUNDLE_NAME)/Contents/Info.plist
	@echo '</plist>' >> $(BUNDLE_NAME)/Contents/Info.plist
	@if [ -f reddit.icns ]; then \
		cp reddit.icns $(BUNDLE_NAME)/Contents/Resources/; \
		echo "Icon bundled"; \
	fi
	@if [ -f ca-bundle.crt ]; then \
		cp ca-bundle.crt $(BUNDLE_NAME)/Contents/Resources/; \
		echo "CA bundle bundled"; \
	elif [ -f /usr/local/opt/curl-ca-bundle/share/ca-bundle.crt ]; then \
		cp /usr/local/opt/curl-ca-bundle/share/ca-bundle.crt $(BUNDLE_NAME)/Contents/Resources/; \
		echo "CA bundle copied from Tigerbrew"; \
	fi
	@if [ -f remux_fmp4.py ]; then \
		echo "Bundling remux script..."; \
		cp remux_fmp4.py $(BUNDLE_NAME)/Contents/Resources/; \
	fi
	@if [ -d yt-dlp-master ]; then \
		echo "Bundling yt-dlp..."; \
		cp -r yt-dlp-master $(BUNDLE_NAME)/Contents/Resources/; \
		chmod +x $(BUNDLE_NAME)/Contents/Resources/yt-dlp-master/yt-dlp; \
	fi
	@echo "Built $(BUNDLE_NAME) successfully!"

# Compile Objective-C files
%.o: %.m
	$(CC) $(OBJCFLAGS) $(CURL_CFLAGS) -c $< -o $@

# Compile C files
%.o: %.c
	$(CC) $(CFLAGS) $(CURL_CFLAGS) -c $< -o $@

# Clean build artifacts
clean:
	rm -f $(ALL_OBJECTS)
	rm -rf $(BUILD_DIR)

# Run the application
run: $(BUNDLE_NAME)
	open $(BUNDLE_NAME)

# Debug - run from command line to see console output
debug: $(BUNDLE_NAME)
	$(BUNDLE_NAME)/Contents/MacOS/$(APP_NAME)

# Show link mode
info:
	@echo "Architecture:  $(ARCH)"
	@echo "Compiler:      $(CC)"
	@echo "Curl linking:  $(LINK_MODE)"
	@echo "Static curl:   $(STATIC_CURL) (exists: $(HAVE_STATIC))"

.PHONY: all clean run debug info check-cjson
