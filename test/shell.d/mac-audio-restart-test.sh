#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/base-test.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/bin"
for command in omarchy-audio-asahi-mic-map systemctl wpctl; do
  cat >"$work/bin/$command" <<'STUB'
#!/bin/bash
printf '%s %s\n' "${0##*/}" "$*" >>"$CALLS"
STUB
done
printf '#!/bin/bash\nexit 0\n' >"$work/bin/sleep"
ln -s "$ROOT/bin/omarchy-cmd-present" "$work/bin/omarchy-cmd-present"
chmod +x "$work/bin/"*
CALLS="$work/calls" PATH="$work/bin:$PATH" "$ROOT/bin/omarchy-restart-audio" >/dev/null
mapfile -t calls <"$work/calls"
[[ ${calls[0]} == 'omarchy-audio-asahi-mic-map --save-state' ]] || fail 'gain/mute saved before audio restart'
[[ ${calls[1]} == 'systemctl --user restart '* ]] || fail 'audio restart follows state save'
pass 'audio recovery saves add-on state before restarting daemons'
