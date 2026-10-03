# Fork: po0-clash

This repository (`yuuuki-creation/po0-clash`) is a public fork of `chen08209/FlClash`, shipped as a standalone app that installs
side by side with official FlClash. Everything under `.agents/` still applies; this file adds what is specific to the
fork. Human-facing documentation lives in `docs/` (Chinese).

## What the fork adds

- po0 firewall auto-whitelist (port of `w0ven/po0fw`): `lib/common/po0_firewall.dart`, `lib/models/po0_firewall.dart`,
  `lib/providers/po0_firewall.dart`, `lib/views/po0_firewall.dart`. The page is a top-level navigation item
  (`PageLabel.po0`), not a Tools entry. Design: `docs/features/po0-firewall.md`, decision record:
  `docs/adr/0001-direct-routing-for-po0-api.md`.
- One Liquid Glass UI on every platform (ADR 0009 for the structure, ADR 0010 for the look,
  `docs/features/glass-ui.md`): neutral backgrounds and opaque content cells, glass only on floating controls, tokens in
  `lib/common/glass.dart`, widgets in `lib/widgets/glass.dart`, and a control sidebar / rail / floating dock chosen by
  window width. Widgets never branch on the platform for their look.
- Its own app identity (`docs/adr/0006-standalone-app-identity.md`): app id `io.github.yuuukicreation.po0clash`, executable
  and display name `po0-clash`, `Po0ClashCore` / `Po0ClashHelperService`, its own Inno Setup `AppId`, IPC names, data
  directory and `po0clash://` scheme. No Firebase.
- Build and release plumbing: `.github/workflows/release.yaml`, `scripts/check-release-tag.sh`,
  `scripts/install-macos.sh`, `scripts/vps/*`.

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
  not drop any of the three layers in ADR 0001 (DIRECT `HttpClient`, DIRECT rule plus `route-exclude-address`, Android
  VPN route split) without a new ADR. While the proxy runs, requests go through the core's DIRECT-only listener
  (`po0-direct`, ADR 0012), authenticated with per-session credentials. Only po0's own address may fall back to a plain
  DIRECT socket then (`po0FindProxy`); for anything else TUN would capture it and a ggy link would whitelist the node.
- A ggy whitelist link writes on every GET (ADR 0012), so `Po0FirewallClient.poll`/`query` send it too. ggy is its
  own page and switch (ADR 0013) and polls at the fixed `GgyFirewall.pollInterval` (11 s); do not make it tunable or
  shorter without the maintainer. An eviction it reports is always logged.
- `Po0Firewall` (po0) and `GgyFirewall` (ggy) own scheduling, both through the `WhitelistScheduler` mixin: po0 runs a
  read-only query per token every `pollSeconds` and adds only when the exit is missing (ADR 0004, 0005). po0 tokens
  live in `Po0FirewallProps.tokenEntries` and ggy links in `ggyEntries`; `po0TokensOf` / `ggyLinksOf` are the only way
  to turn them into requests. Other code only signals both (`start`, `pollNow`, `onNetworkChanged`, `setScreenOn`); it
  must not grow another timer or call the client directly. On Android the screen state comes from `Po0ScreenPlugin`
  (`lib/plugins/po0_screen.dart`).
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
- Upstream `build.yaml` is manual-only in this fork and is not used for releases.
