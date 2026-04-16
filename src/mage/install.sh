#!/bin/bash
set -e

echo "Activating feature 'mage'"

# Default version
MAGE_VERSION=${VERSION:-"latest"}

# Defailt install path
BIN=${BIN:-/usr/local/bin}

# Use a temporary locaiton for k9s archive
export TMP_DIR="/tmp/tmp-mage"
mkdir -p ${TMP_DIR}
chmod 700 ${TMP_DIR}

echo "Installing mage version $MAGE_VERSION"

# Clean up
rm -rf /var/lib/apt/lists/*

echo "Step 1, check if user is root"
if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

echo "Step 2, check if architecture is supported"
ARCHITECTURE="$(uname -m | sed s/aarch64/arm64/ | sed s/x86_64/64bit/)"
if [ "${ARCHITECTURE}" != "amd64" ] && [ "${ARCHITECTURE}" != "x86_64" ] && [ "${ARCHITECTURE}" != "arm64" ] && [ "${ARCHITECTURE}" != "aarch64" ]; then
    echo "(!) Architecture $ARCHITECTURE unsupported"
    exit 1
fi

ARCHITECTURE=$(echo $ARCHITECTURE | tr a-z A-Z)

echo "Step 3, check if platform is supported"
PLATFORM="$(uname -s)"
if [ "${PLATFORM}" != "Linux" ]; then
    echo "(!) Platform $PLATFORM unsupported"
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
check_packages ca-certificates curl unzip jq

MAGE_VERSION=$(curl -sL https://api.github.com/repos/magefile/mage/releases/latest \
  | jq -r '.tag_name')
MAGE_VERSION="${MAGE_VERSION#"v"}"

echo https://github.com/magefile/mage/releases/download/v${MAGE_VERSION}/mage_${MAGE_VERSION}_Linux-${ARCHITECTURE}.tar.gz

curl -sSL -o ${TMP_DIR}/mage.tar.gz "https://github.com/magefile/mage/releases/download/v${MAGE_VERSION}/mage_${MAGE_VERSION}_Linux-${ARCHITECTURE}.tar.gz"
tar -xzf "${TMP_DIR}/mage.tar.gz" -C "${TMP_DIR}" mage
mv ${TMP_DIR}/mage /usr/local/bin/mage
chmod 0755 /usr/local/bin/mage

# Clean up
rm -rf /var/lib/apt/lists/*
rm -rf ${TMP_DIR}

echo "Done!"