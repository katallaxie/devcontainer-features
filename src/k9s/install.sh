#!/usr/bin/env bash

set -e

echo "Activating feature 'k9s'"

# Clean up
rm -rf /var/lib/apt/lists/*

K9S_VERSION=${VERSION:-"latest"}

echo "Step 1, check if user is root"
if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

echo "Step 2, check if architecture is supported"
ARCHITECTURE="$(uname -m | sed s/aarch64/arm64/ | sed s/x86_64/amd64/)"
if [ "${ARCHITECTURE}" != "amd64" ] && [ "${ARCHITECTURE}" != "x86_64" ] && [ "${ARCHITECTURE}" != "arm64" ] && [ "${ARCHITECTURE}" != "aarch64" ]; then
    echo "(!) Architecture $ARCHITECTURE unsupported"
    exit 1
fi

apt_get_update()
{
    echo "Running apt-get update..."
    apt-get update -y
}

# Checks if packages are installed and installs them if not
check_packages() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
            apt_get_update
        fi
        apt-get -y install --no-install-recommends "$@"
    fi
}

export DEBIAN_FRONTEND=noninteractive

# Install dependencies
check_packages curl git tar jq ca-certificates

# Use a temporary locaiton for k9s archive
export TMP_DIR="/tmp/tmp-k9s"
mkdir -p ${TMP_DIR}
chmod 700 ${TMP_DIR}

# Install k9s
echo "(*) Installing k9s..."

VERSION=$(curl -sL https://api.github.com/repos/derailed/k9s/releases/latest \
  | jq -r '.tag_name')
VERSION="${VERSION#"v"}"

curl -sSL -o ${TMP_DIR}/k9s.tar.gz "https://github.com/derailed/k9s/releases/download/v${VERSION}/k9s_Linux_${ARCHITECTURE}.tar.gz"
tar -xzf "${TMP_DIR}/k9s.tar.gz" -C "${TMP_DIR}" k9s
mv ${TMP_DIR}/k9s /usr/local/bin/k9s
chmod 0755 /usr/local/bin/k9s

# Clean up
rm -rf /var/lib/apt/lists/*
rm -rf ${TMP_DIR}

echo "Done!"