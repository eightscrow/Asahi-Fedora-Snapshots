#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"

need_cmd sudo
need_cmd dnf
need_cmd findmnt
need_cmd awk
need_cmd grep

is_fedora || die "This installer supports Fedora only."
is_asahi_kernel || warn "Asahi kernel not detected; continuing because Fedora was detected."

log "Starting Asahi Fedora snapper + grub-btrfs installer"

"$ROOT_DIR/scripts/install-packages.sh"
"$ROOT_DIR/scripts/setup-snapper.sh"
"$ROOT_DIR/scripts/setup-grub-btrfs.sh"
"$ROOT_DIR/scripts/verify.sh"

log "Installer completed successfully"
