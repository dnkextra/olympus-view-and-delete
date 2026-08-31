#!/usr/bin/env bash
# Checks for build dependencies on Debian, installs anything missing,
# then builds a release APK for this project.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLUTTER_DIR="$HOME/flutter"
ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
CMDLINE_TOOLS="$ANDROID_HOME/cmdline-tools/latest/bin"

REQUIRED_PLATFORM="platforms;android-36"
REQUIRED_NDK="ndk;28.2.13676358"
REQUIRED_BUILD_TOOLS="build-tools;35.0.0"

echo "== 1. Java =="
if ! command -v java >/dev/null 2>&1; then
    echo "Installing OpenJDK 17..."
    sudo apt-get update
    sudo apt-get install -y openjdk-17-jdk
else
    echo "Java found: $(java -version 2>&1 | head -1)"
fi

echo "== 2. Flutter SDK =="
if ! command -v flutter >/dev/null 2>&1; then
    if [ -d "$FLUTTER_DIR" ]; then
        echo "Found existing $FLUTTER_DIR, adding to PATH for this run."
    else
        echo "Cloning Flutter stable into $FLUTTER_DIR..."
        git clone --depth 1 https://github.com/flutter/flutter.git -b stable "$FLUTTER_DIR"
    fi
    export PATH="$PATH:$FLUTTER_DIR/bin"
    if ! grep -q 'flutter/bin' "$HOME/.bashrc" 2>/dev/null; then
        echo "export PATH=\"\$PATH:$FLUTTER_DIR/bin\"" >> "$HOME/.bashrc"
        echo "Added Flutter to PATH in ~/.bashrc (open a new shell to pick it up)."
    fi
else
    echo "Flutter found: $(flutter --version | head -1)"
fi

echo "== 3. Android SDK components =="
if [ ! -x "$CMDLINE_TOOLS/sdkmanager" ]; then
    echo "ERROR: sdkmanager not found at $CMDLINE_TOOLS/sdkmanager"
    echo "Install Android cmdline-tools first, then re-run this script."
    exit 1
fi

export ANDROID_HOME
export ANDROID_SDK_ROOT="$ANDROID_HOME"

echo "Installing/verifying: $REQUIRED_PLATFORM, $REQUIRED_BUILD_TOOLS, $REQUIRED_NDK"
yes | "$CMDLINE_TOOLS/sdkmanager" \
    "$REQUIRED_PLATFORM" \
    "$REQUIRED_BUILD_TOOLS" \
    "$REQUIRED_NDK" >/dev/null

echo "Accepting Android SDK licenses..."
yes | "$CMDLINE_TOOLS/sdkmanager" --licenses >/dev/null || true

echo "== 4. flutter doctor =="
flutter doctor

echo "== 5. Building release APK =="
cd "$PROJECT_DIR"
flutter pub get
flutter build apk --release

APK_PATH="$PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK_PATH" ]; then
    echo
    echo "Build succeeded: $APK_PATH"
else
    echo "Build finished but APK not found at expected path."
    exit 1
fi
