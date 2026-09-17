# Apple Silicon upstream integration plan

Working plan for shared Apple Silicon development, encrypted installation, package delivery, and incremental integration into upstream Omarchy. Baseline recorded 2026-09-16; collaboration branch and merge tracker updated 2026-09-17.

## Objective and agreed direction

Develop a complete Apple Silicon Omarchy system together, distribute it to participating testers, and move its components upstream through focused contributions. The shared integration system and an individual upstream PR have different scopes.

- `omacom/omarchy-mac:quattro-upstream` is the published shared source branch, based on Scott's working `quattro-mac-live` integration.
- The package pool is a preferred candidate for distributing the team's working system, including approved replacements for packages already in upstream repositories.
- Encryption of Linux root and user data is a requirement. Choose and adapt the installer implementation that best meets the installation and recovery requirements.
- The intended installation technique places a temporary installer at the tail of the allocated Linux space, installs an encrypted system ahead of it, and reclaims the installer space after the installed system boots successfully.
- Prefer reusing Marcelo Alcantara's macOS interface and Apple boot preparation, combined with the existing prepared-install work, where they satisfy that design.
- Asahi is the initial validation baseline. Aurora remains an explicit experimental option with its own tested package and boot configuration.
- Upstream desktop contributions should remain separable from the temporary package service and installer implementation.

The collaboration branch is what the team develops together. The collaboration package channel is what the team installs and tests together. Availability of official ARM packages makes that work easier; it does not remove the need to distribute changes that are not upstream yet.

## Current state

The following state establishes the implementation baseline. Recheck branch tips and package publication before dependent actions.

| Area | State | Consequence |
| --- | --- | --- |
| Branches | Published code baseline is `0f5cb383`, including [#8942](https://github.com/omacom/omarchy/pull/8942) and [#9834](https://github.com/omacom/omarchy/pull/9834) | Track further integrations below |
| Independent upstream fixes | Provisioning robustness and battery rounding are open as [#12056](https://github.com/omacom/omarchy/pull/12056) and [#12058](https://github.com/omacom/omarchy/pull/12058); Marcelo's [#9834](https://github.com/omacom/omarchy/pull/9834) and [#9835](https://github.com/omacom/omarchy/pull/9835) were also open | Coordinate existing submissions rather than reopen their content |
| [#9835](https://github.com/omacom/omarchy/pull/9835) integration | The local integration already includes its rebased work: explicit menu package guards, architecture substitutions, the ARM fixture, pacman staging, and unified keyring work | Preserve completed adaptations and reconcile any later upstream changes |
| Official ARM packages | Official edge contained 115 packages: 86 `aarch64`, 29 `any`; ARM RC/stable databases returned 404 | Official edge is a useful package source, not yet proof of a qualified full Mac installation |
| Channel qualification | The ARM qualification allowlist in `install/helpers/pacman.sh` is empty | Do not describe channel switching as qualified merely because a database exists |
| Steam | The FEX launcher and UI patch live in `omarchy-steam-fex`; the desktop installs and uses that package | Maintain the launcher in its package and the runtime integration in the desktop repository |
| Public macOS installer | Inspection of Marcelo's public `main` at `33164982` found direct boot/root image placement and no LUKS/passphrase setup | Do not advertise that inspected installer as creating encrypted Linux roots |
| Local encrypted integration | The local prepared-install contract requires LUKS2 and later installer-slice reclamation | Reconcile and test its producer and consumer; the contract alone does not prove an encrypted installation |
| Image installer | The ISO repository documents encrypted installation and a remaining package-managed update gap for UUID-private ESP kernel/initramfs files | Kernel updates must be completed before release acceptance |

Official ARM edge packages identify the Omarchy keyring key `40DFB630 FF42BCFF B047046C F0134EE6 80CAC571` as their signer, also used for x86 edge. The database itself is unsigned. This signing identity is compatible with [#9835](https://github.com/omacom/omarchy/pull/9835)'s `SigLevel = Required DatabaseOptional`; official ARM packages do not need a new fork trust root. Pacman verifies package bytes against the trusted keys when installing. The supplemental collaboration packages still need an agreed signing and trust-bootstrap route, and the complete package set still needs qualification.

Two package-source mechanisms currently coexist in `quattro-mac-live`: [#9835](https://github.com/omacom/omarchy/pull/9835)'s architecture-aware templates, whose edge template points `[omarchy]` at official ARM edge, and `install/hardware/apple/pacman.sh` with migration `1788200000.sh`, which appends `[omarchy-aarch64]` with `Optional TrustAll`. Both mechanisms are in the source tree, but a fresh Apple installation does not necessarily activate both: with the qualification allowlist empty, `omarchy_pacman_finalize` preserves the image's existing configuration rather than installing the official template. The Apple leaf then adds its stanza if absent. Inventory the actual configuration on each installation path; the collection decision must resolve both mechanisms and previously written configuration.

## Shared source development

Use `quattro-upstream` for the working integration. The default is a focused change designed for eventual upstream submission, with attribution preserved. Exceptions are allowed for experiments and temporary integration support, but their status must be explicit in the commit message. A useful integration commit need not already be ready to cherry-pick into upstream unchanged.

Use a consistent commit-message trailer: `Upstream-Status: candidate`, `Upstream-Status: experimental`, or `Upstream-Status: temporary`. Experimental and temporary commits must explain the reason and the condition for removal or upstream submission in the body, with a tracking issue when available. This makes classification mechanically extractable without requiring the collaboration branch to be an already polished PR series. Apply the convention to new work; do not rewrite shared history just to add trailers.

Keep macOS disk operations, image-building code, package recipes, and service-specific trust bootstrap in their appropriate projects. Target-side runtime support can remain in the desktop tree. Preserve the current scope exclusions for parked disk-conversion tools and MLX unless the group deliberately changes scope; reuse installer code in the installer project where needed.

Build on the published starting point and coordinate contributions through the shared branch. Default to history-preserving integration of upstream. Any exceptional shared-history rewrite needs explicit coordination. Submission branches may be rebased and cleaned independently without forcing all testers and contributors to follow rewrites.

Maintain the working integration branch and active submission branches. Continue the provisioning and battery-rounding reviews, track [#9835](https://github.com/omacom/omarchy/pull/9835) with Marcelo, and extract the remaining upstream contributions when ready. ALS and Steam integration can be tested in the full system while receiving separate upstream review where appropriate.

## Repository boundaries and upstream destinations

Keep the Apple installer in a separate repository from the desktop integration branch. Agree its shared home with Marcelo Alcantara and the maintainers, preferably by reusing or extracting his existing installer project with history and attribution preserved. Incorporate suitable components from `omarchy-mac-iso` there. The repository name, ownership, and eventual official home remain decisions for the group.

Upstream integration can land across several official repositories. The intended outcome is a supported Apple installation path using upstream Omarchy packages and shared Linux provisioning, allowing the desktop fork to be retired. The macOS application can remain a maintained companion project. Upstream already separates image construction and installation in [omacom/omarchy-iso](https://github.com/omacom/omarchy-iso) from the runtime and system/user setup supplied by Omarchy packages.

| Component | Collaboration home | Proposed upstream destination |
| --- | --- | --- |
| macOS app, try/install interface, APFS preparation, and Apple boot preparation | Shared Apple installer repository | An official companion repository, subject to maintainer agreement |
| Temporary Linux environment, image construction, encrypted installation, and installer-space reclamation | Installer project, reusing shared Linux installation machinery | Reusable installer changes proposed to `omacom/omarchy-iso`; Apple-specific components retained in the agreed installer project where appropriate |
| Hardware detection, Apple defaults, desktop behavior, and shared system/user provisioning | `omacom/omarchy-mac:quattro-upstream` | `omacom/omarchy`, with package-owned settings in the relevant settings package |
| Kernel, firmware, and package-managed boot updates | Relevant package source and recipe repositories | Official Omarchy packaging or the relevant upstream provider, with runtime integration in Omarchy as needed |

Share Linux provisioning and package definitions across installation paths. The Apple installer should consume those interfaces and recorded package builds rather than carry a second evolving copy of desktop setup. Installer-owned reclamation code may need to run after the first installed boot; define how it is delivered and retired without assuming that every installed helper belongs in the desktop repository.

Coordinate releases with a versioned manifest recording the macOS installer revision, Linux installer/image revision and artifact identity, exact package set, and handoff format version. Test the producer and consumer together and reject incompatible handoffs before disk mutation. This release manifest complements the per-installation disk and partition manifest described below; it contains no encryption credentials.

The existing [M1 + M2 launch card](https://app.basecamp.com/5994298/buckets/48663438/card_tables/cards/10294470280) covers the macOS app's try and install flows. The [unified-installer card](https://app.basecamp.com/5994298/buckets/48663438/card_tables/cards/10296876777) establishes the direction toward shared provisioning, and [Omarchy ARM](https://app.basecamp.com/5994298/buckets/48663438/card_tables/cards/10294467178) covers package mirroring across ARM platforms. Coordinate this work through those existing efforts. The exact repository destinations and tail-installer technique are proposals to validate and review; those cards do not establish acceptance of a particular implementation.

## Package delivery for collaboration

### Repository precedence is intentional

The collaboration source must be able to provide both new package names and modified versions of existing packages, particularly `omarchy` and `omarchy-settings` or their development variants. Merely putting a source above `[core]` is insufficient if an earlier `[omarchy]` or fork repository still wins for those names.

Proposed logical order for participating testers:

1. The team's selected collaboration collection, containing explicitly approved overrides and missing packages.
2. The agreed base repositories, supplied through the pool or directly from official Omarchy, Arch Linux ARM, and Asahi sources.

This is a required behavior, not a claim that the pool already exposes a team-specific collection with that exact layout. Agree the implementation with its maintainer. A lower-priority source limited to missing names can still be useful, but it cannot by itself implement the override channel.

Record the intended provider of every override. Test initial selection, upgrades, equal-version cases, locally newer packages, and leaving the channel. Repository order alone does not establish that already installed packages transition correctly.

### What the pool can contribute

The inspected pool provides upstream mirrors, a Factory for additional builds, signed databases, and documented promotion/testing workflows. Its official Omarchy ARM source contained the same 115 package names counted in official edge. Asahi sources were present in the inspected edge inventory but absent from its RC/stable inventories. Pool ring names are distinct from official Omarchy channel names.

The pool setup inserts its include above `[core]` and retains existing sources. Review the complete resulting configuration, including older fork repositories, before using it for a release. Decide whether to adopt a coherent pool-managed base or a supplemental collaboration collection; do not assemble an accidental mixture through fallback sources.

The aarch64 edge configuration endpoint returns no repositories with no source selection, with `with=asahi`, and with `with=asahi,asahi-alarm`; RC and stable each return five repositories. Resolve this configuration/publication issue with the pool maintainer before directing testers to edge setup. Provide the tested URLs, release identity, and responses.

### Package inventory and builds

Create a manifest mapping each required package to its provider, source commit, recipe, version, architecture, signer, and purpose. Distinguish baseline requirements from optional applications; an absent optional package need not block first encrypted-install validation.

The initial publication worklist contains eight packages absent from official ARM edge:

| Package | Recorded publication gap |
| --- | --- |
| `cursor-bin` | Absent from official ARM edge; present in the fork's unsigned GitHub-release repository |
| `avd-fw` | Absent from official ARM edge; present in the fork repository |
| `libva-v4l2_request-avd` | Absent from official ARM edge; present in the fork repository |
| `obsidian-appimage` | Absent from official ARM edge; present in the fork repository |
| `omarchy-steam-fex` | Absent from official ARM edge; present in the fork repository |
| `pinta` | Absent from official ARM edge; present in the fork repository |
| `vi` | Absent from official ARM edge; present in the fork repository and reported among the pool's Factory builds |
| `omarchy-settings-asahi` | Requested by the integrated [#9835](https://github.com/omacom/omarchy/pull/9835) work; publication under this exact name remains unconfirmed. Marcelo's [runtime release](https://github.com/maralcbr/omarchy-pkgs/releases/tag/asahi-quattro-a67d7f78) publishes `omarchy-settings-dev` instead |

Marcelo's [package repository](https://github.com/maralcbr/omarchy-pkgs) is an existing source of Apple Silicon settings work. Checked 2026-09-17: runtime channel 32 points to `asahi-quattro-a67d7f78`, which publishes `omarchy-settings-dev-4.0.3.r6962.ga67d7f7-1-aarch64.pkg.tar.xz` and its detached signature. The inspected `asahi-quattro` recipe provides `omarchy-settings`, but does not declare `omarchy-settings-asahi`; the inspected release assets and latest listed stable supplemental database did not contain that separate name. Reconcile the integrated migration's explicit package request with Marcelo's intended overlay recipe and publication path. Reuse his settings work, while checking file ownership and compatibility with our recorded runtime/settings pair before selecting a package for the collaboration channel.

Begin recipe and publication work from this inventory and update entries as packages land. Use the listed alternate providers where appropriate. Asahi already supplies its kernel, audio components, and Widevine. Prioritize packages required for the baseline installation ahead of optional applications.

Build the selected runtime/settings pair from the same recorded `quattro-upstream` revision. Testers should receive a packaged system; contributors can continue dev-linking for development. Do not assume mirrored official `omarchy` packages contain the team's branch changes.

### Questions for the pool maintainer

- Can participating teams select a collection or channel with approved package overrides and independent promotion criteria?
- Can the Factory build the runtime/settings pair and Mac extras from exact source and recipe commits?
- How are complete release sets pinned, retained, retrieved, and withdrawn, including dependencies needed to reproduce installer images?
- Who reviews recipes, approves builds, and promotes Mac releases? What is the operational fallback if the service or a maintainer is unavailable?
- How are package and database signing keys authenticated, rotated, and recovered? Factory package signatures must be accounted for alongside mirrored upstream signatures.
- Why does aarch64 edge configuration return no repositories regardless of the tested `with=` selections, while RC and stable are populated and edge databases exist?
- How do testers enter and leave the collaboration collection without unresolved dependencies or an unintended mixture of versions?

### Signing and transition

Use authenticated signing keys and signature enforcement for the shared release path. Replacing `Optional TrustAll` is a deliverable. Naeem's signing issue [#394](https://github.com/omacom/omarchy-mac/issues/394) and the pool's Factory are possible routes; select the route with the collaborators rather than silently requiring both.

Trust initialization belongs in installer/package configuration. Upstream runtime changes should not hardcode trust in a temporary private service. Document all actual trust roots, including Arch Linux ARM and Asahi, official Omarchy, the pool's database and Factory signing, and any retained fork source.

Retire the unsigned repository leaf only when its replacement works for both fresh installations and existing testers. Deleting the leaf and migration from a future source branch does not remove a stanza already written to a user's machine. Provide a separately tested transition that installs the required keys, changes repository order, replaces packages where necessary, and removes obsolete configuration without stranding users.

Qualify each exact tested configuration. A successful run with pool-built overrides validates that collaboration configuration; it must not be presented as proof that official ARM edge alone is qualified. Record the repository URLs, ordering, signatures, package identities, and test environment with the result. Coordinate official ARM qualification and future RC/stable publication with upstream maintainers in parallel.

## Encrypted installer

Prefer Marcelo's macOS interface and boot preparation where suitable, combined with the temporary-installer placement and encrypted installation developed in `omarchy-mac-iso`. Compare the local prepared-install integration against both current public projects, then reuse the components that satisfy the shared installation contract.

### Installation lifecycle

1. From macOS, prepare the Apple boot environment and allocate the Linux extent. Place the temporary installer at its tail, leaving the target space ahead of it. APFS resizing remains a macOS operation.
2. Record a bound handoff manifest identifying the disk, partitions, approved geometry, artifacts, and installation. Validate it before target writes.
3. Boot Linux, collect the passphrase, create LUKS2 in the target extent, and create the agreed Btrfs layout, initially `@`, `@home`, and `@log` as appropriate to the provisioning contract.
4. Install the recorded signed package set, configure the selected collaboration source, and run shared system/user provisioning. Include package-owned Apple defaults such as `omarchy-settings-asahi` when required.
5. Configure the installed kernel and initramfs so the encrypted root boots independently of the temporary installer. Reboot into that root and verify the active installation identity and boot independence.
6. Reclaim only the recorded installer partition. Extend the root partition without moving its start, resize the active encrypted mapping, and grow the Btrfs filesystem in that order.

Linux root and user data must be encrypted. Identify boot components that remain unencrypted; do not describe this as encryption of macOS or the entire physical disk. No reusable encryption credential may remain in logs, the temporary installer, or unencrypted boot files.

### Interruption and recovery requirements

Installation and reclamation must be explicit, restartable state machines. Keep durable progress and revalidate the actual disk state before each mutation; a progress marker alone does not authorize a write.

Test interruption before and after installer-partition deletion, root-partition growth, encrypted-mapping resize, and filesystem growth. A retry must recognize completed stages without deleting or formatting a different partition. Validate exact identities and geometry, not labels alone. Preserve unrelated Linux installations, macOS, and recovery partitions.

Retain the temporary installer until a successful independent installed boot. Document recovery for failed installation, failed first boot, interrupted reclamation, and failed updates. Reclamation should leave an already bootable installation recoverable even if subsequent growth steps fail.

Resolve package-managed kernel/initramfs ownership and ESP update hooks as part of this work. The existing UUID-private ESP design and managed-kernel-update proposal are inputs to review, not a requirement to retain that exact layout. Test snapshot recovery together with the kernel/modules state, because restoring an encrypted root does not necessarily restore external boot files.

The existing bootstrap may remain a developer or recovery route. Do not imply it creates encryption, or require two equally supported public installers. The recommended release path must meet the encrypted lifecycle above.

## Asahi and Aurora

Start acceptance on Asahi. Marcelo's installer already has an experimental Aurora catalog selection; preserve that opportunity while separating kernel choice from the desktop release channel in the underlying configuration.

Establish the actual package provider, pinned source, modules, headers, firmware/device-tree requirements, initramfs handling, ESP updates, reboot detection, and recovery for each supported kernel selection. Audit hardcoded `linux-asahi` assumptions, including package preflight and xpadneo headers.

Kernel discovery must distinguish running, installed, and selected-for-next-boot kernels, including systems with multiple versions. Avoid replacing a hardcoded name with an arbitrary first match. Removing name assumptions may reduce the downstream delta; it does not prove Aurora requires no other runtime changes. Validate those claims on supported hardware.

## Completed adaptations and remaining upstream work

### Merge tracker

This is the set of upstream contributions we are advocating for the collaboration system. Upstream PR status and inclusion in our branch are tracked separately: a change can be running successfully here while its upstream PR remains open. PR statuses and head revisions were checked on 2026-09-17. Inclusion below refers to the collaboration branch at `0f5cb383`; adapted or cherry-picked equivalents need not share the upstream commit hash.

| Contribution | Upstream source branch and checked head | Upstream status | In the collaboration branch? | Next action |
| --- | --- | --- | --- | --- |
| [#9835 — Apple Silicon foundation](https://github.com/omacom/omarchy/pull/9835) | `maralcbr:omacom/asahi-overlay` — `980ce7eb` | Open | Yes, rebased/adapted foundation including the availability, pacman, keyring, and settings work | Coordinate Marcelo's review; compare the final merged tree and retain only our remaining delta |
| [#12056 — Provisioning robustness](https://github.com/omacom/omarchy/pull/12056) | `scottjones:pr/provisioning-robustness` — `400dad0d` | Open | Yes, equivalent first-run, DMI, and locate-test fixes | Continue upstream review independently of the Apple platform submission |
| [#12058 — Battery rounding](https://github.com/omacom/omarchy/pull/12058) | `scottjones:pr/battery-rounding` — `9aa09a0b` | Open | Yes, rounding commit `305a4b3e` | Continue upstream review; keep separate from the Apple-specific platform delta |
| [#8942 — Clock/weather popup anchoring](https://github.com/omacom/omarchy/pull/8942) | `scottjones:panels-anchor-to-widget` — `7a341007` | Open | Yes, equivalent commit `be1c114b`, pushed to `quattro-upstream` | Advocate the existing general-desktop PR; keep it out of D. Five focused tests passed, and Scott confirmed the live result after shell reload |
| [#9834 — Refuse shell tests as root](https://github.com/omacom/omarchy/pull/9834) | `maralcbr:omacom/no-root-mount-tests` — `79c919b9` | Open | Yes, cherry-picked as `0f5cb383` with Marcelo's authorship and source reference preserved | Advocate Marcelo's existing PR separately from D. Syntax checks and the normal-user Windows VM regression test pass; unprivileged user-namespace checks verify runner root refusal, the explicit fixture-only override, and unconditional Windows mount-test root skipping |

Additional work to prepare for submission:

| Work | Branch or component | Collaboration status | Submission path |
| --- | --- | --- | --- |
| Remaining Apple platform support (D) | `pr/apple-silicon` — `e0b622a2` | Included; this extraction branch does not contain [#8942](https://github.com/omacom/omarchy/pull/8942) | Prepare the remaining delta after reconciling [#9835](https://github.com/omacom/omarchy/pull/9835) and package prerequisites; no upstream PR recorded yet |
| Keyboard ambient-light control (E) | `pr/keyboard-als` — `071e54e8` | Equivalent integration commit `785ba933` included | Prepare an independent PR; no need to wait for unrelated installer work |
| Steam/FEX | `omarchy-steam-fex` package and desktop integration | Desktop integration included; package publication/signing remains part of the delivery work | Track the package recipe/publication and any separate runtime submission; `pr/steam-fex` now points at D and is not a separate active series |
| Required Mac packages | Eight-package publication worklist above | Dependencies have mixed publication/signing status | Add recipe PR links, build revisions, and published versions as submissions are created |
| Encrypted installer and Aurora integration | Installer projects and package catalogs | Implementation and lifecycle validation work remains | Track in those projects; do not fold their source into the desktop PR |

Update this tracker when a PR head changes, a change enters the collaboration branch, or upstream merges or closes a submission. Record the integrated revision and validation outcome. After an upstream merge, compare its final implementation with our copy, reconcile differences, and remove redundant downstream changes during the next integration. Keep merged rows with their merge revision until that reconciliation is complete. A closed or superseded PR needs an explicit disposition rather than silently disappearing from the list.

### Remaining work

| State | Work |
| --- | --- |
| Already present locally | Explicit `omarchy-pkg-available` menu guards; architecture-specific preinstall and xpadneo targets; `test/fixtures/optional-aarch64-required`; rebased pacman/keyring work from [#9835](https://github.com/omacom/omarchy/pull/9835); packaged Steam launcher integration |
| Still required | Package-channel decision and implementation; signed branch builds; publication of required missing packages; tested repository transition; encrypted installer integration and kernel update ownership; Aurora assumption audit |
| After upstream changes | Compare the actual merged [#9835](https://github.com/omacom/omarchy/pull/9835) tree and subsequent upstream commits against the integration branch, reconcile differences, and extract remaining submissions |

Use tree comparisons and range-diffs against the actual upstream merge to identify equivalent changes, resolve conflicts, and determine the remaining contribution. Run relevant tests after reconciliation.

Continue [#12056](https://github.com/omacom/omarchy/pull/12056) and [#12058](https://github.com/omacom/omarchy/pull/12058) through review and coordinate [#9834](https://github.com/omacom/omarchy/pull/9834)/[#9835](https://github.com/omacom/omarchy/pull/9835) with Marcelo. Independent fixes and package recipes can land while installation work proceeds. Prepare the remaining Apple platform contribution with its real package dependencies and evidence; decide whether it is one PR or several based on the final scope and reviewer feedback. ALS and Steam-related changes retain their own review boundaries where useful.

Propose appropriate recipes for official `omarchy-pkgs` or the relevant upstream provider. Ask Ryan and the maintainers how ARM publication and qualification should work. Disclose temporary dependencies used during testing; do not describe the intended final official package set as if it already supplies the tested system.

## Acceptance evidence

The first complete milestone is:

`recorded signed package set → encrypted fresh installation → independent installed boot → installer-space reclamation → package/kernel update → reboot → recovery`

Run focused and aggregate tests as appropriate. Rehearse destructive operations and interruption cases on disposable storage; use ARM VMs for package transactions and provisioning; use physical Macs for Apple firmware, graphics, audio, suspend, encrypted boot, and recovery. Generic ARM VM success is not Apple hardware validation.

Record model, kernel selection, source and recipe commits, package versions/signers, repository configuration, and test results. Verify encryption and absence of credentials in unencrypted artifacts. Include x86 regression checks for shared runtime changes and upgrade-from-fork tests for the repository transition.

Pool promotion checks complement this evidence. Server-side repository rollback does not automatically undo packages already installed on a Mac.

## Coordination and execution

Concrete next asks, with ownership to be agreed rather than assigned:

| Person | Ask | Expected result |
| --- | --- | --- |
| Scott | Maintain the merge tracker and commit-label convention; continue [#12056](https://github.com/omacom/omarchy/pull/12056)/[#12058](https://github.com/omacom/omarchy/pull/12058)/[#8942](https://github.com/omacom/omarchy/pull/8942); identify which installed configurations need migration | A documented collaboration baseline, upstream submission set, and transition targets |
| Marcelo Alcantara | Agree how to follow [#9835](https://github.com/omacom/omarchy/pull/9835), choose the shared installer repository, and connect his macOS engine to the prepared encrypted installer; identify the exact Asahi/Aurora payload and boot contracts | A source-integration agreement, installer repository home, and versioned handoff specification |
| Naeem | Which signing route should resolve [#394](https://github.com/omacom/omarchy-mac/issues/394): signing the fork repository or moving the collaboration builds to the pool? How should existing machines acquire the keys and retire TrustAll? | A chosen signing route and tested migration design |
| Marcelo B., pool maintainer | Why is ARM edge configuration empty while RC/stable are populated? Can the pool expose an opt-in Mac override collection and build the runtime/settings pair from exact branch commits? What retention and promotion guarantees can it provide? | A usable configuration and an explicit build/publication agreement |
| Wes | Review the encrypted installation and ESP/kernel-update contract; identify the validation needed and whether he wants to own or review part of the Linux installer | Agreed review criteria and an explicit role |
| Ryan and upstream maintainers | Agree the upstream homes for the macOS app and shared Linux installer changes. What source/recipe revision and build process currently produce official ARM edge? What is needed to publish the eight listed packages, and what evidence qualifies ARM channels for wider release? | Agreed repository destinations and a concrete official packaging and qualification path |

Suggested order:

1. Agree the contribution workflow for the published shared branch, choose the shared installer repository with Marcelo, and maintain the merge tracker as changes are integrated and submitted.
2. Resolve whether the pool can provide the selectable override collection and exact-source builds. In parallel, define the installed-system contract: encryption, layout, boot ownership, updates, and reclamation states.
3. Assemble a signed, recorded package candidate and validate package selection and transition behavior. Use a documented signed fallback source if the pool cannot yet supply the required collection.
4. Integrate the macOS-to-Linux handoff and encrypted installer, including restartable reclamation and package-managed kernel updates.
5. Complete the Asahi lifecycle on agreed hardware, then broaden testing and qualify Aurora separately.
6. Land ready upstream fixes and recipes throughout this work; extract the remaining platform changes as their prerequisites and review scope stabilize.

The next deliverable is a shared package-and-installed-system contract, followed by one reproducible encrypted Asahi candidate.

## References

- [Shared branch](https://github.com/omacom/omarchy-mac/tree/quattro-upstream); upstream PRs [#9834](https://github.com/omacom/omarchy/pull/9834), [#9835](https://github.com/omacom/omarchy/pull/9835), [#12056](https://github.com/omacom/omarchy/pull/12056), [#12058](https://github.com/omacom/omarchy/pull/12058), and [#8942](https://github.com/omacom/omarchy/pull/8942).
- [Official ARM edge database](https://pkgs.omarchy.org/edge/aarch64/omarchy.db); [fork package repository](https://github.com/omarchy-mac/omarchy-pkgs-aarch64); [signing issue #394](https://github.com/omacom/omarchy-mac/issues/394).
- [Pool](https://omarchy-pool.firemanxbr.org/), [source](https://github.com/firemanxbr/omarchy-pool), [live inventories](https://omarchy-pool.firemanxbr.org/api/v1/stats), and [security model](https://omarchy-pool.firemanxbr.org/docs/security-model).
- [Marcelo's runtime and installer](https://github.com/maralcbr/omarchy-mx-mac); local `~/code/omarchy-mac-iso/README.md` and its `plans/managed-kernel-updates.md`; local prepared-install work under `~/code/omarchy-mx-mac-integration/apps/omarchy-apple-installer/Engine/overlay/`.
