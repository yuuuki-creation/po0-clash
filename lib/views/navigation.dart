import 'package:fl_clash/common/app_ports.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/views.dart';
import 'package:material_ui/material_ui.dart';

class Navigation implements NavigationPort {
  static Navigation? _instance;

  @override
  List<NavigationItem> getItems({
    bool openLogs = false,
    bool hasProxies = false,
  }) {
    return [
      NavigationItem(
        keep: false,
        icon: const Icon(Icons.home_rounded),
        label: PageLabel.dashboard,
        builder: (_) =>
            const ControlCenterView(key: GlobalObjectKey(PageLabel.dashboard)),
        modes: const [NavigationItemMode.mobile, NavigationItemMode.laptop],
      ),
      NavigationItem(
        icon: const Icon(Icons.hub_rounded),
        label: PageLabel.proxies,
        builder: (_) =>
            const ProxiesView(key: GlobalObjectKey(PageLabel.proxies)),
        modes: hasProxies ? NavigationItemMode.values : const [],
      ),
      NavigationItem(
        icon: const Icon(Icons.layers_rounded),
        label: PageLabel.profiles,
        builder: (_) =>
            const ProfilesView(key: GlobalObjectKey(PageLabel.profiles)),
      ),
      NavigationItem(
        icon: const Icon(Icons.shield_rounded),
        label: PageLabel.whitelist,
        builder: (_) =>
            const WhitelistView(key: GlobalObjectKey(PageLabel.whitelist)),
      ),
      NavigationItem(
        icon: const Icon(Icons.insights_rounded),
        label: PageLabel.activity,
        builder: (_) =>
            const ActivityView(key: GlobalObjectKey(PageLabel.activity)),
        modes: const [NavigationItemMode.laptop, NavigationItemMode.desktop],
      ),
      NavigationItem(
        icon: const Icon(Icons.tune_rounded),
        label: PageLabel.tools,
        builder: (_) => const ToolsView(key: GlobalObjectKey(PageLabel.tools)),
      ),
    ];
  }

  Navigation._internal();

  factory Navigation() {
    _instance ??= Navigation._internal();
    return _instance!;
  }
}

final navigation = Navigation();
