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

class Po0FirewallView extends StatelessWidget {
  const Po0FirewallView({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: context.appLocalizations.po0Firewall,
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
                    _SettingsRow(),
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

typedef Po0Overview = ({IconData icon, GlassTone tone, String title});

Po0Overview po0OverviewOf(
  AppLocalizations appLocalizations, {
  required bool enabled,
  required bool hasTokens,
  required Po0FirewallState state,
}) {
  final results = state.results;
  final applied = results
      .where((it) => it.type == Po0ResultType.applied)
      .length;
  if (!enabled) {
    return (
      icon: Icons.shield_outlined,
      tone: GlassTone.neutral,
      title: appLocalizations.po0StatusOff,
    );
  }
  if (!hasTokens) {
    return (
      icon: Icons.key_off_rounded,
      tone: GlassTone.warning,
      title: appLocalizations.po0StatusNoToken,
    );
  }
  if (state.isRunning) {
    return (
      icon: Icons.sync_rounded,
      tone: GlassTone.accent,
      title: appLocalizations.po0Running,
    );
  }
  if (results.isEmpty) {
    return (
      icon: Icons.schedule_rounded,
      tone: GlassTone.neutral,
      title: appLocalizations.po0StatusWaiting,
    );
  }
  if (applied == results.length) {
    return (
      icon: Icons.verified_user_rounded,
      tone: GlassTone.success,
      title: appLocalizations.po0StatusApplied,
    );
  }
  return (
    icon: Icons.gpp_maybe_rounded,
    tone: applied == 0 ? GlassTone.danger : GlassTone.warning,
    title: appLocalizations.po0StatusPartial(applied, results.length),
  );
}

GlassTone _toneOf(Po0ResultType type) => switch (type) {
  Po0ResultType.applied => GlassTone.success,
  Po0ResultType.notApplied || Po0ResultType.disabled => GlassTone.warning,
  Po0ResultType.rejected || Po0ResultType.error => GlassTone.danger,
};

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
    final setting = ref.watch(po0FirewallSettingProvider);
    final state = ref.watch(po0FirewallProvider);
    final notifier = ref.read(po0FirewallProvider.notifier);
    final hasTokens = po0TokensOf(setting.tokenEntries).isNotEmpty;
    final overview = po0OverviewOf(
      appLocalizations,
      enabled: setting.enable,
      hasTokens: hasTokens,
      state: state,
    );
    final color = context.toneColor(overview.tone);
    final canRun = setting.enable && hasTokens && !state.isRunning;
    final exitIp = state.results.map((it) => it.currentIp).nonNulls.firstOrNull;
    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: canRun ? () => unawaited(notifier.query()) : null,
          icon: const Icon(Icons.travel_explore_rounded, size: 18),
          label: Text(appLocalizations.po0QueryStatus),
        ),
        FilledButton.icon(
          onPressed: canRun ? () => unawaited(notifier.whitelist()) : null,
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
          final summary = Row(
            children: [
              _StatusBadge(
                icon: overview.icon,
                color: color,
                spinning: state.isRunning,
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
                    _Ticker(
                      builder: (context) => _OverviewMeta(
                        exitIp: exitIp,
                        lastRunAt: state.lastRunAt,
                        pollSeconds: setting.enable
                            ? setting.pollSeconds
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          if (constraints.maxWidth < 600) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [summary, const SizedBox(height: 18), actions],
            );
          }
          return Row(
            children: [
              Expanded(child: summary),
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
  const _OverviewMeta({
    required this.exitIp,
    required this.lastRunAt,
    required this.pollSeconds,
  });

  final String? exitIp;
  final DateTime? lastRunAt;
  final int? pollSeconds;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final exitIp = this.exitIp;
    final lastRunAt = this.lastRunAt;
    final pollSeconds = this.pollSeconds;
    final style = context.textTheme.bodyMedium?.copyWith(
      color: context.colorScheme.onSurfaceVariant,
    );
    if (exitIp == null && lastRunAt == null) {
      return Text(appLocalizations.po0AutoWhitelistDesc, style: style);
    }
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (exitIp != null)
          GlassPill(
            icon: Icons.my_location_rounded,
            label: exitIp,
            monospace: true,
          ),
        if (lastRunAt != null)
          Text(
            appLocalizations.po0LastShort(
              lastRunAt.getLastUpdateTimeDesc(context),
            ),
            style: style,
          ),
        if (lastRunAt != null && pollSeconds != null) ...[
          Text('·', style: style),
          Text(appLocalizations.po0PollEvery(pollSeconds), style: style),
        ],
      ],
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

class _SettingsRow extends StatelessWidget {
  const _SettingsRow();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        const auto = _AutoWhitelistTile();
        const interval = _PollIntervalTile();
        if (constraints.maxWidth < 600) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [auto, SizedBox(height: 12), interval],
          );
        }
        return const IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: auto),
              SizedBox(width: 12),
              Expanded(flex: 2, child: interval),
            ],
          ),
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
                  appLocalizations.po0AutoWhitelistDesc,
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
        title: appLocalizations.po0PollInterval,
        value: '$seconds',
        suffixText: appLocalizations.seconds,
        resetValue: '${defaultPo0FirewallProps.pollSeconds}',
        inputFormatters: TextInputLimits.limit(TextInputLimits.interval),
        validator: (value) {
          final label = appLocalizations.po0PollInterval;
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
                  appLocalizations.po0PollInterval,
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

class _TokensSection extends ConsumerWidget {
  const _TokensSection();

  Future<void> _edit(WidgetRef ref, {int? index}) async {
    final entries = ref.read(po0FirewallSettingProvider).tokenEntries;
    final entry = await dialogs.showCommonDialog<Po0TokenEntry>(
      child: _TokenEntryDialog(
        entry: index == null ? null : entries[index],
        otherTokens: {
          for (final (i, it) in entries.indexed)
            if (i != index) it.token,
        },
      ),
    );
    if (entry == null) {
      return;
    }
    ref
        .read(po0FirewallSettingProvider.notifier)
        .update(
          (state) => state.copyWith(
            tokenEntries: [
              for (final (i, it) in state.tokenEntries.indexed)
                i == index ? entry : it,
              if (index == null) entry,
            ],
          ),
        );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, int index) async {
    final appLocalizations = context.appLocalizations;
    final confirmed = await dialogs.showMessage(
      message: TextSpan(
        text: appLocalizations.deleteTip(appLocalizations.po0Token),
      ),
    );
    if (confirmed != true) {
      return;
    }
    ref
        .read(po0FirewallSettingProvider.notifier)
        .update(
          (state) => state.copyWith(
            tokenEntries: [...state.tokenEntries]..removeAt(index),
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final entries = ref.watch(
      po0FirewallSettingProvider.select((state) => state.tokenEntries),
    );
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
        if (entries.isEmpty)
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
                        appLocalizations.po0TokensEmpty,
                        style: context.textTheme.titleSmall,
                      ),
                      Text(
                        appLocalizations.po0TokensEmptyDesc,
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
        for (final (index, entry) in entries.indexed)
          Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
            child: _TokenEntryItem(
              entry: entry,
              onEdit: () => _edit(ref, index: index),
              onDelete: () => _delete(context, ref, index),
            ),
          ),
      ],
    );
  }
}

class _TokenEntryItem extends StatelessWidget {
  const _TokenEntryItem({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final Po0TokenEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final token = Po0Token(entry.token);
    final label = token.label;
    return GlassButton(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      onTap: onEdit,
      child: Row(
        children: [
          GlassIconBadge(
            icon: token.kind == Po0TokenKind.ggy
                ? Icons.link_rounded
                : Icons.key_rounded,
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
                if (entry.name.isNotEmpty)
                  Text(
                    label,
                    maxLines: 1,
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
  const _TokenEntryDialog({required this.entry, required this.otherTokens});

  final Po0TokenEntry? entry;
  final Set<String> otherTokens;

  @override
  State<_TokenEntryDialog> createState() => _TokenEntryDialogState();
}

class _TokenEntryDialogState extends State<_TokenEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _tokenController = TextEditingController(
    text: widget.entry?.token,
  );
  late final _nameController = TextEditingController(text: widget.entry?.name);
  late Po0TokenKind _kind = Po0Token(widget.entry?.token ?? '').kind;

  bool get _isGgy => _kind == Po0TokenKind.ggy;

  @override
  void dispose() {
    _tokenController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _setKind(Po0TokenKind? kind) {
    if (kind == null || kind == _kind) {
      return;
    }
    setState(() => _kind = kind);
    if (_tokenController.text.trim().isNotEmpty) {
      _formKey.currentState?.validate();
    }
  }

  String? _validateToken(String? value) {
    final appLocalizations = context.appLocalizations;
    final token = value?.trim() ?? '';
    if (token.isEmpty) {
      return appLocalizations.emptyTip(
        _isGgy ? appLocalizations.ggyLink : appLocalizations.po0Token,
      );
    }
    if (_isGgy && !isGgyLink(token)) {
      return appLocalizations.ggyLinkInvalid;
    }
    if (!_isGgy && !isPo0Token(token)) {
      return appLocalizations.po0TokensInvalid;
    }
    if (widget.otherTokens.contains(token)) {
      return appLocalizations.po0TokenDuplicate;
    }
    return null;
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    Navigator.of(context).pop(
      Po0TokenEntry(
        token: _tokenController.text.trim(),
        name: _nameController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: widget.entry == null
          ? appLocalizations.po0AddToken
          : appLocalizations.po0EditToken,
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
              DropdownButtonFormField<Po0TokenKind>(
                initialValue: _kind,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: appLocalizations.po0TokenType,
                ),
                items: [
                  const DropdownMenuItem(
                    value: Po0TokenKind.po0,
                    child: Text('po0'),
                  ),
                  DropdownMenuItem(
                    value: Po0TokenKind.ggy,
                    child: Text(
                      appLocalizations.ggyWhitelistLink,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: _setKind,
              ),
              TextFormField(
                controller: _tokenController,
                autofocus: widget.entry == null,
                inputFormatters: TextInputLimits.limit(
                  _isGgy ? TextInputLimits.url : TextInputLimits.password,
                ),
                decoration: InputDecoration(
                  labelText: _isGgy
                      ? appLocalizations.ggyLink
                      : appLocalizations.po0Token,
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
    final results = ref.watch(po0FirewallProvider.select((it) => it.results));
    if (results.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassSectionLabel(context.appLocalizations.po0Whitelist),
        for (final (index, result) in results.indexed)
          Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
            child: FadeScaleEnterBox(
              child: _TokenCard(index: index, result: result),
            ),
          ),
      ],
    );
  }
}

class _TokenCard extends StatelessWidget {
  const _TokenCard({required this.index, required this.result});

  final int index;
  final Po0TokenResult result;

  String _summary(AppLocalizations appLocalizations) {
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
    final tone = context.toneColor(_toneOf(result.type));
    final limit = result.limit;
    final used = result.whitelist.length;
    return GlassSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: tone.withValues(alpha: 0.16),
                  shape: AppShape.small,
                ),
                child: Text(
                  '${index + 1}',
                  style: textTheme.labelMedium?.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.name ?? result.label,
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
