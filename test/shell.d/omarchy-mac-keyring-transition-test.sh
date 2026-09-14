#!/bin/bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT
export TEST_TRUST_CALLS="$test_tmp/calls" OMARCHY_PATH="$ROOT"
old_key=F3C5AE3FCFFC738C301E30A8F0C548C0D27279F7
new_key=FBD6874D423C418DDB6D143EECE19CDDE306DBD2
export TEST_OLD_KEY="$old_key" TEST_NEW_KEY="$new_key"

# Reject every privileged operation except the explicitly modeled trust calls.
sudo() {
  printf '%s\n' "$*" >>"$TEST_TRUST_CALLS"
  if [[ $* == 'pacman-key --populate omarchy-mac' ]]; then
    return "${TEST_POPULATE_FAILURE:-0}"
  elif [[ $1 == pacman-key && $2 == --finger && $# == 3 ]]; then
    [[ $3 != "${TEST_MISSING_KEY:-}" ]] || return 1
    printf '%s\n' "$3"
  else
    return 99
  fi
}
omarchy-pkg-missing() { return "${TEST_PACKAGE_PRESENT:-1}"; }
omarchy-notification-dismiss() { :; }
export -f sudo omarchy-pkg-missing omarchy-notification-dismiss

mkdir -p "$test_tmp/source/migrations" "$test_tmp/markers"
for name in 1789316115 1789390468; do
  cp "$ROOT/migrations/$name.sh" "$test_tmp/source/migrations/"
done
touch "$test_tmp/markers/1789316115.sh" "$test_tmp/markers/1789317000.sh"
export OMARCHY_MIGRATION_STATE="$test_tmp/markers"
OMARCHY_PATH="$test_tmp/source" bash "$ROOT/bin/omarchy-migrate" >/dev/null
[[ -f $OMARCHY_MIGRATION_STATE/1789390468.sh ]] || fail 'successor marker missing'
[[ $(cat "$TEST_TRUST_CALLS") == "pacman-key --populate omarchy-mac"$'\n'"pacman-key --finger $new_key" ]] ||
  fail 'completed old migrations must stay skipped and only the new key must be checked'
: >"$TEST_TRUST_CALLS"
OMARCHY_PATH="$test_tmp/source" bash "$ROOT/bin/omarchy-migrate" >/dev/null
[[ ! -s $TEST_TRUST_CALLS ]] || fail 'completed successor ran again'
pass 'existing completed migrations stay skipped while successor establishes new trust without requiring the old key'

# Failure leaves the new migration pending and never changes repository policy.
for failure in new populate package; do
  mkdir "$test_tmp/markers-$failure"
  touch "$test_tmp/markers-$failure/1789316115.sh" "$test_tmp/markers-$failure/1789317000.sh"
  export TEST_MISSING_KEY='' TEST_POPULATE_FAILURE=0 TEST_PACKAGE_PRESENT=1
  case "$failure" in
    new) TEST_MISSING_KEY="$new_key" ;;
    populate) TEST_POPULATE_FAILURE=1 ;;
    package) TEST_PACKAGE_PRESENT=0 ;;
  esac
  if OMARCHY_PATH="$test_tmp/source" OMARCHY_MIGRATION_STATE="$test_tmp/markers-$failure" bash "$ROOT/bin/omarchy-migrate" >"$test_tmp/rejected" 2>&1; then
    fail "$failure trust failure must stop migration"
  fi
  [[ ! -e $test_tmp/markers-$failure/1789390468.sh ]] || fail 'failed successor was marked complete'
done
unset TEST_MISSING_KEY TEST_POPULATE_FAILURE TEST_PACKAGE_PRESENT
pass 'missing package, missing new key and population failure leave successor pending'

source "$ROOT/install/helpers/arm-channel.sh"
omarchy_arm_channel_key_fingerprints() { printf '%s\n' "${fixture_keys[@]}"; }
sudo() {
  printf '%s\n' "$*" >>"$TEST_TRUST_CALLS"
  if [[ $1 == gpg && $4 == --batch && $5 == --list-keys ]]; then
    printf '%s\n' "${fixture_keys[@]}" | grep -qxF "$6"
  elif [[ $1 == pacman-key && $4 == --add ]]; then
    [[ $5 == "$ROOT/default/pacman/keyrings/omarchy-mac.gpg" ]] || return 99
    [[ ${TEST_INCOMPLETE_CERT:-0} == 1 ]] || fixture_keys+=("$new_key")
    return 0
  elif [[ $1 == pacman-key && $4 == --lsign-key ]]; then
    [[ $5 == "$new_key" ]]
  else
    return 99
  fi
}
for state in fresh old-only new-only both; do
  fixture_keys=()
  case "$state" in
    old-only) fixture_keys=("$old_key") ;;
    new-only) fixture_keys=("$new_key") ;;
    both) fixture_keys=("$old_key" "$new_key") ;;
  esac
  : >"$TEST_TRUST_CALLS"
  omarchy_arm_channel_trust_fork "$test_tmp/private-keyring"
  if grep -qxF "pacman-key --gpgdir $test_tmp/private-keyring --lsign-key $old_key" "$TEST_TRUST_CALLS"; then fail "$state authorized old trust"; fi
  grep -qxF "pacman-key --gpgdir $test_tmp/private-keyring --lsign-key $new_key" "$TEST_TRUST_CALLS" || fail "$state did not establish new trust"
  expected=1
  [[ $state != both && $state != new-only ]] || expected=0
  [[ $(grep -c -- '--add ' "$TEST_TRUST_CALLS" || true) == "$expected" ]] || fail "$state certificate import count differs"
done
fixture_keys=()
if TEST_INCOMPLETE_CERT=1 omarchy_arm_channel_trust_fork "$test_tmp/private-keyring"; then
  fail 'fresh trust accepts a certificate missing the replacement primary'
fi
pass 'fresh and channel trust stages require the new primary for fresh and old-only clients'

[[ $(cat "$ROOT/default/pacman/keyrings/omarchy-mac-trusted") == "$new_key:4:" ]] || fail 'packaged trusted primaries differ from transition pins'
(
  source "$ROOT/build-inputs/omarchy-mac-keyring/PKGBUILD"
  [[ $pkgver == 20260914 && $pkgrel == 2 ]]
  for index in "${!source[@]}"; do
    [[ $(sha512sum "$ROOT/default/pacman/keyrings/${source[$index]}" | cut -d' ' -f1) == "${sha512sums[$index]}" ]]
  done
) || fail 'versioned package recipe must bind exact public trust files'
pass 'packaged public trust and checksums match the versioned transition'
