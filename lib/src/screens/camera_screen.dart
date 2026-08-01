import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/tokens.dart';
import '../model/camera_ui_controller.dart';
import '../widgets/preview_overlays.dart';
import '../widgets/side_rail.dart';
import '../widgets/vertical_control_panel.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({required this.controller, super.key});
  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.cleanFeed) {
      return Scaffold(
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: controller.restoreControls,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _Preview(controller: controller),
              const Positioned(right: 12, bottom: 10, child: _CleanHint()),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxHeight > constraints.maxWidth) {
            return _PortraitCamera(controller: controller);
          }
          return Row(
            children: <Widget>[
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _Preview(controller: controller),
                    const _Shading(),
                    PreviewOverlays(controller: controller),
                    Positioned.fill(
                      child: _TapFocusLayer(controller: controller),
                    ),
                    _LevelOverlay(controller: controller),
                    if (controller.textureId == null &&
                        !controller.allowSimulation)
                      Center(child: _CameraStatus(controller: controller)),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _TopHud(controller: controller),
                    ),
                    Positioned(
                      top: 58,
                      left: 7,
                      child: _RuntimeBadge(controller: controller),
                    ),
                    // Floating left tools matching the new design
                    Positioned(
                      top: 100,
                      left: 10,
                      child: _LeftToolRail(controller: controller),
                    ),
                    Positioned(
                      left: 0,
                      right: controller.activeControl == null ? 0 : 250,
                      bottom: 0,
                      child: _Dashboard(controller: controller),
                    ),
                    // Quick Tools (3-dot menu) overlay
                    if (controller.showQuickTools)
                      Positioned(
                        right: 86,
                        bottom: 10,
                        child: _QuickToolsOverlay(controller: controller),
                      ),
                    Positioned(
                      top: 52,
                      right: 76,
                      bottom: 70,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: controller.activeControl == null
                            ? const SizedBox.shrink(
                                key: ValueKey<String>('closed'),
                              )
                            : VerticalControlPanel(
                                key: ValueKey<CameraControl?>(
                                  controller.activeControl,
                                ),
                                controller: controller,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              _RightControlPanel(controller: controller),
            ],
          );
        },
      ),
    );
  }

  static void _notice(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  static Future<void> _showMonitorTools(
    BuildContext context,
    CameraUiController controller,
  ) {
    const List<(MonitorTool, String, IconData)> tools =
        <(MonitorTool, String, IconData)>[
          (MonitorTool.frameGuides, 'GUIDES', Icons.crop_free_rounded),
          (MonitorTool.grid, 'GRID', Icons.grid_3x3_rounded),
          (MonitorTool.zebra, 'ZEBRA UI', Icons.texture_rounded),
          (MonitorTool.falseColor, 'FALSE UI', Icons.gradient_rounded),
          (MonitorTool.peaking, 'PEAK UI', Icons.center_focus_strong_rounded),
          (MonitorTool.waveform, 'WAVE UI', Icons.monitor_heart_outlined),
          (MonitorTool.histogram, 'HIST UI', Icons.area_chart_outlined),
          (MonitorTool.cleanFeed, 'CLEAN', Icons.fullscreen_rounded),
        ];
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: ZirconColors.panelStrong,
        title: const Text(
          'MONITOR TOOLS',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => SizedBox(
            width: 430,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tools
                  .map(((MonitorTool, String, IconData) tool) {
                    final bool selected = controller.isToolEnabled(tool.$1);
                    return SizedBox(
                      width: 100,
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          controller.toggleMonitorTool(tool.$1);
                          setState(() {});
                          if (tool.$1 == MonitorTool.cleanFeed)
                            Navigator.of(dialogContext).pop();
                        },
                        icon: Icon(tool.$3, size: 14),
                        label: Text(tool.$2),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: selected
                              ? ZirconColors.accent
                              : ZirconColors.textMuted,
                          side: BorderSide(
                            color: selected
                                ? ZirconColors.accent
                                : ZirconColors.stroke,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }
}

class _TapFocusLayer extends StatefulWidget {
  const _TapFocusLayer({required this.controller});
  final CameraUiController controller;

  @override
  State<_TapFocusLayer> createState() => _TapFocusLayerState();
}

class _TapFocusLayerState extends State<_TapFocusLayer> {
  double _gestureStartZoom = 1.0;

  CameraUiController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool rotated = controller.previewQuarterTurns.isOdd;
        final double sourceWidth = rotated
            ? controller.previewHeight.toDouble()
            : controller.previewWidth.toDouble();
        final double sourceHeight = rotated
            ? controller.previewWidth.toDouble()
            : controller.previewHeight.toDouble();
        final double scale = math.max(
          constraints.maxWidth / sourceWidth,
          constraints.maxHeight / sourceHeight,
        );
        final double renderedWidth = sourceWidth * scale;
        final double renderedHeight = sourceHeight * scale;
        final double cropX = (renderedWidth - constraints.maxWidth) / 2;
        final double cropY = (renderedHeight - constraints.maxHeight) / 2;

        void apply(Offset local, {required bool lock}) {
          if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) return;
          controller.tapToFocus(
            (local.dx + cropX) / renderedWidth,
            (local.dy + cropY) / renderedHeight,
            lock: lock,
          );
        }

        final Offset? point = controller.focusPoint;
        final Offset? displayedPoint = point == null
            ? null
            : Offset(
                point.dx * renderedWidth - cropX,
                point.dy * renderedHeight - cropY,
              );
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (TapUpDetails details) =>
              apply(details.localPosition, lock: false),
          onLongPressStart: (LongPressStartDetails details) =>
              apply(details.localPosition, lock: true),
          onScaleStart: (_) {
            _gestureStartZoom = controller.zoomRatio;
          },
          onScaleUpdate: (ScaleUpdateDetails details) {
            if (details.pointerCount < 2) return;
            controller.setZoomRatio(
              _gestureStartZoom * details.scale,
              rampDurationMs: 0,
            );
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              if (displayedPoint != null &&
                  controller.focusUiState != FocusUiState.hidden)
                Positioned(
                  left: displayedPoint.dx - 27,
                  top: displayedPoint.dy - 27,
                  child: _FocusReticle(
                    state: controller.focusUiState,
                    locked: controller.aeAfLocked,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FocusReticle extends StatelessWidget {
  const _FocusReticle({required this.state, required this.locked});
  final FocusUiState state;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (state) {
      FocusUiState.scanning => ZirconColors.warning,
      FocusUiState.focused => ZirconColors.good,
      FocusUiState.failed => ZirconColors.record,
      FocusUiState.locked => ZirconColors.accent,
      FocusUiState.hidden => Colors.transparent,
    };
    return IgnorePointer(
      child: SizedBox(
        width: 74,
        height: 74,
        child: Column(
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: state == FocusUiState.scanning ? 54 : 46,
              height: state == FocusUiState.scanning ? 54 : 46,
              decoration: BoxDecoration(
                border: Border.all(color: color, width: 2),
                borderRadius: BorderRadius.circular(5),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x99000000), blurRadius: 5),
                ],
              ),
              child: Center(
                child: Container(width: 6, height: 6, color: color),
              ),
            ),
            if (locked) ...<Widget>[
              const SizedBox(height: 3),
              Text(
                'AE/AF LOCK',
                style: TextStyle(
                  color: color,
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  shadows: const <Shadow>[
                    Shadow(color: Colors.black, blurRadius: 3),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LevelOverlay extends StatelessWidget {
  const _LevelOverlay({required this.controller});
  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    final double? roll = controller.levelRollDegrees;
    if (roll == null) return const SizedBox.shrink();
    final Color color = roll.abs() <= 1 ? ZirconColors.good : ZirconColors.text;
    return IgnorePointer(
      child: Center(
        child: SizedBox(
          width: 170,
          height: 46,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Transform.rotate(
                angle: -roll * math.pi / 180,
                child: Row(
                  children: <Widget>[
                    Expanded(child: Container(height: 1.5, color: color)),
                    const SizedBox(width: 28),
                    Expanded(child: Container(height: 1.5, color: color)),
                  ],
                ),
              ),
              Container(
                width: 18,
                height: 8,
                decoration: BoxDecoration(
                  border: Border.all(color: color, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortraitCamera extends StatelessWidget {
  const _PortraitCamera({required this.controller});
  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _Preview(controller: controller),
        const _Shading(),
        PreviewOverlays(controller: controller),
        Positioned.fill(child: _TapFocusLayer(controller: controller)),
        _LevelOverlay(controller: controller),
        if (controller.textureId == null && !controller.allowSimulation)
          Center(child: _CameraStatus(controller: controller)),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _PortraitTop(controller: controller),
        ),
        if (controller.activeControl != null)
          Positioned(
            top: 116,
            right: 0,
            bottom: 132,
            child: VerticalControlPanel(controller: controller),
          ),
        if (controller.activeControl == null)
          Positioned(
            right: 8,
            top: 148,
            child: _PortraitTools(controller: controller),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _PortraitBottom(controller: controller),
        ),
      ],
    );
  }
}

class _TelemetryBadge extends StatelessWidget {
  const _TelemetryBadge({required this.controller});
  final CameraUiController controller;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xC90B0E13),
      border: Border.all(color: ZirconColors.stroke),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(
          Icons.storage_rounded,
          size: 11,
          color: ZirconColors.textMuted,
        ),
        const SizedBox(width: 3),
        Text(
          controller.storageAvailableLabel,
          style: const TextStyle(fontSize: 7),
        ),
        const SizedBox(width: 8),
        Icon(
          controller.batteryCharging
              ? Icons.battery_charging_full_rounded
              : Icons.battery_std_rounded,
          size: 12,
          color: ZirconColors.textMuted,
        ),
        const SizedBox(width: 2),
        Text(
          controller.batteryPercent == null
              ? '—'
              : '${controller.batteryPercent}%',
          style: const TextStyle(fontSize: 7),
        ),
      ],
    ),
  );
}

class _PortraitTop extends StatelessWidget {
  const _PortraitTop({required this.controller});
  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    final bool automatic = controller.operationMode == CameraOperationMode.auto;
    final List<(CameraControl, String)> controls = automatic
        ? <(CameraControl, String)>[
            (CameraControl.lens, 'LENS'),
            (CameraControl.fps, 'FPS'),
          ]
        : <(CameraControl, String)>[
            (CameraControl.lens, 'LENS'),
            (CameraControl.fps, 'FPS'),
            (CameraControl.shutter, 'SHUTTER'),
            (CameraControl.iso, 'ISO'),
            (CameraControl.whiteBalance, 'WB'),
            (CameraControl.tint, 'TINT'),
            (CameraControl.focus, 'FOCUS'),
            (CameraControl.exposureCompensation, 'EV'),
          ];
    return SafeArea(
      bottom: false,
      child: Container(
        height: 116,
        color: const Color(0xE805070A),
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 58,
              child: Row(
                children: <Widget>[
                  const SizedBox(width: 8),
                  Expanded(child: _Timecode(controller: controller)),
                  const SizedBox(width: 5),
                  _OrientationButtons(controller: controller, isPortrait: true),
                  const SizedBox(width: 5),
                  _MasterModeButton(controller: controller),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            const Divider(height: 1, color: ZirconColors.stroke),
            SizedBox(
              height: 57,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                scrollDirection: Axis.horizontal,
                itemCount: controls.length + (automatic ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(width: 5),
                itemBuilder: (BuildContext context, int index) {
                  if (automatic && index == controls.length) {
                    return _PortraitParameter(
                      label: 'FORMAT',
                      value: controller.recordingMode.hudLabel,
                      selected: false,
                      enabled: true,
                      onTap: () {},
                    );
                  }
                  final (CameraControl control, String label) = controls[index];
                  return _PortraitParameter(
                    label: label,
                    value: controller.valueFor(control),
                    selected: controller.activeControl == control,
                    enabled: controller.isControlAvailable(control),
                    onTap: () => controller.selectControl(control),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrientationButtons extends StatelessWidget {
  const _OrientationButtons({
    required this.controller,
    required this.isPortrait,
  });
  final CameraUiController controller;
  final bool isPortrait;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, bool selected, VoidCallback onTap) => SizedBox(
      width: 32,
      height: 30,
      child: Material(
        color: selected
            ? ZirconColors.blue.withValues(alpha: .2)
            : const Color(0xD90B0E13),
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          child: Icon(
            icon,
            size: 17,
            color: selected ? ZirconColors.blue : ZirconColors.textMuted,
          ),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        button(
          Icons.stay_current_portrait_rounded,
          isPortrait,
          () => controller.setCaptureOrientation(CaptureOrientation.portrait),
        ),
        const SizedBox(width: 3),
        button(
          Icons.stay_current_landscape_rounded,
          !isPortrait,
          () => controller.setCaptureOrientation(CaptureOrientation.landscape),
        ),
      ],
    );
  }
}

class _MasterModeButton extends StatelessWidget {
  const _MasterModeButton({required this.controller});
  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    final String label = switch (controller.operationMode) {
      CameraOperationMode.auto => 'AUTO',
      CameraOperationMode.manual => 'MANUAL',
      CameraOperationMode.mixed => 'MIXED',
    };
    return OutlinedButton(
      onPressed: () => controller.setMasterAuto(
        controller.operationMode != CameraOperationMode.auto,
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 34),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor: controller.operationMode == CameraOperationMode.mixed
            ? ZirconColors.warning
            : ZirconColors.accent,
        side: BorderSide(
          color: controller.operationMode == CameraOperationMode.mixed
              ? ZirconColors.warning
              : ZirconColors.accent,
        ),
        textStyle: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900),
      ),
      child: Text(label),
    );
  }
}

class _PortraitParameter extends StatelessWidget {
  const _PortraitParameter({
    required this.label,
    required this.value,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });
  final String label;
  final String value;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      child: Material(
        color: selected ? ZirconColors.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  color: enabled
                      ? ZirconColors.textMuted
                      : ZirconColors.textDim,
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.fade,
                style: TextStyle(
                  color: selected ? ZirconColors.accent : ZirconColors.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortraitTools extends StatelessWidget {
  const _PortraitTools({required this.controller});
  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    Widget button(
      IconData icon,
      String label,
      VoidCallback onTap, {
      bool active = false,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Material(
            color: const Color(0xD90B0E13),
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    icon,
                    size: 17,
                    color: active ? ZirconColors.accent : ZirconColors.text,
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      color: active
                          ? ZirconColors.accent
                          : ZirconColors.textMuted,
                      fontSize: 6,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: <Widget>[
        button(
          Icons.center_focus_strong_rounded,
          'FOCUS',
          () => controller.selectControl(CameraControl.focus),
        ),
        button(
          Icons.lock_outline_rounded,
          'AE/AF',
          () => controller.setAeAfLock(!controller.aeAfLocked),
          active: controller.aeAfLocked,
        ),
        button(
          Icons.zoom_in_rounded,
          'ZOOM',
          () => controller.selectControl(CameraControl.zoom),
          active: controller.activeControl == CameraControl.zoom,
        ),
        button(
          Icons.monitor_heart_outlined,
          'MON',
          () => CameraScreen._showMonitorTools(context, controller),
          active: true,
        ),
      ],
    );
  }
}

class _PortraitBottom extends StatelessWidget {
  const _PortraitBottom({required this.controller});
  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 132,
        padding: const EdgeInsets.fromLTRB(16, 5, 16, 8),
        decoration: const BoxDecoration(
          color: Color(0xEE080C11),
          border: Border(top: BorderSide(color: ZirconColors.stroke)),
        ),
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: _TelemetryBadge(controller: controller),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  _PortraitNav(
                    icon: Icons.video_library_outlined,
                    label: 'MEDIA',
                    onTap: () => controller.setSection(AppSection.media),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      RecordButton(
                        recording: controller.recording,
                        busy: controller.recordBusy,
                        enabled: controller.canRecord,
                        onTap: controller.toggleRecording,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        controller.recording ? 'STOP' : 'REC',
                        style: TextStyle(
                          color: controller.recording
                              ? ZirconColors.record
                              : ZirconColors.text,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  _PortraitNav(
                    icon: Icons.tune_rounded,
                    label: 'SETTINGS',
                    onTap: () => controller.setSection(AppSection.settings),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortraitNav extends StatelessWidget {
  const _PortraitNav({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 24, color: ZirconColors.textMuted),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: ZirconColors.textMuted,
              fontSize: 7,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.controller});
  final CameraUiController controller;
  @override
  Widget build(BuildContext context) {
    final int? textureId = controller.textureId;
    if (textureId == null)
      return Image.asset('assets/mock_preview.jpg', fit: BoxFit.cover);
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: RotatedBox(
            quarterTurns: controller.previewQuarterTurns,
            child: SizedBox(
              width: controller.previewWidth.toDouble(),
              height: controller.previewHeight.toDouble(),
              child: Texture(
                textureId: textureId,
                filterQuality: FilterQuality.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Shading extends StatelessWidget {
  const _Shading();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xD7000000),
          Color(0x10000000),
          Color(0x08000000),
          Color(0xCB000000),
        ],
        stops: <double>[0, .23, .65, 1],
      ),
    ),
  );
}

class _TopHud extends StatelessWidget {
  const _TopHud({required this.controller});
  final CameraUiController controller;

  String get _format => switch (controller.recordingMode) {
    RecordingMode.uhd30 => 'UHD 16:9',
    RecordingMode.fhd30 => 'FHD 16:9',
    RecordingMode.fourThree30 => '1440p 4:3',
  };

  _Hud get _mode => _Hud(
    7,
    'MODE',
    switch (controller.operationMode) {
      CameraOperationMode.auto => 'AUTO',
      CameraOperationMode.manual => 'MANUAL',
      CameraOperationMode.mixed => 'MIXED',
    },
    () => controller.setMasterAuto(
      controller.operationMode != CameraOperationMode.auto,
    ),
    selected: controller.operationMode == CameraOperationMode.manual,
    warning: controller.operationMode == CameraOperationMode.mixed,
  );

  @override
  Widget build(BuildContext context) {
    final bool automatic = controller.operationMode == CameraOperationMode.auto;
    return Container(
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ZirconColors.panelSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZirconColors.glassBorder),
      ),
      child: automatic
          ? Row(
              children: <Widget>[
                _Hud(
                  7,
                  'LENS',
                  controller.lens,
                  () => controller.selectControl(CameraControl.lens),
                ),
                _Hud(
                  5,
                  'FPS',
                  controller.fps,
                  () => controller.selectControl(CameraControl.fps),
                ),
                Expanded(flex: 19, child: _Timecode(controller: controller)),
                _Hud(
                  8,
                  'FORMAT',
                  _format,
                  () => CameraScreen._notice(
                    context,
                    '${controller.recordingMode.width}×${controller.recordingMode.height} • ${controller.recordingMode.fps} fps • ${controller.bitratePreset.display}',
                  ),
                ),
                _mode,
              ],
            )
          : Row(
              children: <Widget>[
                _Hud(
                  7,
                  'LENS',
                  controller.lens,
                  () => controller.selectControl(CameraControl.lens),
                  selected: controller.activeControl == CameraControl.lens,
                ),
                _Hud(
                  5,
                  'FPS',
                  controller.fps,
                  () => controller.selectControl(CameraControl.fps),
                  selected: controller.activeControl == CameraControl.fps,
                ),
                _Hud(
                  8,
                  'SHUTTER',
                  controller.shutter,
                  () => controller.selectControl(CameraControl.shutter),
                  selected: controller.activeControl == CameraControl.shutter,
                ),
                _Hud(
                  6,
                  'IRIS',
                  'f/1.65',
                  () => CameraScreen._notice(
                    context,
                    'The zircon main camera has a fixed f/1.65 aperture.',
                  ),
                  locked: true,
                ),
                Expanded(flex: 19, child: _Timecode(controller: controller)),
                _Hud(
                  6,
                  'ISO',
                  controller.iso,
                  () => controller.selectControl(CameraControl.iso),
                  selected: controller.activeControl == CameraControl.iso,
                ),
                _Hud(
                  8,
                  'WB',
                  controller.whiteBalance,
                  () => controller.selectControl(CameraControl.whiteBalance),
                  selected:
                      controller.activeControl == CameraControl.whiteBalance,
                ),
                _Hud(
                  5,
                  'TINT',
                  controller.tint,
                  () => controller.selectControl(CameraControl.tint),
                  selected: controller.activeControl == CameraControl.tint,
                  locked: true,
                ),
                _Hud(
                  8,
                  'FORMAT',
                  _format,
                  () => CameraScreen._notice(
                    context,
                    '${controller.recordingMode.width}×${controller.recordingMode.height} • ${controller.recordingMode.fps} fps • ${controller.bitratePreset.display}',
                  ),
                ),
                _mode,
              ],
            ),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud(
    this.flex,
    this.label,
    this.value,
    this.onTap, {
    this.selected = false,
    this.warning = false,
    this.locked = false,
  });
  final int flex;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool selected;
  final bool warning;
  final bool locked;
  @override
  Widget build(BuildContext context) {
    final Color active = warning ? ZirconColors.warning : ZirconColors.accent;
    return Expanded(
      flex: flex,
      child: Material(
        color: selected ? active.withValues(alpha: .13) : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              border: Border(
                right: const BorderSide(color: Color(0x332F3A45)),
                bottom: BorderSide(
                  color: selected ? active : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? active : ZirconColors.textMuted,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      color: locked
                          ? ZirconColors.textDim
                          : (selected ? active : ZirconColors.text),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
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

class _Timecode extends StatelessWidget {
  const _Timecode({required this.controller});
  final CameraUiController controller;
  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.center,
    color: controller.recording
        ? ZirconColors.record.withValues(alpha: .1)
        : Colors.transparent,
    child: FittedBox(
      child: Row(
        children: <Widget>[
          if (controller.recording) ...<Widget>[
            const SizedBox(
              width: 7,
              height: 7,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ZirconColors.record,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            controller.timecode,
            style: TextStyle(
              color: controller.recording
                  ? ZirconColors.record
                  : ZirconColors.text,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    ),
  );
}

class _RuntimeBadge extends StatelessWidget {
  const _RuntimeBadge({required this.controller});
  final CameraUiController controller;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xC90B0E13),
      border: Border.all(color: ZirconColors.stroke),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      '${controller.runtimeLabel} • ISO ${controller.actualIso ?? '—'} • ${controller.actualExposureLabel} • Z ${(controller.actualZoomRatio ?? controller.zoomRatio).toStringAsFixed(2)}× • ${controller.measuredPreviewFps?.toStringAsFixed(2) ?? '—'} FPS',
      style: const TextStyle(
        color: ZirconColors.warning,
        fontSize: 7,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.controller});
  final CameraUiController controller;

  Widget _glassBox(Widget child, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Container(
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: ZirconColors.panelSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ZirconColors.glassBorder),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: <Widget>[
            _glassBox(const _Histogram(), flex: 16),
            _glassBox(_Storage(controller: controller), flex: 14),
            _glassBox(_Project(controller: controller), flex: 21),
            _glassBox(_Audio(controller: controller), flex: 16),
          ],
        ),
      );
}

class _Histogram extends StatelessWidget {
  const _Histogram();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 5, 8, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _Title('HISTOGRAM', 'UI'),
        const SizedBox(height: 3),
        Expanded(child: CustomPaint(painter: _HistPainter())),
      ],
    ),
  );
}

class _HistPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint grid = Paint()
      ..color = ZirconColors.stroke
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Offset.zero & size, grid);
    final Path path = Path()..moveTo(0, size.height);
    for (int x = 0; x <= size.width.floor(); x += 2) {
      final double t = x / math.max(1, size.width);
      final double a = math.exp(-math.pow((t - .28) / .16, 2));
      final double b = .72 * math.exp(-math.pow((t - .7) / .13, 2));
      path.lineTo(x.toDouble(), size.height - (a + b) * size.height * .72);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = ZirconColors.accent.withValues(alpha: .72),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Storage extends StatelessWidget {
  const _Storage({required this.controller});
  final CameraUiController controller;
  @override
  Widget build(BuildContext context) {
    final double free = controller.storageFreeFraction ?? 0;
    final int? battery = controller.batteryPercent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(9, 5, 9, 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Title(
            'DEVICE',
            controller.storageAvailableBytes == null ? 'WAIT' : 'LIVE',
          ),
          const Spacer(),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  controller.storageAvailableLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                controller.batteryCharging
                    ? Icons.battery_charging_full_rounded
                    : Icons.battery_std_rounded,
                size: 13,
                color: battery != null && battery <= 15
                    ? ZirconColors.record
                    : ZirconColors.text,
              ),
              const SizedBox(width: 2),
              Text(
                battery == null ? '—' : '$battery%',
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          LinearProgressIndicator(
            value: free,
            minHeight: 3,
            color: free < .1 ? ZirconColors.record : ZirconColors.blue,
            backgroundColor: ZirconColors.stroke,
          ),
          const SizedBox(height: 2),
          Text(
            '${controller.storageAvailableLabel} FREE • ${controller.storageTotalLabel} TOTAL',
            maxLines: 1,
            overflow: TextOverflow.fade,
            style: const TextStyle(color: ZirconColors.textDim, fontSize: 6),
          ),
        ],
      ),
    );
  }
}

class _Project extends StatelessWidget {
  const _Project({required this.controller});
  final CameraUiController controller;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(9, 5, 9, 5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _Title('PROJECT / RECORDING', 'BETA'),
        const Spacer(),
        Text(
          '${controller.project} • ${controller.clipName}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: ZirconColors.text,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'HEVC ${controller.bitratePreset.display}',
          style: const TextStyle(
            color: ZirconColors.accent,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${controller.resolution} • ${controller.profile} • MAIN 8-BIT',
          style: const TextStyle(color: ZirconColors.textMuted, fontSize: 6.5),
        ),
      ],
    ),
  );
}

class _Audio extends StatelessWidget {
  const _Audio({required this.controller});
  final CameraUiController controller;
  @override
  Widget build(BuildContext context) {
    final double? db = controller.audioLevelDbfs;
    final double value = db == null ? 0 : ((db + 60) / 60).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Title('MIC LEVEL', controller.recording ? 'LIVE' : 'ARMED'),
          const Spacer(),
          _Meter('M', value),
          const SizedBox(height: 5),
          Text(
            db == null
                ? 'START RECORDING FOR dBFS'
                : '${db.toStringAsFixed(1)} dBFS',
            style: const TextStyle(
              color: ZirconColors.textMuted,
              fontSize: 7,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter(this.label, this.value);
  final String label;
  final double value;
  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      SizedBox(
        width: 10,
        child: Text(
          label,
          style: const TextStyle(color: ZirconColors.textMuted, fontSize: 7),
        ),
      ),
      Expanded(
        child: SizedBox(
          height: 6,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const ColoredBox(color: ZirconColors.stroke),
              FractionallySizedBox(
                widthFactor: value,
                alignment: Alignment.centerLeft,
                child: const ColoredBox(color: ZirconColors.good),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _Title extends StatelessWidget {
  const _Title(this.title, this.tag);
  final String title;
  final String tag;
  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: ZirconColors.textMuted,
            fontSize: 6.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      Text(
        tag,
        style: const TextStyle(
          color: ZirconColors.warning,
          fontSize: 5.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 1,
    height: 50,
    child: ColoredBox(color: ZirconColors.strokeSoft),
  );
}

class _CameraStatus extends StatelessWidget {
  const _CameraStatus({required this.controller});
  final CameraUiController controller;
  @override
  Widget build(BuildContext context) {
    final bool error = controller.runtimeState == CameraRuntimeState.error;
    final String detail = error
        ? (controller.cameraError ?? 'Unknown Camera2 error')
        : 'Waiting for Camera2 preview and permission.';
    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      margin: const EdgeInsets.fromLTRB(12, 42, 12, 58),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xEF0B0E13),
        border: Border.all(
          color: error ? ZirconColors.record : ZirconColors.stroke,
        ),
        borderRadius: BorderRadius.circular(ZirconRadius.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                error ? Icons.error_outline_rounded : Icons.camera_outlined,
                color: error ? ZirconColors.record : ZirconColors.accent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  error ? 'CAMERA2 NOT ACTIVE' : controller.runtimeLabel,
                  style: TextStyle(
                    color: error ? ZirconColors.record : ZirconColors.text,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (error) ...<Widget>[
                IconButton(
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: detail)),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                ),
                FilledButton(
                  onPressed: controller.retryCamera,
                  child: const Text('RETRY'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 7),
          SelectionArea(
            child: Text(
              detail,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ZirconColors.textMuted,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RightControlPanel extends StatelessWidget {
  const _RightControlPanel({required this.controller});
  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      decoration: const BoxDecoration(
        color: ZirconColors.panelStrong,
        border: Border(left: BorderSide(color: ZirconColors.stroke)),
      ),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 20),
          _RailButton(
            icon: Icons.videocam_outlined,
            label: 'CAMERA',
            selected: controller.section == AppSection.camera,
            onTap: () => controller.setSection(AppSection.camera),
          ),
          const Spacer(),
          RecordButton(
            recording: controller.recording,
            busy: controller.recordBusy,
            enabled: controller.canRecord,
            size: 64,
            onTap: controller.toggleRecording,
          ),
          const SizedBox(height: 4),
          Text(
            controller.recording ? 'STOP' : 'REC',
            style: TextStyle(
              color: controller.recording
                  ? ZirconColors.record
                  : ZirconColors.text,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          _RailButton(
            icon: Icons.video_library_outlined,
            label: 'MEDIA',
            selected: controller.section == AppSection.media,
            onTap: () => controller.setSection(AppSection.media),
          ),
          const SizedBox(height: 12),
          _RailButton(
            icon: Icons.tune_rounded,
            label: 'SETTINGS',
            selected: controller.section == AppSection.settings,
            onTap: () => controller.setSection(AppSection.settings),
          ),
          const SizedBox(height: 12),
          _RailButton(
            icon: Icons.more_horiz_rounded,
            label: '',
            selected: controller.showQuickTools,
            onTap: controller.toggleQuickTools,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _LeftToolRail extends StatelessWidget {
  const _LeftToolRail({required this.controller});
  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: ZirconColors.panelSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZirconColors.glassBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _ToolButton(
            icon: Icons.center_focus_strong_rounded,
            label: 'FOCUS',
            selected: controller.activeControl == CameraControl.focus,
            onTap: () => controller.selectControl(CameraControl.focus),
          ),
          const SizedBox(height: 12),
          _ToolButton(
            icon: Icons.lock_outline_rounded,
            label: 'AE/AF',
            selected: controller.aeAfLocked,
            onTap: () => controller.setAeAfLock(!controller.aeAfLocked),
          ),
          const SizedBox(height: 12),
          _ToolButton(
            icon: Icons.zoom_in_rounded,
            label: 'ZOOM',
            selected: controller.activeControl == CameraControl.zoom,
            onTap: () => controller.selectControl(CameraControl.zoom),
          ),
          const SizedBox(height: 12),
          _ToolButton(
            icon: Icons.monitor_heart_outlined,
            label: 'MON',
            onTap: () => CameraScreen._showMonitorTools(context, controller),
          ),
        ],
      ),
    );
  }
}

class _QuickToolsOverlay extends StatelessWidget {
  const _QuickToolsOverlay({required this.controller});
  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: ZirconColors.panelStrong,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZirconColors.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _ToolButton(
            icon: Icons.gradient_rounded,
            label: 'LUT',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('LUT selection panel')),
            ),
          ),
          const SizedBox(width: 8),
          _ToolButton(
            icon: Icons.vibration_rounded,
            label: 'STABILIZE',
            selected: controller.stabilizationMode != StabilizationMode.off,
            onTap: controller.cycleStabilizationMode,
          ),
          const SizedBox(width: 8),
          _ToolButton(
            icon: Icons.exposure_rounded,
            label: 'EV',
            selected:
                controller.activeControl == CameraControl.exposureCompensation,
            onTap: () =>
                controller.selectControl(CameraControl.exposureCompensation),
          ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? ZirconColors.accent : ZirconColors.text;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 28, color: color),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? ZirconColors.accent : ZirconColors.text;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 7,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
