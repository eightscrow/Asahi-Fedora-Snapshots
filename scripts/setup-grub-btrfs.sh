#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"

need_cmd snapper
need_cmd git
need_cmd make
need_cmd grub2-mkconfig

grub_script_check() { run_sudo test -x /etc/grub.d/41_snapshots-btrfs 2>/dev/null; }

if ! grub_script_check; then
  tmpdir=$(mktemp -d /tmp/asahi-fedora-grub-btrfs.XXXXXX)
  trap 'rm -rf "$tmpdir"' EXIT

  log "Installing grub-btrfs from upstream"
  git clone --depth=1 https://github.com/Antynea/grub-btrfs.git "$tmpdir/grub-btrfs"

  (cd "$tmpdir/grub-btrfs" && run_sudo make GRUB_UPDATE_EXCLUDE=true install) || {
    warn "make install exited non-zero, continuing to fallback"
  }

  # Fallback: /etc/grub.d/ may be mode 700 (root-only), so make install can
  # succeed silently while non-root -x checks return false. Copy manually.
  if ! grub_script_check; then
    if [[ -f "$tmpdir/grub-btrfs/41_snapshots-btrfs" ]]; then
      log "Applying fallback install for 41_snapshots-btrfs"
      run_sudo install -Dm755 "$tmpdir/grub-btrfs/41_snapshots-btrfs" /etc/grub.d/41_snapshots-btrfs
    else
      die "41_snapshots-btrfs not found in cloned source at $tmpdir/grub-btrfs/"
    fi
  fi

fi

grub_script_check || die "grub-btrfs install failed (missing /etc/grub.d/41_snapshots-btrfs)"

config_file="/etc/default/grub-btrfs/config"
mkconfig_lib="/usr/share/grub/grub-mkconfig_lib"
if [[ ! -f "$mkconfig_lib" && -f "/usr/share/grub2/grub-mkconfig_lib" ]]; then
  mkconfig_lib="/usr/share/grub2/grub-mkconfig_lib"
fi

log "Writing Fedora grub-btrfs config"
write_kv_config "$config_file" "GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS" '"rd.live.overlay.overlayfs=1"'
write_kv_config "$config_file" "GRUB_BTRFS_GRUB_DIRNAME" '"/boot/grub2"'
write_kv_config "$config_file" "GRUB_BTRFS_MKCONFIG" '/usr/bin/grub2-mkconfig'
write_kv_config "$config_file" "GRUB_BTRFS_SCRIPT_CHECK" 'grub2-script-check'
write_kv_config "$config_file" "GRUB_BTRFS_MKCONFIG_LIB" "$mkconfig_lib"

root_snapshot_count=$(run_snapper -c root list 2>/dev/null | awk 'NR>2 && $1 ~ /^[1-9][0-9]*$/ {count++} END {print count+0}')
if (( root_snapshot_count == 0 )); then
  log "Creating bootstrap root snapshot"
  run_snapper -c root create --description "asahi fedora installer bootstrap snapshot" --cleanup-algorithm number
fi

if has_snapper_config home; then
  home_snapshot_count=$(run_snapper -c home list 2>/dev/null | awk 'NR>2 && $1 ~ /^[1-9][0-9]*$/ {count++} END {print count+0}')
  if (( home_snapshot_count == 0 )); then
    log "Creating bootstrap home snapshot"
    run_snapper -c home create --description "asahi fedora installer bootstrap snapshot" --cleanup-algorithm timeline
  fi
fi

if [[ -d /boot/grub2 ]]; then
  log "Regenerating /boot/grub2/grub.cfg"
  run_sudo grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/null
else
  die "/boot/grub2 directory not found"
fi

if systemctl list-unit-files 2>/dev/null | grep -q '^grub-btrfsd\.service'; then
  log "Enabling grub-btrfsd"
  run_sudo systemctl enable --now grub-btrfsd
else
  warn "grub-btrfsd.service not found; snapshot submenu updates require grub2-mkconfig"
fi

log "GRUB snapshot integration complete"
