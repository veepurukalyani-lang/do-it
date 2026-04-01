#!/bin/bash

# 1. Download Flutter (Updated to 3.41.6 to match your SDK requirement)
FLUTTER_VERSION="3.41.6"
echo "Downloading Flutter $FLUTTER_VERSION..."
curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz

# 2. Extract Flutter
echo "Extracting Flutter..."
tar xf flutter_linux_${FLUTTER_VERSION}-stable.tar.xz
export PATH="$PATH:`pwd`/flutter/bin"

# 3. Increase memory for build
export NODE_OPTIONS="--max-old-space-size=4096"

# 4. Run the build
echo "Running Flutter build..."
flutter build web --release

# 5. Output should be in build/web
echo "Build complete."
