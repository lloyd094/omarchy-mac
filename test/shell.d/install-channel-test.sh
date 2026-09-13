#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/base-test.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# Execute real main/option parsing with inert leaf stubs. In particular, never
# source an installed environment or run a real updater in these fixtures.
python3 - "$ROOT/install.sh" "$work/functions" <<'PY'
import re, sys
text = open(sys.argv[1]).read()
names = ['main', 'parse_install_options', 'verify_published_pair', 'run_system_setup']
open(sys.argv[2], 'w').write('\n'.join(re.search(r'^' + name + r'\(\) \{.*?^}', text, re.M | re.S)[0] for name in names))
PY
cat >"$work/driver" <<'DRIVER'
set -euo pipefail
source "$FUNCTIONS"
install_channel="${CHANNEL:-}"
channel_stage=""
log() { :; }
fail() { echo "$*" >&2; exit 1; }
step() { echo "$*" >>"$CALLS"; [[ ${FAIL_AT:-} != "$1" ]]; }
check_preconditions() { step preconditions; }
omarchy_arm_channel_stage_new() { echo "$STAGE"; }
omarchy_arm_channel_prepare() { step "prepare $2 $3"; printf '4.0.3rc1-1\n' >"$1/pair-version"; }
omarchy_arm_channel_apply_prepared() { step apply; }
cleanup_channel_install() { step cleanup; }
ensure_utf8_locale() { step locale; }
load_installed_environment() { step environment; }
protect_published_pair() { step protect; }
unprotect_published_pair() { step unprotect; }
omarchy_arm_prepare_package_sources() { step trust; }
ensure_arm_package_repo() { step repositories; }
ensure_gum() { step gum; }
ensure_aur_helper() { step aur; }
ensure_package_sources() { step recipes; }
build_omarchy_packages() { step build; }
install_omarchy_packages() { step local-install; }
install_default_package_set() { step defaults; }
seed_user_defaults() { step seed; }
run_system_setup() { step setup; }
snapshot_factory_baseline() { step snapshot; }
pacman() { echo "$2 ${PAIR_VERSION:-4.0.3rc1-1}"; }
main "$@"
DRIVER
export FUNCTIONS="$work/functions" STAGE="$work/stage" CALLS="$work/calls"
mkdir "$STAGE"
run_case() {
  : >"$CALLS"
  bash "$work/driver" "$@" >"$work/out" 2>&1
}
run_case --channel rc || fail 'published RC orchestration'
[[ $(cat "$CALLS") == $'preconditions\nprepare rc fresh\nlocale\napply\nenvironment\nprotect\ntrust\ngum\naur\ndefaults\nseed\nsetup\nunprotect\nsnapshot\ncleanup' ]] || fail 'published preflight precedes mutations and never builds different bytes'
pass 'explicit RC installs the preflighted pair and bypasses local builds'
FAIL_AT='prepare rc fresh' run_case --channel rc && fail 'failed preflight must stop'
[[ $(cat "$CALLS") == $'preconditions\nprepare rc fresh\ncleanup' ]] || fail 'failed preflight leaves locale and package state untouched'
pass 'missing or invalid lane stops before system mutation'
FAIL_AT=apply run_case --channel stable && fail 'failed captured transaction must stop'
[[ $(cat "$CALLS") == $'preconditions\nprepare stable fresh\nlocale\napply\ncleanup' ]] || fail 'failed captured transaction skips subsequent setup'
PAIR_VERSION=4.0.3rc2-1 run_case --channel rc && fail 'pair changed by default phase must fail'
! grep -q '^setup$' "$CALLS" || fail 'changed pair aborts before setup/snapshot'
pass 'transaction failure or pair drift cannot report completed install'
run_case || fail 'legacy source install'
grep -q '^build$' "$CALLS" || fail 'legacy installer still builds checkout'
! grep -q '^prepare' "$CALLS" || fail 'legacy installer does not switch to an unavailable stable lane'
CHANNEL=edge run_case || fail 'environment lane selection'
grep -qx 'prepare edge fresh' "$CALLS" || fail 'OMARCHY_MIRROR lane interface'
run_case --channel bogus && fail 'invalid lane must fail'
[[ ! -s $CALLS ]] || fail 'invalid option must not reach preconditions'
pass 'legacy source build and explicit environment lane contracts remain distinct'
setup_output=$(FUNCTIONS="$work/functions" bash -euo pipefail -c '
  source "$FUNCTIONS"
  install_channel=rc USER=fixture
  log() { :; }
  sudo() {
    [[ $* == "env OMARCHY_MIRROR=rc OMARCHY_PRESERVE_PACMAN_CONFIG=1 omarchy-apply-system --install-user fixture --first-install" ]]
    echo system
  }
  ensure_arm_package_repo() { echo unexpected-refresh; exit 1; }
  omarchy-provision-user() { [[ $* == "--first-install" ]]; echo user; }
  run_system_setup
') || fail 'published setup environment propagation'
[[ $setup_output == $'system\nuser' ]] || fail 'published setup preserves candidate config without a second system transaction'
pass 'published system setup preserves the staged lane and package-pair protection'
