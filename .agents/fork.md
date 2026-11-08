# Fork: po0-clash

This repository (`yuuuki-creation/po0-clash`) is a public fork of `chen08209/FlClash`, shipped as a standalone app that installs
side by side with official FlClash. Everything under `.agents/` still applies; this file adds what is specific to the
fork. Human-facing documentation lives in `docs/` (Chinese).

## What the fork adds

- po0 firewall auto-whitelist (port of `w0ven/po0fw`): `lib/common/po0_firewall.dart`, `lib/models/po0_firewall.dart`,
  `lib/providers/po0_firewall.dart`, `lib/views/po0_firewall.dart`. po0 and ggy share one top-level navigation item
  (`PageLabel.whitelist`), one master switch and one mixed entry list (ADR 0014). Design: `docs/features/po0-firewall.md`,
  decision record: `docs/adr/0001-direct-routing-for-po0-api.md`.
- Share-link node import (ADR 0015, `docs/features/share-link-nodes.md`): the core method `convertShareLinks`
  (`core/share_links.go`) wraps mihomo's converter; `lib/common/node_profile.dart` renders the "manual nodes" profile
  from `assets/data/node_profile_template.yaml`, `lib/providers/node_profile.dart` owns import / rename / delete, and
  `lib/views/profiles/nodes.dart` is the node page. The profile's `proxies` list is the only node store and every change
  rewrites the file from the template; `Config.nodeProfileId` records which profile it is.
- One minimal UI built with Material components on every platform (ADR 0016, `docs/features/glass-ui.md`): neutral opaque surfaces, generous spacing, blue primary actions,
  a bottom navigation bar / simple sidebar, and a dedicated dashboard on every window width. Existing `Glass*`
  interfaces now render Material components. UI statistics pause off the visible dashboard unless macOS tray speed is
  enabled; this never changes proxy or whitelist intent. Widgets never branch on the platform for their look.
- Its own app identity (`docs/adr/0006-standalone-app-identity.md`): app id `io.github.yuuukicreation.po0clash`, executable
  and display name `po0-clash`, `Po0ClashCore` / `Po0ClashHelperService`, its own Inno Setup `AppId`, IPC names, data
  directory and `po0clash://` scheme. No Firebase.
- Build and release plumbing: `.github/workflows/release.yaml`, `scripts/check-release-tag.sh`,
  `scripts/install-macos.sh`, `scripts/vps/*`, and `.github/workflows/windows-validation.yaml`.

## Rules

- Keep fork logic in fork-owned files and limit edits to upstream files to wiring. The list of touched upstream files is
  in `docs/development/upstream-sync.md`; update it whenever a new upstream file gains a fork edit, because that list is
  what makes the next upstream merge tractable.
- Nothing the OS can see may collide with FlClash: package / bundle / installer ids, process and service names,
  sockets, pipes, lock and data paths, autostart entries, app-specific URL schemes. Use the identifiers in ADR 0006,
  and keep internal names (`fl_clash`, the `com.follow.clash*` Kotlin packages and Gradle `namespace`, `FlClash*`
  classes) unchanged. Where code needs the installed app id, read it at runtime (`context.packageName`), never from
  the namespace.
- The po0 request must leave on the physical network. Do not route it through `request`/`FlClashHttpOverrides`, and do
  not drop any of the three layers in ADR 0001 (the DIRECT transport, now `plugins/rust_api`'s `whitelist` module per
  ADR 0017; DIRECT rule plus `route-exclude-address`; Android VPN route split) without a new ADR. While the proxy runs, requests go through the core's DIRECT-only listener
  (`po0-direct`, ADR 0012), authenticated with per-session credentials. Only po0's own address may fall back to a plain
  DIRECT socket then (`po0FindProxy`); for anything else TUN would capture it and a ggy link would whitelist the node.
- A ggy whitelist link writes on every GET (ADR 0012), so `Po0FirewallClient.poll`/`query` send it too. ggy shares the
  unified whitelist page and the master switch (ADR 0014) and polls at the fixed `GgyFirewall.pollInterval` (11 s); do
  not make it tunable or shorter without the maintainer. An eviction it reports is always logged.
- `Po0Firewall` (po0) and `GgyFirewall` (ggy) own scheduling, both through the `WhitelistScheduler` mixin and both driven
  by the master switch `Po0FirewallProps.enable`: po0 runs a read-only query per token every `pollSeconds` and adds only
  when the exit is missing (ADR 0004, 0005). po0 tokens live in `Po0FirewallProps.tokenEntries` and ggy links in
  `ggyEntries`; `po0TokensOf` / `ggyLinksOf` are the only way to turn them into requests. A master-switch change routes
  through `WhitelistCoordinator` (one profile reload for both schedulers, ADR 0014); other code only signals both
  (`start`, `pollNow`, `pollIfDue`, `onNetworkChanged`, `setScreenOn`); it must not grow another timer or call the client directly.
  On Android the screen state comes from `Po0ScreenPlugin` (`lib/plugins/po0_screen.dart`).
- On desktop exactly one of TUN and the system proxy is on (ADR 0011). Route changes go through
  `SystemAction.useRoute`; the `AppStateManager` listener runs `reconcileDesktopRoute` for every other writer, and a
  failed TUN authorization falls back to the system proxy. Do not add a second place that enforces or bypasses this.
- Tokens are credentials: never log or display more than `Po0Token.label`, and redact them from error text.
- The app has its own semver, independent of upstream; this repository starts at 5.0.0 and the maintainer picks every
  release's version. `pubspec.yaml` `version` is the only source; a release tag is `v<version without +build>`
  (`v5.0.0`), and `scripts/check-release-tag.sh` fails the build otherwise. Bump the version and its build number (Android `versionCode`, must only grow) in the change that prepares
  a release. On upstream merges, a `pubspec.yaml` version conflict always keeps ours.
- Never push a release tag or trigger `release.yaml` unless the maintainer explicitly asks for a release.
- Commit messages follow `.agents/rules.md`; no agent `Co-authored-by` trailers.
- The Android release keystore `android/app/keystore.jks` and `android/signing.properties` are committed on purpose
  (ADR 0006); do not replace them, since a new key forces every user to reinstall. Never commit any other secret,
  including `android/local.properties`.

## Where things run

- Flutter tooling (codegen, format, analyze, test, coverage) runs on the build VPS; see `docs/development/build.md`.
  `scripts/vps/verify.sh` is the CI-equivalent gate.
- Release packages for Android, Windows and macOS are built by `.github/workflows/release.yaml` on GitHub runners, only
  on a `v[0-9]*` tag push or a manual dispatch; see `docs/development/release.md`.
- `windows-validation.yaml` runs on relevant same-repository PRs and manual requests. It tests setup hooks and native
  Windows Rust code, and validates signing / install / uninstall with fixture binaries. It does not build or publish
  release applications; fork PRs do not receive signing Secrets.
- Upstream `build.yaml` is manual-only in this fork and is not used for releases.
