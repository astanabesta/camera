import 'dart:async';

import 'package:flutter/material.dart';

import 'design/tokens.dart';
import 'model/camera_ui_controller.dart';
import 'screens/camera_screen.dart';
import 'screens/media_screen.dart';
import 'screens/settings_screen.dart';

class ZirconCinemaApp extends StatefulWidget {
  const ZirconCinemaApp({super.key, this.controller});

  final CameraUiController? controller;

  @override
  State<ZirconCinemaApp> createState() => _ZirconCinemaAppState();
}

class _ZirconCinemaAppState extends State<ZirconCinemaApp>
    with WidgetsBindingObserver {
  late final CameraUiController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? CameraUiController();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_controller.initializeCamera());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_controller.resumeCamera());
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        unawaited(_controller.pauseCamera());
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zircon Cinema',
      debugShowCheckedModeBanner: false,
      theme: buildZirconTheme(),
      home: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return switch (_controller.section) {
            AppSection.camera => CameraScreen(controller: _controller),
            AppSection.media => MediaScreen(controller: _controller),
            AppSection.settings => SettingsScreen(controller: _controller),
          };
        },
      ),
    );
  }
}
