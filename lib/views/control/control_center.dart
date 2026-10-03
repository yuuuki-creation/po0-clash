import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import 'connect_orb.dart';
import 'core_status.dart';
import 'tiles.dart';

/// The home space on phones and narrow windows. Wide windows show the same
/// controls in the sidebar instead, so this page is not a destination there.
class ControlCenterView extends StatelessWidget {
  const ControlCenterView({super.key});

  static const _wideBreakpoint = 640.0;

  @override
  Widget build(BuildContext context) {
    final bottom = BottomInsetScope.of(context);
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _wideBreakpoint;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 880),
                  child: wide ? const _WideLayout() : const _NarrowLayout(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final markSize = dense ? 30.0 : 36.0;
    return Row(
      children: [
        ClipRSuperellipse(
          borderRadius: AppRadius.all(markSize * 0.28),
          child: Image.asset(
            'assets/images/icon.png',
            width: markSize,
            height: markSize,
            filterQuality: FilterQuality.medium,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            appName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                (dense
                        ? context.textTheme.titleMedium
                        : context.textTheme.headlineSmall)
                    ?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
          ),
        ),
        if (coreLib == null) const CoreStatusButton(),
      ],
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout();

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BrandHeader(),
        SizedBox(height: 16),
        Center(child: ConnectOrb(size: 120)),
        SizedBox(height: 20),
        OutboundModeSwitch(),
        gap,
        QuickToggles(),
        gap,
        CurrentNodeCard(),
        gap,
        _Pair(first: WhitelistStatusCard(), second: CurrentProfileCard()),
        gap,
        TrafficCard(),
        gap,
        _Pair(first: NetworkCard(), second: MemoryInfo(), minHeight: 0),
      ],
    );
  }
}

class _WideLayout extends StatelessWidget {
  const _WideLayout();

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BrandHeader(),
        SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 260,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: ConnectOrb(size: 132)),
                  SizedBox(height: 16),
                  OutboundModeSwitch(),
                ],
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  QuickToggles(),
                  gap,
                  CurrentNodeCard(),
                  gap,
                  _Pair(
                    first: WhitelistStatusCard(),
                    second: CurrentProfileCard(),
                  ),
                  gap,
                  TrafficCard(),
                  gap,
                  _Pair(
                    first: NetworkCard(),
                    second: MemoryInfo(),
                    minHeight: 0,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Pair extends StatelessWidget {
  const _Pair({
    required this.first,
    required this.second,
    this.minHeight = _PairSlot.cardHeight,
  });

  final Widget first;
  final Widget second;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _PairSlot(minHeight: minHeight, child: first),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PairSlot(minHeight: minHeight, child: second),
        ),
      ],
    );
  }
}

class _PairSlot extends StatelessWidget {
  const _PairSlot({required this.minHeight, required this.child});

  static const cardHeight = 118.0;

  final double minHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: child,
    );
  }
}
