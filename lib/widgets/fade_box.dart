import 'package:animations/animations.dart';
import 'package:fl_clash/common/common.dart';
import 'package:material_ui/material_ui.dart';

class FadeBox extends StatelessWidget {
  final Widget child;
  final AlignmentGeometry? alignment;
  final StackFit fit;

  const FadeBox({
    super.key,
    required this.child,
    this.alignment,
    this.fit = StackFit.loose,
  });

  @override
  Widget build(BuildContext context) {
    final realAlignment = alignment ?? Alignment.center;
    return AnimatedSwitcher(
      switchInCurve: Easing.standard,
      switchOutCurve: Easing.standard,
      layoutBuilder: (currentChild, previousChildren) => Align(
        alignment: realAlignment,
        child: Stack(
          alignment: realAlignment,
          fit: fit,
          children: <Widget>[...previousChildren, ?currentChild],
        ),
      ),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      duration: context.motionDuration(Durations.short4),
      child: child,
    );
  }
}

class FadeThroughBox extends StatelessWidget {
  final Widget child;
  final AlignmentGeometry? alignment;
  final EdgeInsets? margin;

  const FadeThroughBox({
    super.key,
    required this.child,
    this.alignment,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final realAlignment = alignment ?? Alignment.centerLeft;
    return PageTransitionSwitcher(
      duration: context.motionDuration(Durations.medium2),
      transitionBuilder: (child, animation, secondaryAnimation) {
        return FadeThroughTransition(
          animation: animation,
          fillColor: Colors.transparent,
          secondaryAnimation: secondaryAnimation,
          child: child,
        );
      },
      layoutBuilder: (entries) => Container(
        alignment: realAlignment,
        margin: margin,
        child: Stack(alignment: realAlignment, children: entries),
      ),
      child: child,
    );
  }
}

class FadeScaleBox extends StatelessWidget {
  final Widget child;
  final AlignmentGeometry? alignment;

  const FadeScaleBox({super.key, required this.child, this.alignment});

  @override
  Widget build(BuildContext context) {
    final realAlignment = alignment ?? Alignment.center;
    return AnimatedSwitcher(
      duration: context.motionDuration(Durations.short3),
      reverseDuration: context.motionDuration(Durations.short1),
      transitionBuilder: (child, animation) =>
          FadeScaleEnterTransition(animation: animation, child: child),
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: realAlignment,
        children: <Widget>[...previousChildren, ?currentChild],
      ),
      child: child,
    );
  }
}

class FadeScaleEnterBox extends StatefulWidget {
  final Widget child;

  const FadeScaleEnterBox({super.key, required this.child});

  @override
  State<FadeScaleEnterBox> createState() => _FadeScaleEnterBoxState();
}

class _FadeScaleEnterBoxState extends State<FadeScaleEnterBox>
    with SingleTickerProviderStateMixin, _EnterAnimation {
  @override
  late final AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Durations.short3);
    _animation = _controller.view;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.disableAnimations) {
      return widget.child;
    }
    return FadeScaleEnterTransition(animation: _animation, child: widget.child);
  }
}

mixin _EnterAnimation<T extends StatefulWidget> on State<T> {
  AnimationController get _controller;
  bool _entered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entered) {
      return;
    }
    _entered = true;
    if (context.disableAnimations) {
      _controller.value = _controller.upperBound;
    } else {
      _controller.forward();
    }
  }
}

const _defaultSlideDistance = 24.0;

class FadeSlideEnterBox extends StatefulWidget {
  final Duration delay;
  final double distance;
  final Axis axis;
  final Widget child;

  const FadeSlideEnterBox({
    super.key,
    this.delay = Duration.zero,
    this.distance = _defaultSlideDistance,
    this.axis = Axis.horizontal,
    required this.child,
  });

  @override
  State<FadeSlideEnterBox> createState() => _FadeSlideEnterBoxState();
}

class _FadeSlideEnterBoxState extends State<FadeSlideEnterBox>
    with SingleTickerProviderStateMixin, _EnterAnimation {
  @override
  late final AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    final total = Durations.medium2 + widget.delay;
    _controller = AnimationController(vsync: this, duration: total);
    final start = widget.delay.inMicroseconds / total.inMicroseconds;
    _animation = start == 0
        ? _controller.view
        : _controller.drive(CurveTween(curve: Interval(start, 1)));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.disableAnimations) {
      return widget.child;
    }
    return FadeSlideEnterTransition(
      animation: _animation,
      distance: widget.distance,
      axis: widget.axis,
      child: widget.child,
    );
  }
}

class FadeSlideEnterTransition extends StatelessWidget {
  const FadeSlideEnterTransition({
    super.key,
    required this.animation,
    this.distance = _defaultSlideDistance,
    this.axis = Axis.horizontal,
    this.child,
  });

  final Animation<double> animation;
  final double distance;
  final Axis axis;
  final Widget? child;

  static final Animatable<double> _fadeInTransition = CurveTween(
    curve: const Interval(0.0, 0.25),
  );
  static final Animatable<double> _slideInCurve = CurveTween(
    curve: Easing.emphasizedDecelerate,
  );

  @override
  Widget build(BuildContext context) {
    final begin = axis == Axis.horizontal
        ? Offset(-distance, 0)
        : Offset(0, distance);
    final slide = Tween<Offset>(
      begin: begin,
      end: Offset.zero,
    ).chain(_slideInCurve).animate(animation);
    return FadeTransition(
      opacity: _fadeInTransition.animate(animation),
      child: AnimatedBuilder(
        animation: slide,
        builder: (_, child) =>
            Transform.translate(offset: slide.value, child: child),
        child: child,
      ),
    );
  }
}

/// Material 3's fade: in over 30% while growing from 80%, out as a plain fade.
class FadeScaleEnterTransition extends StatelessWidget {
  const FadeScaleEnterTransition({
    super.key,
    required this.animation,
    this.child,
  });

  final Animation<double> animation;
  final Widget? child;

  static final Animatable<double> _fadeIn = CurveTween(
    curve: const Interval(0.0, 0.3),
  );
  static final Animatable<double> _scaleIn = Tween<double>(
    begin: 0.8,
    end: 1.0,
  ).chain(CurveTween(curve: Easing.emphasizedDecelerate));
  static final Animatable<double> _fadeOut = Tween<double>(begin: 1, end: 0);

  @override
  Widget build(BuildContext context) {
    return DualTransitionBuilder(
      animation: animation,
      forwardBuilder: (_, animation, child) => FadeTransition(
        opacity: _fadeIn.animate(animation),
        child: ScaleTransition(
          scale: _scaleIn.animate(animation),
          child: child,
        ),
      ),
      reverseBuilder: (_, animation, child) =>
          FadeTransition(opacity: _fadeOut.animate(animation), child: child),
      child: child,
    );
  }
}
