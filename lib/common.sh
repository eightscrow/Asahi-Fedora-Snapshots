#!/usr/bin/env bash

set -euo pipefail

LOG_PREFIX="[asahi-fedora-snapshots]"

log() {
  printf '%s %s\n' "$LOG_PREFIX" "$*"
}

warn() {
  printf '%s WARN: %s\n' "$LOG_PREFIX" "$*" >&2
}

die() {
  printf '%s ERROR: %s\n' "$LOG_PREFIX" "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command missing: $1"
}

run_sudo() {
  sudo "$@"
}

run_snapper() {
  run_sudo env LC_ALL=C LANG=C snapper "$@"
}

is_fedora() {
  [[ -r /etc/os-release ]] || return 1
  # shellcheck disable=SC1091
  source /etc/os-release
  [[ "${ID:-}" == "fedora" ]]
}

is_asahi_kernel() {
  uname -r | grep -qi 'asahi'
}

is_btrfs_mount() {
  local mount_point="$1"
  [[ "$(findmnt -no FSTYPE "$mount_point" 2>/dev/null || true)" == "btrfs" ]]
}

has_snapper_config() {
  local config_name="$1"
  run_snapper list-configs 2>/dev/null | awk 'NR>2 {print $1}' | grep -qx "$config_name"
}

set_snapper_config() {
  local config_name="$1"
  shift
  run_snapper -c "$config_name" set-config "$@"
}

write_kv_config() {
  local file_path="$1"
  local key="$2"
  local value="$3"

  run_sudo mkdir -p "$(dirname "$file_path")"
  run_sudo touch "$file_path"

  if run_sudo grep -q "^${key}=" "$file_path"; then
    run_sudo sed -i "s|^${key}=.*|${key}=${value}|" "$file_path"
  else
    printf '%s=%s\n' "$key" "$value" | run_sudo tee -a "$file_path" >/dev/null
  fi
}
