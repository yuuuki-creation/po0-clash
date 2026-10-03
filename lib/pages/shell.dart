import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/control/connect_orb.dart';
import 'package:fl_clash/views/control/control_center.dart';
import 'package:fl_clash/views/control/tiles.dart';
import 'package:fl_clash/views/po0_firewall.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef OnDestinationSelected = void Function(PageLabel label);

IconData _iconOf(NavigationItem item) => item.icon.icon ?? Icons.circle;

/// The floating capsule that navigates on phones. Pages scroll beneath it, so
/// it is the one surface that blurs what it covers.
class GlassDock extends StatelessWidget {
  const GlassDock({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  static const height = 66.0;
  static const margin = 12.0;

  static double extentOf(BuildContext context) =>
      height + margin * 2 + MediaQuery.paddingOf(context).bottom;

  final List<NavigationItem> items;
  final int currentIndex;
  final OnDestinationSelected onSelected;

  @override
  Widget build(BuildContext context) {
    final count = items.length;
    final duration = context.motionDuration(Durations.medium2);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        margin,
        16,
        margin + MediaQuery.paddingOf(context).bottom,
      ),
      child: SizedBox(
        height: height,
        child: GlassSurface(
          kind: GlassKind.chrome,
          borderRadius: AppRadius.full,
          child: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (count > 0)
                    AnimatedAlign(
                      duration: duration,
                      curve: Easing.emphasizedDecelerate,
                      alignment: Alignment(
                        count == 1 ? 0 : -1 + 2 * currentIndex / (count - 1),
                        0,
                      ),
                      child: FractionallySizedBox(
                        widthFactor: 1 / count,
                        heightFactor: 1,
                        child: const _SelectionPill(),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (index, item) in items.indexed)
                        Expanded(
                          child: _DockItem(
                            icon: _iconOf(item),
                            label: item.label.label,
                            selected: index == currentIndex,
                            onTap: () => onSelected(item.label),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionPill extends StatelessWidget {
  const _SelectionPill({this.borderRadius});

  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final borderRadius = this.borderRadius;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: context.glass.selected,
        shape: borderRadius == null ? AppShape.full : AppShape.of(borderRadius),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.borderRadius,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final color = selected ? colorScheme.primary : colorScheme.onSurfaceVariant;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: borderRadius == null
            ? AppShape.full
            : AppShape.of(borderRadius!),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The narrow-window navigation: a vertical glass capsule of icons.
class GlassRail extends StatelessWidget {
  const GlassRail({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  static const width = 84.0;
  static const _itemHeight = 64.0;
  static const _pillInset = 2.0;

  final List<NavigationItem> items;
  final int currentIndex;
  final OnDestinationSelected onSelected;

  @override
  Widget build(BuildContext context) {
    final duration = context.motionDuration(Durations.medium2);
    return SizedBox(
      width: width,
      child: GlassSurface(
        kind: GlassKind.panel,
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Stack(
              children: [
                if (items.isNotEmpty)
                  AnimatedPositioned(
                    duration: duration,
                    curve: Easing.emphasizedDecelerate,
                    top: currentIndex * _itemHeight + _pillInset,
                    left: _pillInset,
                    right: _pillInset,
                    height: _itemHeight - _pillInset * 2,
                    child: const _SelectionPill(borderRadius: AppRadius.medium),
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, item) in items.indexed)
                      SizedBox(
                        height: _itemHeight,
                        child: _DockItem(
                          icon: _iconOf(item),
                          label: item.label.label,
                          selected: index == currentIndex,
                          borderRadius: AppRadius.medium,
                          onTap: () => onSelected(item.label),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The wide-window sidebar: the whole control center on top, the spaces below
/// it with a live line each, and the network at the foot.
class ControlSidebar extends StatelessWidget {
  const ControlSidebar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    this.topInset = 0,
  });

  static const width = 300.0;

  final List<NavigationItem> items;
  final int currentIndex;
  final OnDestinationSelected onSelected;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: GlassSurface(
        kind: GlassKind.panel,
        child: Material(
          type: MaterialType.transparency,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 16 + topInset, 16, 0),
                sliver: SliverList.list(
                  children: [
                    const BrandHeader(dense: true),
                    const SizedBox(height: 12),
                    const Center(child: ConnectOrb(size: 92)),
                    const SizedBox(height: 12),
                    const OutboundModeSwitch(height: 40),
                    if (system.isDesktop) ...[
                      const SizedBox(height: 8),
                      const DesktopRouteSwitch(),
                    ],
                    const SizedBox(height: 18),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                sliver: SliverList.list(
                  children: [
                    for (final (index, item) in items.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _SidebarItem(
                          item: item,
                          selected: index == currentIndex,
                          onTap: () => onSelected(item.label),
                        ),
                      ),
                  ],
                ),
              ),
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: _SidebarFooter(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends ConsumerWidget {
  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavigationItem item;
  final bool selected;
  final VoidCallback onTap;

  String? _subtitleOf(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    switch (item.label) {
      case PageLabel.proxies:
        final group = leadingGroupOf(ref);
        if (group == null) {
          return null;
        }
        return ref.watch(selectedProxyNameProvider(group.name));
      case PageLabel.profiles:
        return ref.watch(
          currentProfileProvider.select((state) => state?.realLabel),
        );
      case PageLabel.po0:
        final setting = ref.watch(po0FirewallSettingProvider);
        return po0OverviewOf(
          appLocalizations,
          enabled: setting.enable,
          hasTokens: po0TokensOf(setting.tokenEntries).isNotEmpty,
          state: ref.watch(po0FirewallProvider),
        ).title;
      case PageLabel.ggy:
        final setting = ref.watch(po0FirewallSettingProvider);
        return po0OverviewOf(
          appLocalizations,
          enabled: setting.ggyEnable,
          hasTokens: ggyLinksOf(setting.ggyEntries).isNotEmpty,
          state: ref.watch(ggyFirewallProvider),
          noTokensTitle: appLocalizations.ggyStatusNoLink,
        ).title;
      case PageLabel.activity:
        return appLocalizations.activityDesc;
      default:
        return item.label.description;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle = _subtitleOf(context, ref);
    final colorScheme = context.colorScheme;
    final glass = context.glass;
    return GlassButton(
      plain: !selected,
      color: glass.selected,
      rimColor: Colors.transparent,
      elevated: false,
      borderRadius: AppRadius.small,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            _iconOf(item),
            size: 20,
            color: selected ? colorScheme.primary : glass.secondaryLabel,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleSmall,
                ),
                if (subtitle != null && subtitle.isNotEmpty)
                  EmojiText(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
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

class _SidebarFooter extends ConsumerWidget {
  const _SidebarFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final traffic = ref.watch(trafficsProvider).list.lastOrNull;
    final ipInfo = ref.watch(networkDetectionProvider).ipInfo;
    final style = context.textTheme.bodySmall?.copyWith(
      color: glass.secondaryLabel,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget line(IconData? icon, String text, {String? fontFamily}) => Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: glass.secondaryLabel),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style?.copyWith(fontFamily: fontFamily),
          ),
        ),
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, color: glass.separator),
        const SizedBox(height: 10),
        line(
          null,
          '↑ ${(traffic?.up ?? 0).traffic.show}/s   '
          '↓ ${(traffic?.down ?? 0).traffic.show}/s',
        ),
        if (ipInfo != null) ...[
          const SizedBox(height: 6),
          line(
            Icons.public_rounded,
            '${ipInfo.countryCode} · ${ipInfo.ip}',
            fontFamily: FontFamily.jetBrainsMono.value,
          ),
        ],
      ],
    );
  }
}
