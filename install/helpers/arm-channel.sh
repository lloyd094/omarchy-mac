#!/bin/bash

# ARM package lanes use the same stable package names. A lane is reported only
# for a single, directly configured managed server; custom repositories are not
# guessed from unrelated upstream mirrors or installed package names.
omarchy_arm_channel_current() {
  local config="${1:-/etc/pacman.conf}"
  awk '
    /^[[:space:]]*\[/ { selected = ($0 ~ /^[[:space:]]*\[omarchy-aarch64\][[:space:]]*(#.*)?$/); sections += selected }
    selected && /^[[:space:]]*Include[[:space:]]*=/ { invalid = 1 }
    selected && /^[[:space:]]*Server[[:space:]]*=/ {
      servers++
      if ($0 !~ /^[[:space:]]*Server[[:space:]]*=[[:space:]]*https:\/\/github[.]com\/omarchy-mac\/omarchy-pkgs-aarch64\/releases\/download\/(stable|rc|edge)\/?[[:space:]]*(#.*)?$/) invalid = 1
      value = $0
      sub(/^.*\/download\//, "", value)
      sub(/[\/[:space:]#].*$/, "", value)
    }
    END { if (sections == 1 && servers == 1 && !invalid) print value; else exit 1 }
  ' "$config"
}

omarchy_arm_channel_render() {
  local config="$1" channel="$2" output="$3"
  case "$channel" in stable | rc | edge) ;; *) echo "Invalid ARM package channel: $channel" >&2; return 1 ;; esac
  if ! omarchy_arm_channel_current "$config" >/dev/null; then
    echo "Cannot switch a custom or ambiguous ARM repository. Keep the current configuration and configure its lane explicitly." >&2
    return 1
  fi
  awk -v channel="$channel" '
    /^[[:space:]]*\[/ { selected = ($0 ~ /^[[:space:]]*\[omarchy-aarch64\][[:space:]]*(#.*)?$/) }
    selected && /^[[:space:]]*Server[[:space:]]*=/ { sub(/\/download\/(stable|rc|edge)/, "/download/" channel) }
    { print }
  ' "$config" >"$output"
}

# Called inside omarchy-update's lock/snapshot boundary. The installing
# transaction keeps libalpm's sysupgrade/replacement/reason semantics, but uses
# captured repository databases and verified archives instead of mutable feeds.
omarchy_arm_channel_apply() (
  set -euo pipefail
  local channel="$1" config="${OMARCHY_PACMAN_CONFIG:-/etc/pacman.conf}"
  local scratch="${TMPDIR:-/var/tmp}" stage dbpath repo name version filename hash size extra pair_version=""
  local required available archive cache
  local -a targets caches
  case $(findmnt -n -o FSTYPE -T "$scratch") in
    "" | tmpfs | ramfs) echo "ARM channel staging needs a disk-backed temporary directory." >&2; return 1 ;;
  esac
  stage=$(mktemp -d "$scratch/omarchy-channel.XXXXXXXX")
  trap 'sudo rm -rf -- "$stage"' EXIT
  # The pacman downloader runs as DownloadUser and must read local repo files.
  chmod 755 "$stage"
  mkdir -m 755 "$stage/db" "$stage/cache" "$stage/repos"
  cp "$config" "$stage/original.conf"
  omarchy_arm_channel_render "$config" "$channel" "$stage/lane.conf"
  omarchy_arm_render_package_sources "$stage/lane.conf" >"$stage/source.conf"
  pacman-conf --config "$stage/source.conf" >"$stage/resolved.conf"
  dbpath=$(pacman-conf --config "$stage/source.conf" DBPath)
  sudo cp -a "$dbpath/local" "$stage/db/local"

  local -a probe=(--config "$stage/resolved.conf" --dbpath "$stage/db" --cachedir "$stage/cache" --logfile "$stage/preflight.log")
  sudo env OMARCHY_UPDATE_PACMAN=1 pacman "${probe[@]}" -Sy --noconfirm
  sudo pacman "${probe[@]}" -Sl omarchy-aarch64 >"$stage/lane-packages"
  for name in omarchy omarchy-settings; do
    version=$(awk -v name="$name" '$1 == "omarchy-aarch64" && $2 == name { print $3 }' "$stage/lane-packages")
    if [[ -z $version || $version == *$'\n'* || ( -n $pair_version && $version != "$pair_version" ) ]]; then
      echo "The $channel lane does not provide one matching omarchy/omarchy-settings package pair. Current configuration is unchanged." >&2
      return 1
    fi
    pair_version=$version
    targets+=("omarchy-aarch64/$name=$version")
  done
  targets+=(--ignore omarchy,omarchy-settings)
  while read -r name; do targets+=("$name"); done < <(omarchy_arm_package_upgrade_args)

  local format='%r %n %v %f %h %s'
  sudo pacman "${probe[@]}" -Sup --needed --noconfirm --ask 4 --print-format "$format" "${targets[@]}" >"$stage/expected"
  required=$(awk '{ if ($6 !~ /^[0-9]+$/) exit 1; total += $6 } END { printf "%.0f", total + 104857600 }' "$stage/expected")
  available=$(df -B1 --output=avail "$stage" | tail -1 | tr -d '[:space:]')
  if [[ ! $available =~ ^[0-9]+$ ]] || (( available < required )); then
    echo "Insufficient disk space for channel archives ($required bytes required)." >&2
    return 1
  fi
  # Download-only verifies the configured signature policy without installing
  # a keyring or changing any installed package. Missing trust fails here.
  sudo env OMARCHY_UPDATE_PACMAN=1 pacman "${probe[@]}" -Suw --needed --noconfirm --ask 4 "${targets[@]}"
  caches=("$stage/cache")
  while read -r cache; do caches+=("$cache"); done < <(pacman-conf --config "$stage/resolved.conf" CacheDir)

  pacman-conf --config "$stage/resolved.conf" --repo-list >"$stage/repositories"
  while read -r repo; do
    [[ $repo =~ ^[[:alnum:]_.-]+$ ]] || { echo "Invalid repository name: $repo" >&2; return 1; }
    mkdir -m 755 "$stage/repos/$repo"
    sudo cp "$stage/db/sync/$repo.db" "$stage/repos/$repo/$repo.db"
    if [[ -f $stage/db/sync/$repo.db.sig ]]; then
      sudo cp "$stage/db/sync/$repo.db.sig" "$stage/repos/$repo/$repo.db.sig"
    fi
  done <"$stage/repositories"
  while read -r repo name version filename hash size extra; do
    [[ -n $repo ]] || continue
    if [[ -n $extra || ! $filename =~ ^[[:alnum:]_.+:-]+$ || ! $hash =~ ^[[:xdigit:]]{64}$ || ! $size =~ ^[0-9]+$ || ! -d $stage/repos/$repo ]]; then
      echo "Invalid package manifest entry: $name" >&2
      return 1
    fi
    archive=""
    for cache in "${caches[@]}"; do
      if [[ -f $cache/$filename ]]; then archive="$cache/$filename"; break; fi
    done
    [[ -n $archive ]] || { echo "Downloaded archive is missing: $filename" >&2; return 1; }
    printf '%s  %s\n' "$hash" "$archive" | sha256sum -c -
    if [[ -f $archive.sig ]]; then
      sudo cp "$archive.sig" "$stage/repos/$repo/$filename.sig"
    fi
    if [[ $archive == "$stage/cache/$filename" ]]; then
      sudo mv "$archive" "$stage/repos/$repo/$filename"
    else
      sudo cp "$archive" "$stage/repos/$repo/$filename"
    fi
  done <"$stage/expected"

  # Flattened options retain the real root/db/keyring, Includes have already
  # been resolved, and every repository now has exactly one local server.
  # A custom transfer command must not turn file:// back into a network fetch.
  awk -v base="$stage/repos" '
    /^[[:space:]]*(Server|CacheServer|XferCommand)[[:space:]]*=/ { next }
    /^\[/ {
      print
      if ($0 != "[options]") { repo = $0; gsub(/^\[|\]$/, "", repo); print "Server = file://" base "/" repo }
      next
    }
    { print }
  ' "$stage/resolved.conf" >"$stage/frozen.conf"
  if ! cmp -s "$config" "$stage/original.conf"; then
    echo "pacman.conf changed during channel preparation. Preserving it; retry after reviewing the change." >&2
    return 1
  fi
  # A different lane may have an equal or older database timestamp. Force the
  # captured database into the real sync cache before comparing transactions.
  sudo env OMARCHY_UPDATE_PACMAN=1 pacman --config "$stage/frozen.conf" -Syy --noconfirm
  sudo pacman --config "$stage/frozen.conf" -Sup --needed --noconfirm --ask 4 --print-format "$format" "${targets[@]}" >"$stage/actual"
  if ! diff -u "$stage/expected" "$stage/actual"; then
    echo "Installed package state changed during channel preparation. Retry; the active configuration is unchanged." >&2
    return 1
  fi
  if ! sudo env OMARCHY_UPDATE_PACMAN=1 pacman --config "$stage/frozen.conf" -Syu --needed --noconfirm --ask 4 "${targets[@]}"; then
    echo "Channel transaction failed; no new channel configuration was committed. Package hooks may have run; installed pair:" >&2
    pacman -Q omarchy omarchy-settings >&2 || true
    return 1
  fi
  if ! cmp -s "$config" "$stage/original.conf"; then
    echo "Packages were installed, but pacman.conf changed during the transaction. Preserving it; inspect the configuration before retrying the channel switch." >&2
    return 1
  fi
  sudo cp -p "$config" "$config.bak"
  sudo install -m 644 "$stage/source.conf" "$config"
  echo "ARM package channel is now $channel ($pair_version)."
  echo "The selected upstream graphics stack and distribution dependencies were resolved at transaction time."
)
