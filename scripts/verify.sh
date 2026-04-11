#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"

need_cmd snapper
need_cmd grub2-mkconfig

has_snapper_config root || die "snapper root config missing"

if is_btrfs_mount /home; then
  has_snapper_config home || die "snapper home config missing (home is BTRFS)"
fi

run_sudo test -x /etc/grub.d/41_snapshots-btrfs || die "grub-btrfs script missing"
run_sudo test -f /etc/default/grub-btrfs/config || die "grub-btrfs config missing"
run_sudo test -f /boot/grub2/grub.cfg || die "grub.cfg missing"

if ! run_sudo grep -q 'grub-btrfs\.cfg' /boot/grub2/grub.cfg; then
  die "grub-btrfs include not found in /boot/grub2/grub.cfg"
fi

run_sudo systemctl is-enabled snapper-timeline.timer >/dev/null || die "snapper-timeline.timer is not enabled"
run_sudo systemctl is-enabled snapper-cleanup.timer >/dev/null || die "snapper-cleanup.timer is not enabled"

if systemctl list-unit-files 2>/dev/null | grep -q '^grub-btrfsd\.service'; then
  run_sudo systemctl is-enabled grub-btrfsd >/dev/null || die "grub-btrfsd is not enabled"
fi

log "Verification successful"
