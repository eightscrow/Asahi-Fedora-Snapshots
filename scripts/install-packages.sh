#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"

packages=(
  btrfs-progs
  snapper
  python3-dnf-plugin-snapper
  inotify-tools
  btrfs-assistant
  grub2-tools
  grub2-tools-extra
  git
  make
)

log "Installing required Fedora packages"
run_sudo dnf install -y "${packages[@]}"

log "Package install step complete"
