# omarchy-mac candidate validation

Updated 2026-09-19 after the authorized M2 Max dev-link trial and migration review. Candidate integration has not been merged or promoted.

## Recorded inputs

| Input | Revision or version |
| --- | --- |
| Shared branch and previous dev-linked checkout | `350c46550b99688cdb5224408edd5870de2ca07b` |
| Candidate activated at boot | `3f9f7177` |
| Installed-package migration guard after boot | `ea58eb2c` |
| Installed add-on source | `b76c6d79cfe5e5c05c22fdeb83f60b6b872f72c2` |
| Add-on recipe/tooling | `94a2dd49a6f42f98b40367479db38b6d35480b85` |
| Migration/compatibility review | `c19e2f6a` |
| Login activation review | `6607f4bb` |
| Separately reviewable audio-restart fix | `4ee7ddcf` |
| Installed trial runtime | `4.0.2-202609092055.mac1` (verified local reconstruction) |
| Installed settings | `4.0.2-202609092055`, unchanged |
| Installed add-on | `0.1.0-1` |

Persistent worktrees: `/home/scott/code/omarchy-worktrees/mac-package` and `/home/scott/code/omarchy-worktrees/mac-package-recipes`. The former `/tmp` worktrees and full companion bundle were lost on reboot. Their branches survived; no uncommitted source was recovered or assumed. The active checkout and its unrelated files were preserved.

## Current result

The add-on remains on `integrate/omarchy-mac-package`; it is not merged into `quattro-upstream`, which remains at `350c4655`. The original runtime/settings/add-on candidate trio was built from `b76c6d79`, with scratch transaction checks. That `/tmp` bundle did not survive reboot. The durable live trial instead pairs add-on `0.1.0-1` from `b76c6d79` with a minimal reconstruction of the installed runtime (`4.0.2-202609092055.mac1`); settings remains `4.0.2-202609092055` and the candidate was subsequently dev-linked and booted successfully on 2026-09-19 at `3f9f7177`. Ownership transfer and offline rollback were rehearsed with dependencies enforced, and the live transaction and package integrity checks passed.

Scott confirmed reboot, Wi-Fi, playback, microphone recording, and lid-close resume on an M2 Max. Wi-Fi retains the administrator’s wpa_supplicant override; BCM4388 remains excluded from resume recovery, and the existing user microphone unit remains authoritative. Audio restart exposed a WirePlumber teardown stall. It reproduced with WirePlumber alone, but stopped cleanly after stopping the mapper and unloading its null sink. A separate desktop fix waits for graph removal and DSP readiness, preserves service state and device choices, and completed two live restarts in 3.75 seconds each without forced recovery. The exact underlying WirePlumber listener-loop defect remains unidentified.

Historical migration bodies are retained, with the unresolved package name corrected and an installed-package guard added to the old package-acquisition migration; compatibility leaves acquire the add-on in their original system/user scope. The new transition handles already-completed migrations. Login only starts an enabled microphone unit; provisioning, first-run and migration handle setup.

The revised extraction saves 1,279 desktop lines against `350c4655`. Including the restart fix, optional mapper guard, installed-package migration guard and their tests at `ea58eb2c`, the combined reduction is 1,123 lines. `packages/`, plans and documentation are excluded from those desktop counts. Upstream desktop PRs must exclude `packages/`; it remains independently maintained in the collaboration repository. CLI, standalone package and focused regression suites pass. The non-root desktop aggregate passes 285/286 shell test files; the existing optional-menu drift failure remains.

The candidate dev link is active after reboot. No candidate was published to the rolling feed, repository trust was not changed, and no shared-branch merge occurred. Signed repository selection, full image provisioning, additional M1/M2 coverage, the packaged-unit activation path, and separately recorded Aurora qualification remain open. Current persistent worktrees are under `~/code/omarchy-worktrees/`; live artifacts, recovery commands and diagnostic evidence are under `~/omarchy-mac-recovery/trial/`.

## Durable evidence

`/home/scott/omarchy-mac-recovery/trial/` contains:

- `artifacts/` and `SHA256SUMS`: local runtime trial, reconstructed runtime rollback, and pinned add-on archives. The runtime was reconstructed from 1,885 installed entries matching pacman’s recorded manifest; it is not an original downloaded build artifact. Archive comparison confirms only two transferred files and the new detector/link differ in the trial runtime.
- `payload-audit.json`, `archive-diff.json`, `rehearsal.json`, `transaction.log`, `rollback-script-test.log`: paired installation, repetition, rollback and retry checks. Scratch transactions retain dependency checks and disable hooks; the later live local transaction ran its normal hooks. No broad overwrite workaround was used.
- `live-before.json`, `live-after-setup.json`, `post-resume.json`: effective configuration, unchanged gain/mute/default-device checks, and actual sleep logs.
- `restart-trace-20260918/`, `wireplumber-only-trace-20260918/`, `mapper-unloaded-trace-20260918/`: reproducible stall stacks and discriminating experiments. PulseAudio stayed running during the WirePlumber-only stall.
- `fixed-restart-trace-20260918/`: the first patch attempt still failed and raced DSP readiness; retained as failed evidence.
- `fixed-restart-ready-trace-20260918/`, `fixed-restart-repeat-trace-20260918/`: corrected restart passed twice, restored audio levels, and did not enter forced recovery. It was invoked by explicit worktree path; the active command began resolving to the corrected candidate after the 2026-09-19 dev-link reboot.
- `review-tests/`: CLI, standalone package, focused regression and aggregate logs. Final readiness changes were rerun in the focused restart test after the aggregate had begun. The aggregate's only failing file is `optional-transactions-drift-test.sh`, previously reproduced on the unchanged baseline.

Snapshot 8 remains the retained pre-trial root snapshot; `/home` and `/boot` are excluded, and root restoration has not been exercised. The tested offline rollback script and separate Wi-Fi recovery instructions are in the recovery folder.

## Source identity and CPU observation

The extracted mapper is byte-identical to `350c4655:bin/omarchy-audio-asahi-mic-map` (SHA256 `5a4cd6bbc36e2c7beb62023a27997d1f5f84b3ffeae58a5f107185615dfda1bc`). The pre-trial installed helper differs (SHA256 `838d44a5578ad12c134ad77ff54284afe7b987c4223480330ec4f54ba881d291`): it polled every two seconds. The prior 2h25m CPU observation belonged to that older helper. It does not demonstrate an event-loop regression in the extracted helper; a sustained idle CPU measurement of the current helper remains separate work.

## Desktop reduction and upstream boundary

Counts use `git diff --numstat 350c4655 <revision> -- bin default install migrations test`.

| Scope | Runtime/setup/migrations net removed | Tests net removed | Total net removed |
| --- | ---: | ---: | ---: |
| Reviewed extraction at `6607f4bb` | 607 (52 added, 659 removed) | 672 (75 added, 747 removed) | 1,279 |
| Including restart fix at `4ee7ddcf` | 533 (129 added, 662 removed) | 610 (137 added, 747 removed) | 1,143 |
| Including optional mapper and migration guards at `ea58eb2c` | 531 (133 added, 664 removed) | 592 (156 added, 748 removed) | 1,123 |

The earlier 1,334 figure described the initial candidate before these review fixes. The separate restart fix and its tests add 136 lines to the reviewed desktop delta. Package source is counted separately. Do not submit the entire collaboration branch as the upstream desktop PR: exclude `packages/` and keep extraction, compatibility, desktop lifecycle changes and packaging independently reviewable.

## Qualification limits

The M2 trial does not validate iwd as the live backend, BCM4378/BCM4387 driver recovery, an unmodified packaged microphone unit, all M1/M2 hardware, signed repository promotion or an installer. Gain/mute and device selections were checked after the fixed restarts; Scott confirmed playback and microphone recording after the final corrected restart. The subsequent candidate dev-linked boot has connected Wi-Fi, active audio services, a recovered microphone mapping and no failed systemd units; subjective playback/recording on that new boot remains to be checked. Further restart repetitions, including active recording, remain open. Shared branch merge remains unauthorized. Aurora requires independent evidence.

## Dev-linked boot and pending migrations (2026-09-19)

Boot `30abfcf9-644a-4186-bf51-e58d563fbf1a` activated `/home/scott/code/omarchy-worktrees/mac-package` in both the shell and user systemd environment. Scott reports the desktop came up without visible errors. NetworkManager is connected; PipeWire, pipewire-pulse, WirePlumber and the microphone service are active. The mapper initially deferred until DSP appeared, then created the configured `omarchy_asahi_mic.monitor` source. The configured output remains `audio_effect.j414-convolver`. Neither systemd manager reports failed units. This does not yet establish subjective audio checks on this new boot.

Five migrations remain pending and were not executed during this review. `1789275235` now accepts the installed local add-on without querying a sync repository, with focused coverage for missing-repository and retry cases. `1789310715` writes the Cloudflare mise wrapper; `1789325478` skips aarch64. `1789522888` applies because Steam is installed, but `omarchy-steam-fex` is absent from the installed set and local sync databases. It would stop the ordered queue before the final `1789780917` add-on transition. Resolve the Steam package delivery separately; do not bypass ordering or mark unrun migrations complete.

Candidate guards passed the focused Apple migration and audio-restart tests; the optional mapper guard also passed the CLI suite. Earlier aggregate limitations remain as recorded above. The dev-link selection, configuration backups and offline return instructions are under `~/omarchy-mac-recovery/trial/dev-link-20260919/`. To return to the previous desktop, use `/home/scott/code/omarchy/bin/omarchy-dev-link /home/scott/code/omarchy --no-reboot` in a terminal, then reboot. The package rollback is a separate operation.
