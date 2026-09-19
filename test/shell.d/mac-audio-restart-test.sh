#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/base-test.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/bin"
cat >"$work/bin/fixture" <<'STUB'
#!/bin/bash
name=${0##*/}
printf '%s %s\n' "$name" "$*" >>"$CALLS"
case $name in
  omarchy-hw-apple-silicon) [[ ${APPLE:-1} == 1 ]] ;;
  omarchy-cmd-present) [[ ${MAPPER_PRESENT:-1} == 1 ]] ;;
  omarchy-audio-asahi-mic-map)
    if [[ ${1:-} == "--save-state" ]]; then exit "${SAVE_STATUS:-0}"; else
      if [[ ${DEFER_ONCE:-0} == 1 && ! -f $CALLS.ready ]]; then touch "$CALLS.ready"; exit 75; fi
      exit "${MAP_STATUS:-0}"
    fi ;;
  systemctl)
    case $2 in
      is-active) [[ ${ACTIVE:-1} == 1 ]] ;;
      restart) exit "${RESTART_STATUS:-0}" ;;
      *) exit 0 ;;
    esac ;;
  pactl)
    case "$*" in
      '--format=json list sinks')
        printf '[{"name":"omarchy_asahi_mic","owner_module":42,"properties":{"omarchy.asahi-mic.owner":"%s"}}]\n' "${OWNER-test}" ;;
      get-default-source) echo "${INPUT:-omarchy_asahi_mic.monitor}" ;;
      get-default-sink) echo audio_effect.j414-convolver ;;
      'list short sources') printf '1\tomarchy_asahi_mic.monitor\n2\texternal-mic\n' ;;
      'list short sinks') printf '1\taudio_effect.j414-convolver\n' ;;
      *) exit 0 ;;
    esac ;;
  pw-dump) echo '[]' ;;
  wpctl|sleep) exit 0 ;;
esac
STUB
chmod +x "$work/bin/fixture"
for name in omarchy-cmd-present omarchy-hw-apple-silicon omarchy-audio-asahi-mic-map systemctl pactl pw-dump wpctl sleep; do
  ln -s fixture "$work/bin/$name"
done
export CALLS="$work/calls" PATH="$work/bin:$PATH"
run_case() {
  : >"$CALLS"
  env "$@" "$ROOT/bin/omarchy-restart-audio" >"$work/output" 2>&1
}
run_case
python - "$CALLS" <<'PY'
import sys
calls=open(sys.argv[1]).read().splitlines()
expected=['omarchy-audio-asahi-mic-map --save-state','systemctl --user stop omarchy-asahi-mic.service','pactl unload-module 42','systemctl --user restart wireplumber.service pipewire.service pipewire-pulse.service','omarchy-audio-asahi-mic-map ','systemctl --user start omarchy-asahi-mic.service','pactl set-default-source omarchy_asahi_mic.monitor','pactl set-default-sink audio_effect.j414-convolver']
positions=[calls.index(c) for c in expected]
assert positions==sorted(positions),calls
assert calls.count('pactl unload-module 42')==1
assert not any('enable' in c for c in calls)
PY
pass 'save, detach, daemon restart, remap and restore device choices in order'
run_case ACTIVE=0
! grep -Eq 'systemctl --user (stop|start) omarchy-asahi-mic.service' "$CALLS" || fail 'inactive mapper service remains inactive'
grep -Fxq 'pactl unload-module 42' "$CALLS" || fail 'existing owned graph is detached even with an inactive service'
run_case INPUT=external-mic
grep -Fxq 'pactl set-default-source external-mic' "$CALLS" || fail 'external microphone choice survives remapping'
run_case OWNER=
! grep -Fq 'unload-module' "$CALLS" || fail 'unowned same-name sink must survive'
! grep -Fq 'systemctl --user stop omarchy-asahi-mic.service' "$CALLS" || fail 'unowned graph must not stop service'
run_case APPLE=0
! grep -Eq '^(pactl|omarchy-audio-asahi-mic-map) ' "$CALLS" || fail 'non-Apple audio never touches mapping'
pass 'inactive services, external input choices, unowned sinks and other hardware are preserved'
run_case MAPPER_PRESENT=0
! grep -Eq '^(pactl|omarchy-audio-asahi-mic-map) ' "$CALLS" || fail 'Apple installs without the add-on must skip mapping'
grep -Fxq 'systemctl --user restart wireplumber.service pipewire.service pipewire-pulse.service' "$CALLS" || fail 'missing optional mapper must not skip daemon restart'
! grep -Eq 'command not found|Could not save microphone' "$work/output" || fail 'missing optional mapper must not warn'
pass 'Apple audio restarts normally without the optional add-on'

run_case RESTART_STATUS=42
grep -Fq 'systemctl --user kill ' "$CALLS" || fail 'existing forced recovery remains available'
grep -Fxq 'systemctl --user start omarchy-asahi-mic.service' "$CALLS" || fail 'forced recovery restores mapper service'
if run_case MAP_STATUS=43; then fail 'failed microphone restoration must report failure'; fi
grep -Fxq 'systemctl --user start omarchy-asahi-mic.service' "$CALLS" || fail 'restore failure still resumes mapper supervisor'
[[ $(grep -Fc 'omarchy-audio-asahi-mic-map ' "$CALLS") == 2 ]] || fail 'exit trap must not duplicate remapping'
run_case SAVE_STATUS=44
! grep -Fq 'unload-module' "$CALLS" || fail 'failed state save must not remove the mapping'
pass 'failure paths retain daemon recovery and restore the prior mapper service state'

run_case DEFER_ONCE=1
grep -Fxq 'pactl set-default-source omarchy_asahi_mic.monitor' "$CALLS" || fail 'DSP readiness retry restores input choice'
[[ $(grep -Fc 'omarchy-audio-asahi-mic-map ' "$CALLS") == 3 ]] || fail 'deferred DSP setup retries once before succeeding'
pass 'deferred DSP startup retries before restoring device choices'
