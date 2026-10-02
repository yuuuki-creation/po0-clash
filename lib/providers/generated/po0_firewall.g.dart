// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../po0_firewall.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(po0FirewallClient)
final po0FirewallClientProvider = Po0FirewallClientProvider._();

final class Po0FirewallClientProvider
    extends
        $FunctionalProvider<
          Po0FirewallClient,
          Po0FirewallClient,
          Po0FirewallClient
        >
    with $Provider<Po0FirewallClient> {
  Po0FirewallClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'po0FirewallClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$po0FirewallClientHash();

  @$internal
  @override
  $ProviderElement<Po0FirewallClient> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Po0FirewallClient create(Ref ref) {
    return po0FirewallClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Po0FirewallClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Po0FirewallClient>(value),
    );
  }
}

String _$po0FirewallClientHash() => r'9d993036c0418eccffeadca8dee839e43b590380';

/// Keeps the current exit whitelisted for as long as the app runs, whether or
/// not the proxy is started: a read-only query each interval, and an add only
/// when the exit is missing. Android pauses while the screen is off.

@ProviderFor(Po0Firewall)
final po0FirewallProvider = Po0FirewallProvider._();

/// Keeps the current exit whitelisted for as long as the app runs, whether or
/// not the proxy is started: a read-only query each interval, and an add only
/// when the exit is missing. Android pauses while the screen is off.
final class Po0FirewallProvider
    extends $NotifierProvider<Po0Firewall, Po0FirewallState> {
  /// Keeps the current exit whitelisted for as long as the app runs, whether or
  /// not the proxy is started: a read-only query each interval, and an add only
  /// when the exit is missing. Android pauses while the screen is off.
  Po0FirewallProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'po0FirewallProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$po0FirewallHash();

  @$internal
  @override
  Po0Firewall create() => Po0Firewall();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Po0FirewallState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Po0FirewallState>(value),
    );
  }
}

String _$po0FirewallHash() => r'0807bad801045e823e25c1168deaa192fb7e9021';

/// Keeps the current exit whitelisted for as long as the app runs, whether or
/// not the proxy is started: a read-only query each interval, and an add only
/// when the exit is missing. Android pauses while the screen is off.

abstract class _$Po0Firewall extends $Notifier<Po0FirewallState> {
  Po0FirewallState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Po0FirewallState, Po0FirewallState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Po0FirewallState, Po0FirewallState>,
              Po0FirewallState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
