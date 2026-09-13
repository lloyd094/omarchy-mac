echo "Repair missing zram configuration on previously migrated installs"

# 1787669934 shipped before the missing-configuration repair. Users with its
# completion marker need a new migration, but must not have configured swap
# reactivated merely because this repair is new. Empty files and links also
# count as deliberate configuration, including administrator masks.
state_dir="${OMARCHY_MIGRATION_STATE:-$HOME/.local/state/omarchy/migrations}"
repair_pending="$state_dir/1789246530.zram-repair-pending"
if [[ ! -f $repair_pending ]]; then
  zram_root="${OMARCHY_ZRAM_ROOT:-}"
  for directory in /etc /run /usr/local/lib /usr/lib; do
    for config in "$zram_root$directory/systemd/zram-generator.conf" \
      "$zram_root$directory/systemd/zram-generator.conf.d/"*.conf; do
      if [[ -e $config || -L $config ]]; then
        exit 0
      fi
    done
  done
  # A failed activation may already have installed the fallback. Remember that
  # this user started the repair so a retry cannot mistake it for a local choice.
  mkdir -p "$state_dir"
  touch "$repair_pending"
fi

# Only the unconfigured population needs the existing repair. It verifies the
# required package, preserves active swap, and honours masked or absent units.
bash -euo pipefail "$OMARCHY_PATH/migrations/1787669934.sh"
rm -f "$repair_pending"
