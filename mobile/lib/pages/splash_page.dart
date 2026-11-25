import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/auth_middleware.dart';
import '../app/routes.dart';
import '../utils/app_theme.dart';
import '../utils/notification_router.dart';
import 'splash/splash_destination.dart';

typedef SplashNavigate = void Function(String route);

/// Leaves the splash for [route]; on the home page, opens the notification that launched the app
/// (cold start) on top of it, so back returns to home.
///
/// The page is pushed over the splash and the splash is removed once the page's fade-in is over:
/// replacing it (offNamed/offAllNamed) takes the splash away at once, and the page would fade in
/// over a blank background instead of over the splash's red top.
void splashNavigate(String route) {
  final Route<dynamic>? splash = Get.rawRoute;
  Get.toNamed(route);
  Future<void>.delayed(const Duration(milliseconds: 400), () {
    if (splash != null && splash.isActive) Get.removeRoute(splash);
  });
  if (route == AppRoutes.home) {
    WidgetsBinding.instance.addPostFrameCallback((_) => NotificationNavigator.openPending());
  }
}

/// Where the white sheet of [route] starts on its first frame (from the top of the screen), so the
/// splash exit lands on it and the red above reads as the page's header.
/// Measured on the pages' first frames: Login's one-line header; Beranda's header with the
/// schedule block still loading (students and lecturers), or without it (admins).
double splashSheetTop(BuildContext context, String route) {
  final double top = MediaQuery.paddingOf(context).top;
  if (route != AppRoutes.home) return top + 54;
  return top + (AuthMiddleware.cachedRole == 'ADMIN' ? 59 : 282);
}

/// Sizes shared with the native launch splash (tool/brand_assets.py): same circle, same symbol,
/// same place (centre of the screen), so the handoff from Android's splash is invisible.
const double _circle = 160;
const double _symbol = 96;
const Duration _introDuration = Duration(milliseconds: 700);
const Duration _exitDuration = Duration(milliseconds: 450);

/// The red splash: a short intro while the session is checked, then a white sheet rises to where
/// the destination's sheet starts and [navigate] is called once. No fixed delay.
class SplashPage extends StatefulWidget {
  final Future<String> Function() resolve;
  final SplashNavigate navigate;

  const SplashPage({
    super.key,
    this.resolve = resolveSplashDestination,
    this.navigate = splashNavigate,
  });

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: _introDuration);
  late final AnimationController _exit = AnimationController(vsync: this, duration: _exitDuration);
  bool _started = false;
  bool _reducedMotion = false;
  bool _introDone = false;
  bool _leaving = false;
  bool _navigated = false;
  String? _route;

  @override
  void initState() {
    super.initState();
    widget.resolve().then((String route) {
      if (!mounted) return;
      setState(() => _route = route);
      _maybeLeave();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) {
      _intro.value = 1;
      _introDone = true;
    } else {
      // Starts once the first frame is out: that frame replaces Android's launch splash, which
      // looks the same, so the movement begins where the native splash ends.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _intro.forward().then((_) {
          if (!mounted) return;
          setState(() => _introDone = true);
          _maybeLeave();
        });
      });
    }
  }

  void _maybeLeave() {
    if (_leaving || !_introDone || _route == null) return;
    if (_reducedMotion) {
      _go();
      return;
    }
    setState(() => _leaving = true);
    _exit.forward().then((_) => _go());
  }

  void _go() {
    if (!mounted || _navigated) return;
    _navigated = true;
    widget.navigate(_route!);
  }

  @override
  void dispose() {
    _intro.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.sizeOf(context).height;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[_intro, _exit]),
        builder: (BuildContext context, Widget? _) {
          final double t = Curves.easeOutCubic.transform(_intro.value);
          final double out = Curves.easeInOutCubic.transform(_exit.value);
          final double content = 1 - out;
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Opacity(
                opacity: content,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Center(
                      child: Transform.translate(
                        offset: Offset(0, -56 * t),
                        child: Transform.scale(scale: 1 - 0.2 * t, child: const _Mark()),
                      ),
                    ),
                    Center(
                      child: Transform.translate(
                        offset: Offset(0, 40 + 16 * (1 - t)),
                        child: Opacity(
                          opacity: t,
                          child: const Text(
                            'MyTelU',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_introDone && _route == null)
                      Center(
                        child: Transform.translate(
                          offset: const Offset(0, 100),
                          child: const SizedBox(
                            key: Key('splash-progress'),
                            width: 120,
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              color: Colors.white,
                              backgroundColor: Colors.white24,
                              borderRadius: BorderRadius.all(Radius.circular(2)),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: bottomInset + 32,
                      child: Opacity(
                        opacity: t,
                        child: const Text(
                          'Telkom University',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_leaving)
                Positioned(
                  key: const Key('splash-sheet'),
                  left: 0,
                  right: 0,
                  bottom: 0,
                  top: lerpDouble(height, splashSheetTop(context, _route!), out),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The Telkom University symbol in a white circle, as on the native splash.
class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _circle,
      height: _circle,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: Image.asset('assets/images/telyu_symbol.png', height: _symbol),
    );
  }
}
