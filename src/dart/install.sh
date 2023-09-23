#!/bin/sh
set -e

echo "Activating feature 'dart'"

# Default version
VERSION=${VERSION:-3.1.2}

# Defailt install path
BIN=${BIN:-/usr/local/bin}

echo "Installing dart version $VERSION"

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

export DART_SDK=/usr/lib/dart
export PATH=$DART_SDK/bin:/root/.pub-cache/bin:$PATH

# Install dart
set -eux; \
    case "$(dpkg --print-architecture)" in \
        amd64) \
            DART_SHA256=be679ccef3a0b28f19e296dd5b6374ac60dd0deb06d4d663da9905190489d48b; \
            SDK_ARCH="x64";; \
        armhf) \
            DART_SHA256=0be45ee5992be715cf57970f8b37f5be26d3be30202c420ce1606e10147223f0; \
            SDK_ARCH="arm";; \
        arm64) \
            DART_SHA256=395180693ccc758e4e830d3b13c4879e6e96b6869763a56e91721bf9d4228250; \
            SDK_ARCH="arm64";; \
    esac; \
    SDK="dartsdk-linux-${SDK_ARCH}-release.zip"; \
    BASEURL="https://storage.googleapis.com/dart-archive/channels"; \
    URL="$BASEURL/stable/release/$VERSION/sdk/$SDK"; \
    echo "SDK: $URL" >> dart_setup.log ; \
    curl -fLO "$URL"; \
    echo "$DART_SHA256 *$SDK" \
        | sha256sum --check --status --strict -; \
    unzip "$SDK" && mv dart-sdk "$DART_SDK" && rm "$SDK" \
        && chmod 755 "$DART_SDK" && chmod 755 "$DART_SDK/bin";

# Clean up
rm -rf /var/lib/apt/lists/*

echo "Done!"