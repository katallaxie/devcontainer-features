#!/usr/bin/env bash

set -e

echo "Activating feature 'k9s'"

# Clean up
rm -rf /var/lib/apt/lists/*

K9S_VERSION=${VERSION:-"latest"}

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
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

# from https://stackoverflow.com/questions/4023830/how-to-compare-two-strings-in-dot-separated-version-format-in-bash
function vercomp() {
  if [[ "$1" == "$2" ]]; then
    return 0
  fi
  local IFS=.
  # shellcheck disable=SC2206
  local i ver1=($1) ver2=($2)
  # fill empty fields in ver1 with zeros
  for ((i = ${#ver1[@]}; i < ${#ver2[@]}; i++)); do
    ver1[i]=0
  done
  for ((i = 0; i < ${#ver1[@]}; i++)); do
    if [[ -z ${ver2[i]} ]]; then
      # fill empty fields in ver2 with zeros
      ver2[i]=0
    fi
    if ((10#${ver1[i]} > 10#${ver2[i]})); then
      return 1
    fi
    if ((10#${ver1[i]} < 10#${ver2[i]})); then
      return 2
    fi
  done
  return 0
}

get_architecture() {
    local version="$1"
    local architecture_
    architecture="$(uname -m)"
    case $architecture in
        x86_64) architecture_="amd64";;
        aarch64 | armv8* | arm64) architecture_="arm64";;
        *) echo "(!) Architecture $architecture unsupported"; exit 1 ;;
    esac

    # x86_64 before 0.27.0
    vercomp "$version" "0.27.0"
    case $? in
    0) op='=' ;;
    1) op='>' ;;
    2) op='<' ;;
    esac
    if [[ "$op" == '<' && "$architecture" == 'x86_64' ]]; then
        architecture_="x86_64"
    fi

    echo "${architecture_}"
}

export DEBIAN_FRONTEND=noninteractive

# Install dependencies
check_packages curl git tar

# Use a temporary locaiton for k9s archive
export TMP_DIR="/tmp/tmp-k9s"
mkdir -p ${TMP_DIR}
chmod 700 ${TMP_DIR}

# Install k9s
echo "(*) Installing k9s..."

VERSION=$(curl -sL https://api.github.com/repos/derailed/k9s/releases/latest \
  | jq -r '.tag_name')
VERSION="${VERSION#"v"}"

ARCHITECTURE=$(get_architecture "$VERSION")

curl -sSL -o ${TMP_DIR}/k9s.tar.gz "https://github.com/derailed/k9s/releases/download/v${VERSION}/k9s_Linux_${ARCHITECTURE}.tar.gz"
tar -xzf "${TMP_DIR}/k9s.tar.gz" -C "${TMP_DIR}" k9s
mv ${TMP_DIR}/k9s /usr/local/bin/k9s
chmod 0755 /usr/local/bin/k9s

# Clean up
rm -rf /var/lib/apt/lists/*
rm -rf ${TMP_DIR}

echo "Done!"