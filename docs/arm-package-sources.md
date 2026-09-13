# ARM package sources

Apple Silicon installations use the regular Arch Linux ARM, Asahi Alarm, and Mac package repositories. The official `https://pkgs.omarchy.org/edge/$arch` repository has `Usage = Sync`, so it is refreshed but excluded from automatic package selection and upgrades.

The installer, system updater, and pacman channel refresh explicitly select `omarchy/hyprland`, `omarchy/hyprtoolkit`, and `omarchy/hyprland-guiutils` alongside a full system upgrade. Aquamarine and other dependencies resolve from the regular repositories. Dependency failures stop the transaction; no packages are ignored or dependencies bypassed.

The shared policy lives in `install/helpers/arm-package-sources.sh`. Package signatures are required and the existing Omarchy signing key is imported by its full fingerprint. Repository configuration preserves other repositories and mirror choices, saving `/etc/pacman.conf.bak` when it changes.

Use `omarchy update` for system upgrades. A bare `pacman -Syu` does not update the explicitly selected edge packages and can fail when their regular-repository dependencies change ABI. Edge is rolling; versions are resolved together at transaction time rather than pinned.

## ARM package channels

The fork-owned repository uses distinct `stable`, `rc`, and `edge` release coordinates under `https://github.com/omarchy-mac/omarchy-pkgs-aarch64/releases/download/`. All three lanes provide `omarchy` and `omarchy-settings`; ARM does not request the x86 `omarchy-dev` pair. Channel reporting reads the managed ARM server, so an older installation pointing at `/edge` reports edge even when its installed package names are `omarchy` and `omarchy-settings`.

An explicit channel switch goes through the normal update lock, snapshot and migration pipeline. It stages the current pacman configuration, changing only the managed ARM lane and reapplying the existing explicit upstream graphics policy. Other repository ordering, options and mirror Includes are preserved. Custom or ambiguous ARM server/Include layouts are rejected rather than guessed. ARM refresh uses this same path and no longer runs the reset-only `pre-refresh-pacman` hook, because it does not discard and recreate the user's configuration. The x86 reset path retains that hook; normal update hooks still run after successful migrations.

Before changing installed packages, the switch syncs isolated databases, verifies a matching desktop package pair, resolves the full transaction and downloads its archives under the configured signature policy. Verification uses a private copy of public keyring trust. Required trust that is absent fails preparation; any undeclared key imported during verification rejects the transaction without changing the live keyring. It checks the resolved archive hashes and captures the repository databases and archives as local repositories. A second resolution against the real installed database must match the preflight manifest. One ordinary libalpm system-upgrade transaction then uses those captured repositories, preserving dependency reasons, replacement handling and conflict checks. Explicit version-constrained desktop targets allow RC-to-stable downgrades without enabling distribution-wide downgrades. Equal/older lane database timestamps are handled with a forced sync of the captured database.

The persistent configuration is committed only after successful package installation and only if it has not changed independently. Transaction failures report the installed pair rather than claiming rollback: package hooks may have run before an error. On abort, the prior sync databases are restored under pacman’s real lock if they still match this transaction’s captured cache. Independent cache changes or a held lock retain recovery files and report that compensation could not complete. Installed packages and hook effects are not rolled back. A later migration failure keeps the ordinary update unsuccessful. No migration moves existing `/edge` users to a lane that may not yet be published.

This freezes one switch transaction, not future distribution upgrades. Arch Linux ARM, Asahi and the explicitly selected upstream graphics stack still resolve according to their rolling policies on the next update. Record their resolved versions when qualifying an RC; a different resolved stack needs new compatibility evidence. Captured repositories use a task directory beneath `${XDG_CACHE_HOME:-$HOME/.cache}/omarchy/channels`, require disk-backed storage with sufficient free space, and are removed after the transaction. Existing package caches are reused without deleting their archives.

## Fresh Apple Silicon installation

`./install.sh --channel rc` (or `OMARCHY_MIRROR=rc ./install.sh`) installs the published lane's captured `omarchy`/`omarchy-settings` pair. It verifies availability, resolves dependencies and downloads under the configured signature policy before changing locale, packages or active repository configuration. If the base has no managed ARM section, preflight adds one only to its candidate; custom or hidden managed sections must be configured explicitly. The new managed lane uses the existing Mac repository's `Optional TrustAll` policy; unsigned release metadata is not authenticated by this check. Required upstream graphics signatures remain required.

Fresh preflight can initialize an ephemeral local signing key in its private keyring and fetch and trust only the declared upstream stack fingerprint `40DFB630FF42BCFFB047046CF0134EE680CAC571`. Host secret keys are never copied. The private keyring and its agent are removed on exit. Existing distribution/Asahi trust must already be provisioned by the base system. Accepted installation can then establish the declared stack signer in the live keyring for subsequent package setup.

The captured core/system transaction is followed by the ordinary rolling default-package and optional AUR setup. A temporary `IgnorePkg` entry protects the published desktop pair during those later operations, and both package versions are checked after defaults and after system/user setup. Setup preserves the preflighted repository configuration; cleanup removes only the installer's temporary pin, before recording a factory snapshot on success. This does not freeze optional/default dependencies, so their resolved versions and any unavailable packages remain part of RC qualification.

Without a channel argument or `OMARCHY_MIRROR`, the source installer retains its checkout-build behavior and legacy `/edge` repository default. Existing clients and 3-to-4 bootstraps are not silently redirected to an unpublished `/stable` lane.

## Recovering an install that predates this policy

The policy travels inside the `omarchy` package, and both places that apply it — the installer and the update commands — are out of reach on a machine installed before it. The installer is over, and the update aborts in dependency resolution before the package carrying the helper can be replaced, so the machine cannot upgrade its way to the fix. Such a machine reports:

```
:: unable to satisfy dependency 'libaquamarine.so=13-64' required by hyprtoolkit
:: installing aquamarine (0.15.0-2) breaks dependency 'libaquamarine.so=13-64' required by hyprland
error: failed to prepare transaction (could not satisfy dependencies)
```

`fix-arm-packages.sh` in the repository root applies the same preparation from outside the package and then runs the selection, which is enough for `omarchy update` to work normally afterwards. It sources `install/helpers/arm-package-sources.sh` rather than restating it, taking the copy from its own checkout, `$OMARCHY_PATH`, or `/usr/share/omarchy`, and falling back to the published copy when an installed machine has none of them:

```bash
curl -fsSL https://raw.githubusercontent.com/omarchy-mac/omarchy-mac/quattro/fix-arm-packages.sh | bash
```

The transaction runs as `sudo env OMARCHY_UPDATE_PACMAN=1 pacman -Syu --noconfirm`, the same way `omarchy-update-system-pkgs` and `omarchy-refresh-pacman` do. The update guard hook aborts a `-Syu` that does not identify itself, and this is the update path arriving by another route rather than someone reaching past it. The transaction is noninteractive because the recommended pipe supplies the script itself on standard input.

`--dry-run` reports the configuration change and the transaction without applying either, and is the only mode that runs off Apple Silicon. Pass options after `bash -s --` when running the script through a pipe:

```bash
curl -fsSL https://raw.githubusercontent.com/omarchy-mac/omarchy-mac/quattro/fix-arm-packages.sh | bash -s -- --dry-run
```

`--no-snapshot` skips the Snapper snapshot the script otherwise takes of the machine as found and can be passed the same way:

```bash
curl -fsSL https://raw.githubusercontent.com/omarchy-mac/omarchy-mac/quattro/fix-arm-packages.sh | bash -s -- --no-snapshot
```

The transaction replaces the running compositor, so log out and back in before doing anything else.
