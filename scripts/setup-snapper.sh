#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"

need_cmd snapper
need_cmd btrfs

if ! is_btrfs_mount /; then
  die "Root filesystem is not BTRFS."
fi

if ! has_snapper_config root; then
  if run_sudo btrfs subvolume list / 2>/dev/null | grep -q ' path \.snapshots$'; then
    log "Removing leftover /.snapshots subvolume before creating root config"
    run_sudo find /.snapshots -mindepth 2 -maxdepth 2 -name snapshot -exec btrfs subvolume delete {} \; 2>/dev/null || true
    run_sudo btrfs subvolume delete /.snapshots 2>/dev/null || true
  fi
  log "Creating snapper config: root"
  run_snapper -c root create-config /
fi

if is_btrfs_mount /home; then
  if ! has_snapper_config home; then
    if run_sudo btrfs subvolume list /home 2>/dev/null | grep -q 'path @home/\.snapshots$\| path \.snapshots$'; then
      log "Removing leftover /home/.snapshots subvolume before creating home config"
      run_sudo find /home/.snapshots -mindepth 2 -maxdepth 2 -name snapshot -exec btrfs subvolume delete {} \; 2>/dev/null || true
      run_sudo btrfs subvolume delete /home/.snapshots 2>/dev/null || true
    fi
    log "Creating snapper config: home"
    run_snapper -c home create-config /home
  fi
else
  warn "/home is not BTRFS, skipping home snapper config"
fi

log "Applying root snapper retention policy"
set_snapper_config root \
  NUMBER_CLEANUP=yes \
  NUMBER_LIMIT=8 \
  NUMBER_LIMIT_IMPORTANT=6 \
  TIMELINE_CREATE=yes \
  TIMELINE_CLEANUP=yes \
  TIMELINE_LIMIT_HOURLY=6 \
  TIMELINE_LIMIT_DAILY=5 \
  TIMELINE_LIMIT_WEEKLY=3 \
  TIMELINE_LIMIT_MONTHLY=1 \
  TIMELINE_LIMIT_YEARLY=0 \
  EMPTY_PRE_POST_CLEANUP=yes

if has_snapper_config home; then
  log "Applying home snapper retention policy"
  set_snapper_config home \
    NUMBER_CLEANUP=no \
    NUMBER_LIMIT=0 \
    NUMBER_LIMIT_IMPORTANT=0 \
    TIMELINE_CREATE=yes \
    TIMELINE_CLEANUP=yes \
    TIMELINE_LIMIT_HOURLY=4 \
    TIMELINE_LIMIT_DAILY=5 \
    TIMELINE_LIMIT_WEEKLY=2 \
    TIMELINE_LIMIT_MONTHLY=1 \
    TIMELINE_LIMIT_YEARLY=0 \
    EMPTY_PRE_POST_CLEANUP=yes
fi

log "Enabling snapper timeline and cleanup timers"
run_sudo systemctl enable --now snapper-timeline.timer snapper-cleanup.timer

log "Snapper setup complete"
