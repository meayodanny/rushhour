import 'package:flutter/material.dart';

/// Both screens paint the same city from a synchronized absolute animation
/// clock. Their route animations drive identical camera parameters, making the
/// hand-off visually continuous instead of a platform page transition.
Route<T> buildSharedMapRoute<T>({required Widget page}) => PageRouteBuilder<T>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 920),
      reverseTransitionDuration: const Duration(milliseconds: 720),
      pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) => page,
      transitionsBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        Widget child,
      ) => child,
    );

/// Camera-flight route used when moving deeper into the map. It intentionally
/// avoids every platform transition and combines zoom, vertical camera travel,
/// clipping and a delayed reveal of the destination UI.
Route<T> buildCameraRoute<T>({required Widget page, RouteSettings? settings}) => PageRouteBuilder<T>(
      settings: settings,
      opaque: false,
      transitionDuration: const Duration(milliseconds: 920),
      reverseTransitionDuration: const Duration(milliseconds: 720),
      pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) => page,
      transitionsBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        Widget child,
      ) {
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (BuildContext context, Widget? child) {
            final camera = Curves.easeInOutCubic.transform(animation.value);
            final reveal = Curves.easeOutCubic.transform(((animation.value - .18) / .82).clamp(0.0, 1.0));
            return ClipRect(
              child: Opacity(
                opacity: reveal,
                child: Transform.translate(
                  offset: Offset(0, 48 * (1 - camera)),
                  child: Transform.scale(
                    scale: 1.16 - .16 * camera,
                    child: child,
                  ),
                ),
              ),
            );
          },
        );
      },
    );

/// Settings feel like a physical sheet in the game's flat geometry, but are
/// still a normal route with a completely authored transition.
Route<T> buildPanelRoute<T>({required Widget page}) => PageRouteBuilder<T>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 620),
      reverseTransitionDuration: const Duration(milliseconds: 480),
      pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) => page,
      transitionsBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        Widget child,
      ) {
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (BuildContext context, Widget? child) {
            final t = Curves.easeOutQuart.transform(animation.value);
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, 90 * (1 - t)),
                child: Transform.scale(
                  alignment: Alignment.bottomCenter,
                  scale: .94 + .06 * t,
                  child: child,
                ),
              ),
            );
          },
        );
      },
    );

Route<T> buildReturnToMenuRoute<T>({required Widget page}) => PageRouteBuilder<T>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 980),
      pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) => page,
      transitionsBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        Widget child,
      ) {
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (BuildContext context, Widget? child) {
            final t = Curves.easeInOutCubic.transform(animation.value);
            return ClipRect(
              child: Opacity(
                opacity: ((t - .08) / .92).clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, -36 * (1 - t)),
                  child: Transform.scale(scale: .84 + .16 * t, child: child),
                ),
              ),
            );
          },
        );
      },
    );
