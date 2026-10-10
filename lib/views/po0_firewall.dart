import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/po0_firewall.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _maxContentWidth = 920.0;

typedef WhitelistOverview = ({IconData icon, GlassTone tone, String title});

WhitelistOverview whitelistOverviewOf(
  AppLocalizations appLocalizations, {
  required WhitelistSummary summary,
}) {
  if (!summary.enabled) {
    return (
      icon: Icons.shield_outlined,
      tone: GlassTone.neutral,
      title: appLocalizations.po0StatusOff,
    );
  }
  if (summary.total == 0) {
    return (
      icon: Icons.key_off_rounded,
      tone: GlassTone.warning,
      title: appLocalizations.whitelistNoEntries,
    );
  }
  if (summary.isRunning) {
    return (
      icon: Icons.sync_rounded,
      tone: GlassTone.accent,
      title: appLocalizations.po0Running,
    );
  }
  if (summary.applied == 0 && summary.waiting == summary.total) {
    return (
      icon: Icons.schedule_rounded,
      tone: GlassTone.neutral,
      title: appLocalizations.po0StatusWaiting,
    );
  }
  if (summary.applied == summary.total) {
    return (
      icon: Icons.verified_user_rounded,
      tone: GlassTone.success,
      title: appLocalizations.po0StatusApplied,
    );
  }
  return (
    icon: Icons.gpp_maybe_rounded,
    tone: summary.applied == 0 ? GlassTone.danger : GlassTone.warning,
    title: appLocalizations.po0StatusPartial(summary.applied, summary.total),
  );
}

GlassTone _toneOf(Po0ResultType type) => switch (type) {
  Po0ResultType.applied => GlassTone.success,
  Po0ResultType.notApplied || Po0ResultType.disabled => GlassTone.warning,
  Po0ResultType.rejected || Po0ResultType.error => GlassTone.danger,
};

class WhitelistView extends StatelessWidget {
  const WhitelistView({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: context.appLocalizations.whitelistTitle,
      body: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            24 + BottomInsetScope.of(context),
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _OverviewPanel(),
                    SizedBox(height: 12),
                    _SettingsSection(),
                    _TokensSection(),
                    _TokenResults(),
                    _DirectTip(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rebuilds its subtree periodically so relative times stay current.
class _Ticker extends StatefulWidget {
  const _Ticker({required this.builder});

  final WidgetBuilder builder;

  @override
  State<_Ticker> createState() => _TickerState();
}

class _TickerState extends State<_Ticker> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

class _OverviewPanel extends ConsumerWidget {
  const _OverviewPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final summary = ref.watch(whitelistSummaryProvider);
    final overview = whitelistOverviewOf(appLocalizations, summary: summary);
    final color = context.toneColor(overview.tone);
    final canRun = summary.enabled && summary.total > 0 && !summary.isRunning;
    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (summary.hasPo0)
          OutlinedButton.icon(
            onPressed: canRun
                ? () =>
                      unawaited(ref.read(po0FirewallProvider.notifier).query())
                : null,
            icon: const Icon(Icons.travel_explore_rounded, size: 18),
            label: Text(appLocalizations.whitelistQueryPo0),
          ),
        FilledButton.icon(
          onPressed: canRun
              ? () {
                  if (summary.hasPo0) {
                    unawaited(
                      ref.read(po0FirewallProvider.notifier).whitelist(),
                    );
                  }
                  if (summary.hasGgy) {
                    unawaited(
                      ref.read(ggyFirewallProvider.notifier).whitelist(),
                    );
                  }
                }
              : null,
          icon: const Icon(Icons.bolt_rounded, size: 18),
          label: Text(appLocalizations.po0WhitelistNow),
        ),
      ],
    );
    return GlassSurface(
      borderRadius: AppRadius.large,
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final summaryRow = Row(
            children: [
              _StatusBadge(
                icon: overview.icon,
                color: color,
                spinning: summary.isRunning,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeBox(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        overview.title,
                        key: ValueKey(overview.title),
                        style: context.textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _Ticker(builder: (_) => _OverviewMeta(summary: summary)),
                  ],
                ),
              ),
            ],
          );
          if (constraints.maxWidth < 600) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [summaryRow, const SizedBox(height: 18), actions],
            );
          }
          return Row(
            children: [
              Expanded(child: summaryRow),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _OverviewMeta extends StatelessWidget {
  const _OverviewMeta({required this.summary});

  final WhitelistSummary summary;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final style = context.textTheme.bodyMedium?.copyWith(
      color: context.colorScheme.onSurfaceVariant,
    );
    final children = <Widget>[];
    final po0Exit = summary.po0Exit;
    final ggyExit = summary.ggyExit;
    if (po0Exit != null && ggyExit != null && !sameC24(po0Exit, ggyExit)) {
      // The services report different networks; never merge them into one
      // made-up shared exit.
      for (final (service, ip) in [
        (appLocalizations.whitelistPo0Token, po0Exit),
        (appLocalizations.whitelistGgyLink, ggyExit),
      ]) {
        children.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(service, style: style),
              const SizedBox(width: 6),
              GlassPill(label: ip, monospace: true),
            ],
          ),
        );
      }
    } else if (whitelistSharedExitOf(summary) case final exit?) {
      children.add(
        GlassPill(
          icon: Icons.my_location_rounded,
          label: exit,
          monospace: true,
        ),
      );
    }
    final lastPo0At = summary.hasPo0 ? summary.lastPo0At : null;
    final lastGgyAt = summary.hasGgy ? summary.lastGgyAt : null;
    if (lastPo0At != null) {
      children.add(
        Text(
          appLocalizations.whitelistLastPo0(
            lastPo0At.getLastUpdateTimeDesc(context),
          ),
          style: style,
        ),
      );
    }
    if (lastGgyAt != null) {
      children.add(
        Text(
          appLocalizations.whitelistLastGgy(
            lastGgyAt.getLastUpdateTimeDesc(context),
          ),
          style: style,
        ),
      );
    }
    if (children.isEmpty) {
      return Text(appLocalizations.whitelistAutoDesc, style: style);
    }
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.icon,
    required this.color,
    required this.spinning,
  });

  static const _size = 60.0;

  final IconData icon;
  final Color color;
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: color),
      duration: context.motionDuration(Durations.medium2),
      curve: Easing.standard,
      builder: (_, color, _) {
        final accent = color ?? this.color;
        return DecoratedBox(
          decoration: ShapeDecoration(
            color: accent.withValues(alpha: context.glass.isDark ? 0.22 : 0.14),
            shape: const CircleBorder(),
          ),
          child: SizedBox.square(
            dimension: _size,
            child: Center(
              child: spinning
                  ? SizedBox.square(
                      dimension: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: accent,
                      ),
                    )
                  : Icon(icon, color: accent, size: 30),
            ),
          ),
        );
      },
    );
  }
}

class _SettingsSection extends ConsumerWidget {
  const _SettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPo0 = ref.watch(
      whitelistSummaryProvider.select((summary) => summary.hasPo0),
    );
    final hasGgy = ref.watch(
      whitelistSummaryProvider.select((summary) => summary.hasGgy),
    );
    final ggyNote = hasGgy ? const _GgyIntervalTile() : null;
    const auto = _AutoWhitelistTile();
    if (!hasPo0) {
      return ggyNote == null
          ? auto
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [auto, const SizedBox(height: 12), ggyNote],
            );
    }
    const interval = _PollIntervalTile();
    return LayoutBuilder(
      builder: (_, constraints) {
        final pair = <Widget>[
          const Expanded(flex: 3, child: auto),
          const SizedBox(width: 12),
          const Expanded(flex: 2, child: interval),
        ];
        if (constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              auto,
              const SizedBox(height: 12),
              interval,
              if (ggyNote != null) ...[const SizedBox(height: 12), ggyNote],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: pair,
              ),
            ),
            if (ggyNote != null) ...[const SizedBox(height: 12), ggyNote],
          ],
        );
      },
    );
  }
}

class _AutoWhitelistTile extends ConsumerWidget {
  const _AutoWhitelistTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final enabled = ref.watch(
      po0FirewallSettingProvider.select((state) => state.enable),
    );
    void toggle(bool value) => ref
        .read(po0FirewallSettingProvider.notifier)
        .update((state) => state.copyWith(enable: value));
    return GlassButton(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      onTap: () => toggle(!enabled),
      child: Row(
        children: [
          GlassIconBadge(
            icon: Icons.shield_rounded,
            color: context.toneColor(GlassTone.success),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appLocalizations.po0AutoWhitelist,
                  style: context.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  appLocalizations.whitelistAutoDesc,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(value: enabled, onChanged: toggle),
        ],
      ),
    );
  }
}

class _PollIntervalTile extends ConsumerWidget {
  const _PollIntervalTile();

  Future<void> _edit(BuildContext context, WidgetRef ref, int seconds) async {
    final appLocalizations = context.appLocalizations;
    final (:min, :max) = po0PollSecondsRange;
    final value = await dialogs.showCommonDialog<String>(
      child: InputDialog(
        title: appLocalizations.whitelistPo0Interval,
        value: '$seconds',
        suffixText: appLocalizations.seconds,
        resetValue: '${defaultPo0FirewallProps.pollSeconds}',
        inputFormatters: TextInputLimits.limit(TextInputLimits.interval),
        validator: (value) {
          final label = appLocalizations.whitelistPo0Interval;
          if (value == null || value.isEmpty) {
            return appLocalizations.emptyTip(label);
          }
          final number = int.tryParse(value);
          if (number == null) {
            return appLocalizations.numberTip(label);
          }
          if (number < min || number > max) {
            return appLocalizations.po0PollIntervalRange(min, max);
          }
          return null;
        },
      ),
    );
    if (value == null) {
      return;
    }
    ref
        .read(po0FirewallSettingProvider.notifier)
        .update((state) => state.copyWith(pollSeconds: int.parse(value)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final seconds = ref.watch(
      po0FirewallSettingProvider.select((state) => state.pollSeconds),
    );
    return GlassButton(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      onTap: () => _edit(context, ref, seconds),
      child: Row(
        children: [
          const GlassIconBadge(icon: Icons.timer_rounded),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  appLocalizations.whitelistPo0Interval,
                  style: context.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  appLocalizations.secondsCount(seconds),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.edit_rounded,
            size: 18,
            color: context.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

/// ggy's fixed cadence is information, not a setting (ADR 0013).
class _GgyIntervalTile extends StatelessWidget {
  const _GgyIntervalTile();

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return GlassSurface(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          const GlassIconBadge(icon: Icons.timer_rounded),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  appLocalizations.whitelistGgyInterval(
                    GgyFirewall.pollInterval.inSeconds,
                  ),
                  style: context.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  appLocalizations.whitelistEntriesEmptyDesc,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

typedef _EntryRow = ({Po0TokenKind kind, int index, Po0TokenEntry entry});

class _TokensSection extends ConsumerWidget {
  const _TokensSection();

  Future<void> _edit(WidgetRef ref, {_EntryRow? row}) async {
    final result = await dialogs
        .showCommonDialog<({Po0TokenKind kind, Po0TokenEntry entry})>(
          child: _TokenEntryDialog(
            initialKind: row?.kind ?? Po0TokenKind.po0,
            entry: row?.entry,
            otherTokensOf: (kind) {
              final setting = ref.read(po0FirewallSettingProvider);
              final entries = kind == Po0TokenKind.ggy
                  ? setting.ggyEntries
                  : setting.tokenEntries;
              final editedIndex = row != null && row.kind == kind
                  ? entries.indexOf(row.entry)
                  : -1;
              return {
                for (final (i, entry) in entries.indexed)
                  if (i != editedIndex) entry.token,
              };
            },
          ),
        );
    if (result == null || !ref.context.mounted) {
      return;
    }
    final appLocalizations = ref.context.appLocalizations;
    final duplicateMessage = result.kind == Po0TokenKind.ggy
        ? appLocalizations.ggyLinkDuplicate
        : appLocalizations.po0TokenDuplicate;
    try {
      ref
          .read(po0FirewallSettingProvider.notifier)
          .update(
            (state) => switch (result.kind) {
              Po0TokenKind.po0 => state.copyWith(
                tokenEntries: _applyEntry(
                  state.tokenEntries,
                  row,
                  result.entry,
                  duplicateMessage,
                ),
              ),
              Po0TokenKind.ggy => state.copyWith(
                ggyEntries: _applyEntry(
                  state.ggyEntries,
                  row,
                  result.entry,
                  duplicateMessage,
                ),
              ),
            },
          );
    } on MessageException catch (error) {
      dialogs.showNotifier(error.message, level: MessageLevel.error);
    }
  }

  List<Po0TokenEntry> _applyEntry(
    List<Po0TokenEntry> latest,
    _EntryRow? row,
    Po0TokenEntry entry,
    String duplicateMessage,
  ) {
    final index = row == null ? -1 : latest.indexOf(row.entry);
    if (row != null && index == -1) {
      return latest;
    }
    if (latest.indexed.any(
      (it) => it.$1 != index && it.$2.token == entry.token,
    )) {
      throw MessageException(duplicateMessage);
    }
    if (row == null) {
      return [...latest, entry];
    }
    return [for (final (i, it) in latest.indexed) i == index ? entry : it];
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    _EntryRow row,
  ) async {
    final appLocalizations = context.appLocalizations;
    final confirmed = await dialogs.showMessage(
      message: TextSpan(
        text: appLocalizations.deleteTip(
          row.kind == Po0TokenKind.ggy
              ? appLocalizations.whitelistGgyLink
              : appLocalizations.whitelistPo0Token,
        ),
      ),
    );
    if (confirmed != true) {
      return;
    }
    ref
        .read(po0FirewallSettingProvider.notifier)
        .update(
          (state) => switch (row.kind) {
            Po0TokenKind.po0 => state.copyWith(
              tokenEntries: [...state.tokenEntries]..remove(row.entry),
            ),
            Po0TokenKind.ggy => state.copyWith(
              ggyEntries: [...state.ggyEntries]..remove(row.entry),
            ),
          },
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final setting = ref.watch(po0FirewallSettingProvider);
    final rows = [
      for (final (index, entry) in setting.tokenEntries.indexed)
        (kind: Po0TokenKind.po0, index: index, entry: entry),
      for (final (index, entry) in setting.ggyEntries.indexed)
        (kind: Po0TokenKind.ggy, index: index, entry: entry),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassSectionLabel(
          appLocalizations.po0Tokens,
          trailing: TextButton.icon(
            onPressed: () => _edit(ref),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(appLocalizations.po0AddToken),
          ),
          padding: const EdgeInsets.fromLTRB(6, 16, 0, 6),
        ),
        if (rows.isEmpty)
          GlassButton(
            padding: const EdgeInsets.all(16),
            onTap: () => _edit(ref),
            child: Row(
              children: [
                GlassIconBadge(
                  icon: Icons.key_off_rounded,
                  color: context.toneColor(GlassTone.warning),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appLocalizations.whitelistNoEntries,
                        style: context.textTheme.titleSmall,
                      ),
                      Text(
                        appLocalizations.whitelistEntriesEmptyDesc,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        for (final (index, row) in rows.indexed)
          Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
            child: _TokenEntryItem(
              row: row,
              onEdit: () => _edit(ref, row: row),
              onDelete: () => _delete(context, ref, row),
            ),
          ),
      ],
    );
  }
}

class _TokenEntryItem extends StatelessWidget {
  const _TokenEntryItem({
    required this.row,
    required this.onEdit,
    required this.onDelete,
  });

  final _EntryRow row;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final entry = row.entry;
    final isGgy = row.kind == Po0TokenKind.ggy;
    final label = Po0Token(entry.token).label;
    final kindLabel = isGgy
        ? appLocalizations.whitelistGgyLink
        : appLocalizations.whitelistPo0Token;
    return GlassButton(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      onTap: onEdit,
      child: Row(
        children: [
          GlassIconBadge(
            icon: isGgy ? Icons.link_rounded : Icons.key_rounded,
            size: 36,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name.isNotEmpty ? entry.name : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleSmall,
                ),
                Text(
                  '$kindLabel · $label',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                    fontFamily: FontFamily.jetBrainsMono.value,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: appLocalizations.edit,
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: appLocalizations.delete,
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _TokenEntryDialog extends StatefulWidget {
  const _TokenEntryDialog({
    required this.initialKind,
    required this.entry,
    required this.otherTokensOf,
  });

  final Po0TokenKind initialKind;
  final Po0TokenEntry? entry;
  final Set<String> Function(Po0TokenKind kind) otherTokensOf;

  @override
  State<_TokenEntryDialog> createState() => _TokenEntryDialogState();
}

class _TokenEntryDialogState extends State<_TokenEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late Po0TokenKind _kind = widget.initialKind;
  late final _tokenController = TextEditingController(
    text: widget.entry?.token,
  );
  late final _nameController = TextEditingController(text: widget.entry?.name);

  bool get _isEdit => widget.entry != null;

  bool get _isGgy => _kind == Po0TokenKind.ggy;

  @override
  void dispose() {
    _tokenController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String? _validateToken(String? value) {
    final appLocalizations = context.appLocalizations;
    final token = value?.trim() ?? '';
    if (token.isEmpty) {
      return appLocalizations.emptyTip(_kindLabel);
    }
    if (_isGgy && !isGgyLink(token)) {
      return appLocalizations.ggyLinkInvalid;
    }
    if (!_isGgy && !isPo0Token(token)) {
      return appLocalizations.po0TokensInvalid;
    }
    if (widget.otherTokensOf(_kind).contains(token)) {
      return _isGgy
          ? appLocalizations.ggyLinkDuplicate
          : appLocalizations.po0TokenDuplicate;
    }
    return null;
  }

  String get _kindLabel => _isGgy
      ? context.appLocalizations.whitelistGgyLink
      : context.appLocalizations.whitelistPo0Token;

  void _submit() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    Navigator.of(context).pop((
      kind: _kind,
      entry: Po0TokenEntry(
        token: _tokenController.text.trim(),
        name: _nameController.text.trim(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: _isEdit
          ? appLocalizations.po0EditToken
          : appLocalizations.po0AddToken,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(appLocalizations.submit)),
      ],
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            spacing: 24,
            children: [
              if (_isEdit)
                Row(
                  children: [
                    Text(
                      appLocalizations.whitelistEntryType,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GlassPill(label: _kindLabel),
                  ],
                )
              else
                GlassSegmented<Po0TokenKind>(
                  values: Po0TokenKind.values,
                  selected: _kind,
                  labelOf: (kind) => kind == Po0TokenKind.ggy
                      ? appLocalizations.whitelistGgyLink
                      : appLocalizations.whitelistPo0Token,
                  onChanged: (kind) => setState(() => _kind = kind),
                ),
              TextFormField(
                controller: _tokenController,
                autofocus: !_isEdit,
                inputFormatters: TextInputLimits.limit(
                  _isGgy ? TextInputLimits.url : TextInputLimits.password,
                ),
                decoration: InputDecoration(
                  labelText: _kindLabel,
                  hintText: _isGgy
                      ? 'https://www.guguyun.com/…?token=ctecsfw_xxx'
                      : 'pgnfw_xxx',
                ),
                validator: _validateToken,
                onFieldSubmitted: (_) => _submit(),
              ),
              TextFormField(
                controller: _nameController,
                inputFormatters: TextInputLimits.limit(TextInputLimits.name),
                decoration: InputDecoration(
                  labelText: appLocalizations.po0TokenName,
                ),
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TokenResults extends ConsumerWidget {
  const _TokenResults();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref
        .watch(whitelistSummaryProvider.select((summary) => summary.entries))
        .where((status) => status.result != null)
        .toList();
    if (statuses.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassSectionLabel(context.appLocalizations.po0Whitelist),
        for (final (index, status) in statuses.indexed)
          Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
            child: FadeScaleEnterBox(child: _TokenCard(status: status)),
          ),
      ],
    );
  }
}

class _TokenCard extends StatelessWidget {
  const _TokenCard({required this.status});

  final WhitelistEntryStatus status;

  String _summary(AppLocalizations appLocalizations) {
    final result = status.result!;
    final ip = result.currentIp ?? appLocalizations.unknown;
    final message = result.message ?? '';
    return switch (result.type) {
      Po0ResultType.applied => appLocalizations.po0ResultApplied(ip),
      Po0ResultType.notApplied => appLocalizations.po0ResultNotApplied(ip),
      Po0ResultType.disabled => appLocalizations.po0ResultDisabled,
      Po0ResultType.rejected => appLocalizations.po0ResultRejected(message),
      Po0ResultType.error => appLocalizations.po0ResultError(message),
    };
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final textTheme = context.textTheme;
    final colorScheme = context.colorScheme;
    final result = status.result!;
    final tone = context.toneColor(_toneOf(result.type));
    final limit = result.limit;
    final used = result.whitelist.length;
    final isGgy = status.service == WhitelistService.ggy;
    return GlassSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 26,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: tone.withValues(alpha: 0.16),
                  shape: AppShape.small,
                ),
                child: Text(
                  isGgy ? 'ggy' : 'po0',
                  style: textTheme.labelSmall?.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  status.entry.name.isNotEmpty
                      ? status.entry.name
                      : status.token.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium,
                ),
              ),
              GlassPill(
                color: tone,
                label: switch (result.type) {
                  Po0ResultType.applied => appLocalizations.po0ChipApplied,
                  Po0ResultType.notApplied =>
                    appLocalizations.po0ChipNotApplied,
                  Po0ResultType.disabled => appLocalizations.po0ChipDisabled,
                  Po0ResultType.rejected => appLocalizations.po0ChipRejected,
                  Po0ResultType.error => appLocalizations.po0ChipError,
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _summary(appLocalizations),
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (limit != null && limit > 0) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: 0,
                      end: (used / limit).clamp(0, 1).toDouble(),
                    ),
                    duration: Durations.long2,
                    curve: Easing.emphasizedDecelerate,
                    builder: (_, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 6,
                      color: tone,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  appLocalizations.po0Usage(used, limit),
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
          if (result.whitelist.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in result.whitelist)
                  _EntryChip(
                    entry: entry,
                    isCurrent: sameC24(entry.ip, result.currentIp),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EntryChip extends StatelessWidget {
  const _EntryChip({required this.entry, required this.isCurrent});

  final Po0WhitelistEntry entry;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final slot = entry.slot;
    final chip = GlassPill(
      icon: isCurrent
          ? Icons.my_location_rounded
          : slot != null
          ? Icons.push_pin_rounded
          : null,
      color: isCurrent ? null : context.colorScheme.onSurfaceVariant,
      label: slot == null ? entry.ip : '${entry.ip} · $slot',
      monospace: true,
    );
    return isCurrent
        ? Tooltip(message: context.appLocalizations.po0CurrentExit, child: chip)
        : chip;
  }
}

class _DirectTip extends StatelessWidget {
  const _DirectTip();

  @override
  Widget build(BuildContext context) {
    final color = context.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 20, 6, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.appLocalizations.po0DirectTip,
              style: context.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
