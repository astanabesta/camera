import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/tokens.dart';
import '../model/camera_ui_controller.dart';

class VerticalControlPanel extends StatelessWidget {
  const VerticalControlPanel({required this.controller, super.key});

  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    final CameraControl? control = controller.activeControl;
    if (control == null) return const SizedBox.shrink();
    return Container(
      width: 184,
      decoration: const BoxDecoration(
        color: Color(0xF20B0E13),
        border: Border(
          left: BorderSide(color: ZirconColors.stroke),
          bottom: BorderSide(color: ZirconColors.stroke),
        ),
      ),
      child: Column(
        children: <Widget>[
          _Header(controller: controller, control: control),
          if (_supportsAuto(control))
            _AutoManualSwitch(controller: controller, control: control),
          if (control == CameraControl.zoom)
            _ZoomSpeedControl(controller: controller),
          Expanded(child: _body(control)),
        ],
      ),
    );
  }

  Widget _body(CameraControl control) => switch (control) {
    CameraControl.iso => _ruler(
      control,
      0,
      6,
      72,
      1 / 12,
      '50–3200 • 800 ANALOG MAX',
      const <_Preset>[
        _Preset(0, '50'),
        _Preset(1, '100'),
        _Preset(2, '200'),
        _Preset(3, '400 HCG*'),
        _Preset(4, '800 A-MAX'),
        _Preset(5, '1600 DIGITAL'),
        _Preset(6, '3200 DIGITAL'),
      ],
      (double value) => '${(50 * math.pow(2, value)).round()}',
    ),
    CameraControl.shutter => _ruler(
      control,
      11.25,
      345.6,
      3343,
      .1,
      'ANGLE • 0.1° FINE',
      const <_Preset>[
        _Preset(90, '90°'),
        _Preset(144, '144°'),
        _Preset(172.8, '172.8°'),
        _Preset(180, '180°'),
        _Preset(216, '216°'),
      ],
      (double value) => '${value.toStringAsFixed(1)}°',
    ),
    CameraControl.focus => _ruler(
      control,
      0,
      10,
      1000,
      .01,
      '0–10 DIOPTERS • FINE PULL',
      const <_Preset>[
        _Preset(0, '∞'),
        _Preset(.333333, '3m'),
        _Preset(1, '1m'),
        _Preset(3.333333, '30cm'),
        _Preset(10, '10cm'),
      ],
      _focus,
    ),
    CameraControl.exposureCompensation => _ruler(
      control,
      -4,
      4,
      48,
      1 / 6,
      'AUTO EXPOSURE • ±4 EV',
      const <_Preset>[
        _Preset(-2, '-2'),
        _Preset(-1, '-1'),
        _Preset(0, '0'),
        _Preset(1, '+1'),
        _Preset(2, '+2'),
      ],
      (double value) => '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}',
    ),
    CameraControl.whiteBalance => _whiteBalance(),
    CameraControl.fps => const _FrameRatePanel(),
    CameraControl.lens => const _LockedPanel(
      title: 'CAMERA 0 • MAIN',
      detail:
          'Only the main rear camera is publicly exposed as a cinema-capable Camera2 device.',
      tags: <String>['MAIN', '6.14 mm', 'f/1.65'],
    ),
    CameraControl.tint => const _LockedPanel(
      title: 'TINT CALIBRATION GATED',
      detail:
          'Exact tint requires measured per-channel gains. No invented calibration is exposed.',
      tags: <String>['AUTO', 'NOT CALIBRATED'],
    ),
    CameraControl.zoom => _ruler(
      control,
      math.log(controller.minimumZoomRatio) / math.ln2,
      math.log(controller.maximumZoomRatio) / math.ln2,
      180,
      1 / 60,
      '${controller.zoomSpeed.compactLabel} • LOG₂ • ACT ${_zoom(controller.actualZoomRatio ?? 1.0)}',
      <_Preset>[
        const _Preset(0, '1×'),
        const _Preset(1, '2×'),
        const _Preset(2, '4×'),
        _Preset(
          math.log(controller.maximumZoomRatio) / math.ln2,
          '${_zoom(controller.maximumZoomRatio)} MAX',
        ),
      ],
      (double value) => _zoom(math.pow(2, value).toDouble()),
    ),
  };

  Widget _ruler(
    CameraControl control,
    double min,
    double max,
    int divisions,
    double step,
    String helper,
    List<_Preset> presets,
    String Function(double) formatter,
  ) {
    final double value = controller
        .numericControlValue(control)
        .clamp(min, max)
        .toDouble();
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(9, 7, 9, 3),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  helper,
                  style: const TextStyle(
                    color: ZirconColors.warning,
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                formatter(value),
                style: const TextStyle(
                  color: ZirconColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 74,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: presets
                      .map((_Preset preset) {
                        final bool selected =
                            (value - preset.value).abs() < step * 1.1;
                        return SizedBox(
                          width: 68,
                          height: presets.length > 5 ? 20 : 25,
                          child: TextButton(
                            onPressed: () => controller.setNumericControlValue(
                              control,
                              preset.value,
                            ),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              foregroundColor: selected
                                  ? ZirconColors.accent
                                  : ZirconColors.text,
                              backgroundColor: selected
                                  ? ZirconColors.accentSoft
                                  : Colors.transparent,
                              textStyle: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: Text(preset.label),
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    const Positioned.fill(
                      child: CustomPaint(painter: _Ticks()),
                    ),
                    RotatedBox(
                      quarterTurns: 3,
                      child: SliderTheme(
                        data: const SliderThemeData(
                          trackHeight: 2,
                          activeTrackColor: ZirconColors.accent,
                          inactiveTrackColor: ZirconColors.stroke,
                          thumbColor: ZirconColors.text,
                          thumbShape: RoundSliderThumbShape(
                            enabledThumbRadius: 7,
                          ),
                        ),
                        child: Slider(
                          value: value,
                          min: min,
                          max: max,
                          divisions: divisions,
                          onChanged: (double next) {
                            if (controller.hapticControlFeedback)
                              HapticFeedback.selectionClick();
                            controller.setNumericControlValue(control, next);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 33,
          child: Row(
            children: <Widget>[
              Expanded(
                child: IconButton(
                  onPressed: () => controller.setNumericControlValue(
                    control,
                    (value - step).clamp(min, max).toDouble(),
                  ),
                  icon: const Icon(Icons.remove_rounded, size: 17),
                ),
              ),
              const Text(
                'FINE',
                style: TextStyle(
                  color: ZirconColors.textMuted,
                  fontSize: 7,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Expanded(
                child: IconButton(
                  onPressed: () => controller.setNumericControlValue(
                    control,
                    (value + step).clamp(min, max).toDouble(),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 17),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _whiteBalance() {
    const List<String> labels = <String>[
      'AUTO',
      '3200K',
      '4300K',
      '5600K',
      '6500K',
    ];
    return Column(
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'VENDOR PRESETS • NOT CHART-CALIBRATED',
            style: TextStyle(
              color: ZirconColors.warning,
              fontSize: 7,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: labels
                .map(
                  (String label) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: SizedBox(
                      height: 34,
                      child: OutlinedButton(
                        onPressed: () => controller.setControlValue(
                          CameraControl.whiteBalance,
                          label,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: controller.whiteBalance == label
                              ? ZirconColors.accent
                              : ZirconColors.textMuted,
                          side: BorderSide(
                            color: controller.whiteBalance == label
                                ? ZirconColors.accent
                                : ZirconColors.stroke,
                          ),
                        ),
                        child: Text(label),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }

  static String _focus(double diopters) {
    if (diopters <= .005) return '∞';
    final double meters = 1 / diopters;
    return meters >= 1
        ? '${meters.toStringAsFixed(1)}m'
        : '${(meters * 100).round()}cm';
  }

  static String _zoom(double value) {
    if ((value - value.round()).abs() < .005) return '${value.round()}×';
    return '${value < 2 ? value.toStringAsFixed(2) : value.toStringAsFixed(1)}×';
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.control});
  final CameraUiController controller;
  final CameraControl control;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 45,
      padding: const EdgeInsets.only(left: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ZirconColors.stroke)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _title(control),
                  style: const TextStyle(
                    color: ZirconColors.textMuted,
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  controller.valueFor(control),
                  style: const TextStyle(
                    color: ZirconColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: controller.closeControl,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  static String _title(CameraControl value) => switch (value) {
    CameraControl.lens => 'LENS',
    CameraControl.fps => 'FRAME RATE',
    CameraControl.shutter => 'SHUTTER ANGLE',
    CameraControl.iso => 'SENSOR ISO',
    CameraControl.whiteBalance => 'WHITE BALANCE',
    CameraControl.tint => 'TINT',
    CameraControl.focus => 'FOCUS',
    CameraControl.exposureCompensation => 'EXPOSURE BIAS',
    CameraControl.zoom => 'ZOOM',
  };
}

bool _supportsAuto(CameraControl control) =>
    control == CameraControl.iso ||
    control == CameraControl.focus ||
    control == CameraControl.whiteBalance;

class _ZoomSpeedControl extends StatelessWidget {
  const _ZoomSpeedControl({required this.controller});
  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ZirconColors.strokeSoft)),
      ),
      child: Row(
        children: ZoomSpeed.values
            .map(
              (ZoomSpeed speed) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _ModeButton(
                    label: speed.compactLabel,
                    selected: controller.zoomSpeed == speed,
                    onTap: () => controller.setZoomSpeed(speed),
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _AutoManualSwitch extends StatelessWidget {
  const _AutoManualSwitch({required this.controller, required this.control});

  final CameraUiController controller;
  final CameraControl control;

  @override
  Widget build(BuildContext context) {
    final bool automatic = controller.isControlAuto(control);
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ZirconColors.strokeSoft)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _ModeButton(
              label: 'AUTO',
              selected: automatic,
              onTap: () => controller.setControlAuto(control, true),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _ModeButton(
              label: 'MANUAL',
              selected: !automatic,
              onTap: () => controller.setControlAuto(control, false),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? ZirconColors.accentSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? ZirconColors.accent : ZirconColors.stroke,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: selected ? ZirconColors.accent : ZirconColors.textMuted,
                fontSize: 7,
                fontWeight: FontWeight.w900,
                letterSpacing: .35,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FrameRatePanel extends StatelessWidget {
  const _FrameRatePanel();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: Column(
        children: <Widget>[
          Text(
            '24/25 UNQUALIFIED',
            style: TextStyle(
              color: ZirconColors.warning,
              fontSize: 8,
              fontWeight: FontWeight.w900,
            ),
          ),
          Spacer(),
          _Rate('24 🔒'),
          SizedBox(height: 6),
          _Rate('25 🔒'),
          SizedBox(height: 6),
          _Rate('30  ACTIVE', active: true),
          Spacer(),
          Text(
            '30 fps is the only functional-beta request.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ZirconColors.textMuted, fontSize: 8),
          ),
        ],
      ),
    );
  }
}

class _Rate extends StatelessWidget {
  const _Rate(this.label, {this.active = false});
  final String label;
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
    height: 38,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: active ? ZirconColors.accentSoft : const Color(0xFF11161D),
      border: Border.all(
        color: active ? ZirconColors.accent : ZirconColors.stroke,
      ),
      borderRadius: BorderRadius.circular(ZirconRadius.sm),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: active ? ZirconColors.accent : ZirconColors.textDim,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _LockedPanel extends StatelessWidget {
  const _LockedPanel({
    required this.title,
    required this.detail,
    required this.tags,
  });
  final String title;
  final String detail;
  final List<String> tags;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(
          Icons.lock_outline_rounded,
          color: ZirconColors.warning,
          size: 24,
        ),
        const SizedBox(height: 9),
        Text(
          title,
          style: const TextStyle(
            color: ZirconColors.warning,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          detail,
          style: const TextStyle(
            color: ZirconColors.textMuted,
            fontSize: 9,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: tags
              .map(
                (String tag) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: ZirconColors.stroke),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      color: ZirconColors.text,
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ],
    ),
  );
}

class _Preset {
  const _Preset(this.value, this.label);
  final double value;
  final String label;
}

class _Ticks extends CustomPainter {
  const _Ticks();
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = ZirconColors.stroke
      ..strokeWidth = 1;
    for (int i = 0; i <= 14; i++) {
      final double y = 8 + (size.height - 16) * i / 14;
      final double length = i.isEven ? 10 : 5;
      canvas.drawLine(
        Offset(size.width / 2 - length, y),
        Offset(size.width / 2 + length, y),
        paint,
      );
    }
    canvas.drawLine(
      Offset(size.width / 2 - 16, size.height / 2),
      Offset(size.width / 2 + 16, size.height / 2),
      Paint()
        ..color = ZirconColors.accent
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
