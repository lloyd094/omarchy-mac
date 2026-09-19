# omarchy-mac 0.1.0 candidate validation

Recorded 2026-09-18. This is a reviewable source/package candidate, not a production deployment. No live desktop configuration, repository trust, rolling feed or installer was changed.

## Recorded inputs

| Input | Revision |
| --- | --- |
| Collaboration baseline | `350c46550b99688cdb5224408edd5870de2ca07b` |
| Runtime/settings/add-on source | `b76c6d79cfe5e5c05c22fdeb83f60b6b872f72c2` |
| Add-on recipe and candidate tooling | `94a2dd49a6f42f98b40367479db38b6d35480b85` in `omarchy-mac/omarchy-pkgs-aarch64:feature/omarchy-mac-package` |
| Upstream runtime/settings recipes | `6d27290193109c07b0134360d382e64790ae5dda` in `omacom/omarchy-pkgs` |

Worktrees: `/tmp/omarchy-mac-package` (`integrate/omarchy-mac-package`) and `/tmp/omarchy-mac-package-recipes` (`feature/omarchy-mac-package`). The original dev-linked checkout remains on `quattro-mac-live` at `350c4655`; its untracked plans were preserved. The packaging repository's original checkout remains on `main`, with its pre-existing untracked content preserved.

The source commits separate Wi-Fi extraction, microphone/policy extraction, setup hardening, desktop interfaces, and compatibility migrations. Recipe and candidate-tool commits live in the packaging repository. Documentation commits may follow the pinned build inputs without changing their payloads.

## Candidate artifacts

Local artifact bundle: `/tmp/omarchy-mac-candidate/`. `manifest.json` and `SHA256SUMS` record exact source/recipe revisions and artifact hashes. The three unsigned aarch64 artifacts are:

- `omarchy-mac-0.1.0-1-aarch64.pkg.tar.xz`
- `omarchy-4.0.3.r1.mac.b76c6d79-1-aarch64.pkg.tar.xz`
- `omarchy-settings-4.0.3.r1.mac.b76c6d79-1-aarch64.pkg.tar.xz`

The companion versions are deliberately local candidate versions, not rolling release versions. No package assets were uploaded. The recipe is not registered in the rolling package updater.

## Verification

- Standalone `makepkg` build: the recipe copies only `packages/omarchy-mac/` into a separate source directory before running its tests and staging the package. No desktop-tree resources are needed. Source revision and MIT attribution are included in the artifact.
- Dependencies: audited against actual executable ownership, including `cmp` from diffutils, `pactl` from libpulse, and `pw-dump`/`pw-link` from pipewire. No kernel, `omarchy-settings` replacement/provision, installer or trust payload is declared.
- Package ownership: every non-directory payload path has one owner. The old runtime's Wi-Fi/microphone helpers and old settings microphone unit transfer to the add-on. Neither runtime nor settings carries the independently buildable package source directory.
- Pacman transactions: fresh, upgrade from full baseline runtime/settings artifacts, and repeat installation pass in disposable roots under fakeroot. The installed base package database supplies dependencies, so normal dependency checks stay enabled. No broad overwrite option is used. Hooks and scriptlets are disabled; this proves package resolution/file transfer rather than a bootable system.
- Effective configuration: real NetworkManager `--print-config` selects iwd from the vendor default and honors an `/etc` replacement. Real `systemd-analyze cat-config` honors the administrator unit replacement. Modprobe parses both vendor and administrator options. Real `systemctl --root` validates repair of the exact old enablement symlinks after retiring the generated unit.
- Setup and migration tests: fresh/upgrade/repeat/interrupted setup; two user homes; offline activation without endpoints or a user bus; first-session activation with a temporary bus socket; administrator/user fragments, dangling links, masks, explicit disables and modified config; failure and retry after package acquisition or setup failure. Historical migration names and compatibility leaves remain available.
- Wi-Fi behavioral tests: healthy resume, disabled radio, immediate signature recovery, backstop, clock steps, stale journal exclusion, driver unload/load failures, failed reconnect, and excluded chipsets/architectures. BCM4388, Intel/T2 and non-Apple cases stay excluded.
- Microphone behavioral tests: original graph/state tests moved with the unchanged mapper; missing endpoints, gain/mute persistence, device selection, rollback, supervisor retry and daemon loss remain covered. A desktop integration test proves state saving precedes audio restart.
- Desktop aggregate: `./test/all` as UID 1000 with `OMARCHY_PKGS_PATH=/home/scott/code/omarchy-pkgs`, `OMARCHY_ISO_PATH=/home/scott/code/omarchy-iso`, and `NO_COLOR`, `LC_ALL` and compositor variables unset. CLI suite passes; **285 of 286 shell test files pass**. `optional-transactions-drift-test.sh` fails identically in the untouched `350c4655` baseline: its parser does not model the existing compound Steam guard or preinstall row. This unrelated baseline failure was preserved and is not reported as a green aggregate. Graphical checks are skipped in this headless run.

Raw logs are retained in the local bundle. The final aggregate ran the same runtime/setup/test code as the pinned artifacts; subsequent source edits only added extraction attribution and dependency documentation.

## Scope and measured reduction

Compared with `350c4655`, the desktop runtime/setup/migration areas have 47 added and 690 removed lines: **643 net lines removed**. Desktop tests have 55 added and 746 removed: **691 net lines removed**. The total desktop reduction is **1,334 lines**, including integration calls, compatibility wrappers, package acquisition and migration coverage. The new independently maintained package directory is excluded from this desktop reduction; it carries the transferred implementation and behavioral tests plus setup safeguards.

Desktop bindings, trackpad defaults, Electron workarounds, ALS, HID/initramfs changes, boot, snapshots and installer work are outside the add-on release. The candidate companion recipe merely retains the existing ALS unit; it does not transfer it into the add-on.

## Release gates still open

Physical M1/M2 suspend/resume, microphone/device/gain behavior, effective policy and reboot validation remain unperformed against these artifacts. Aurora requires separately recorded evidence. Signed staging-source selection, installation hooks, and full image provisioning still need qualification. Image builders must consume `install/omarchy-apple.packages` before hardware setup. These are release-promotion gates, not claims made by the source candidate. The active desktop and rolling feed remain unchanged.
