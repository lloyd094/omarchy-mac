#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/base-test.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
cat >"$work/bin/omarchy-hw-apple-silicon" <<'STUB'
#!/bin/bash
[[ ${APPLE:-1} == 1 ]]
STUB
cat >"$work/bin/lspci" <<'STUB'
#!/bin/bash
echo "Broadcom [14e4:${WIFI_ID:-4433}]"
STUB
cat >"$work/bin/systemctl" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >>"$CALLS"
exit "${SYSTEMCTL_STATUS:-0}"
STUB
chmod +x "$work/bin/"*
export PATH="$work/bin:$PATH" CALLS="$work/calls"
stage="$work/root"
"$ROOT/install" "$stage"
setup="$stage/usr/bin/omarchy-mac-setup-system"
unit="$stage/etc/systemd/system/omarchy-wifi-resume-fix.service"
mkdir -p "${unit%/*}"
"$setup" "$stage"
[[ ! -e $unit ]] || fail 'fresh setup uses vendor unit'
grep -q 'enable omarchy-wifi-resume-fix.service' "$CALLS" || fail 'fresh setup enables recovery'
cp "$ROOT/legacy/${unit##*/}" "$unit"
"$setup" "$stage"
[[ ! -e $unit && -f $unit.omarchy-mac-retired ]] || fail 'recognized generated unit retires'
"$setup" "$stage"
# Simulate interruption after backup but before deleting a duplicate generated file.
cp "$ROOT/legacy/${unit##*/}" "$unit"
"$setup" "$stage"
[[ ! -e $unit ]] || fail 'interrupted retirement retries'
printf 'custom service\n' >"$unit"
: >"$CALLS"
"$setup" "$stage"
[[ $(cat "$unit") == 'custom service' && ! -s $CALLS ]] || fail 'custom unit survives setup'
rm "$unit"
ln -s /dev/null "$unit"
"$setup" "$stage"
[[ $(readlink "$unit") == /dev/null && ! -s $CALLS ]] || fail 'mask survives setup'
rm "$unit"
for spec in '0 4433' '1 4434' '1 0000'; do
  read -r apple wifi <<<"$spec"
  APPLE=$apple WIFI_ID=$wifi "$setup" "$stage"
  [[ ! -s $CALLS ]] || fail 'non-Apple and excluded hardware are untouched'
done
if SYSTEMCTL_STATUS=42 "$setup" "$stage"; then fail 'enable failure must be retryable'; fi
"$setup" "$stage"
pass 'fresh, upgrade, repeated, interrupted, overrides, masks and hardware gates'
