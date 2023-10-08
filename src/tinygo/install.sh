#!/bin/sh
set -e

echo "Activating feature 'tinygo'"

# Default version
VERSION=${VERSION:-0.30.0}

# Defailt install path
BIN=${BIN:-/usr/local/bin}

echo "Installing TinyGo version $VERSION"

# Clean up
rm -rf /var/lib/apt/lists/*

echo "Step 1, check if user is root"
if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

echo "Step 2, check if architecture is supported"
architecture="$(uname -m)"
if [ "${architecture}" != "amd64" ] && [ "${architecture}" != "x86_64" ] && [ "${architecture}" != "arm64" ] && [ "${architecture}" != "aarch64" ]; then
    echo "(!) Architecture $architecture unsupported"
    exit 1
fi

apt_get_update()
{
    if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
        echo "Running apt-get update..."
        apt-get update -y
    fi
}

# Checks if packages are installed and installs them if not
check_packages()
{
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        apt_get_update
        apt-get -y install --no-install-recommends "$@"
    fi
}

export DEBIAN_FRONTEND=noninteractive

# Install dependencies
check_packages ca-certificates curl unzip

set -eux; \
    ARCHITECTURE="$(dpkg --print-architecture)"; \
    URL="https://github.com/tinygo-org/tinygo/releases/download/v${VERSION}/tinygo_${VERSION}_${ARCHITECTURE}.deb"; \
    curl -fLO "$URL"
    dpkg -i "tinygo_${VERSION}_${ARCHITECTURE}.deb"

# Clean up
rm -rf /var/lib/apt/lists/*

echo "Done!"