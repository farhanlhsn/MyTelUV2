import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

/// Background of a page with a red header over a white sheet: red at the top, white at the
/// bottom. Wrapped around a SafeArea, the bottom inset (gesture bar) is white like the sheet above
/// it instead of a red strip, and the red still shows behind the rounded corners of the sheet.
class RedHeaderBackground extends StatelessWidget {
  final Widget child;

  const RedHeaderBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            AppColors.primary,
            AppColors.primary,
            AppColors.surface,
            AppColors.surface,
          ],
          stops: <double>[0, 0.5, 0.5, 1],
        ),
      ),
      child: child,
    );
  }
}
