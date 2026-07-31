import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../model/camera_ui_controller.dart';
import 'cinema_ruler.dart';
import 'glass_panel.dart';

class ControlSheet extends StatelessWidget {
  const ControlSheet({required this.controller, super.key});

  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    final CameraControl? control = controller.activeControl;
    if (control == null) return const SizedBox.shrink();

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(13, 8, 7, 8),
      borderRadius: ZirconRadius.lg,
      color: ZirconColors.panelStrong,
      blur: 18,
      child: SizedBox(
        height: 128,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 126,
              child: _ControlIdentity(controller: controller, control: control),
            ),
            Container(width: 1, height: 92, color: ZirconColors.stroke),
            const SizedBox(width: 11),
            Expanded(
              child: _ProfessionalControl(
                key: ValueKey<CameraControl>(control),
                controller: controller,
                control: control,
              ),
            ),
            const SizedBox(width: 5),
            IconButton(
              tooltip: 'Close control',
              onPressed: controller.closeControl,
              icon: const Icon(
                Icons.close_rounded,
                color: ZirconColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlIdentity extends StatelessWidget {
  const _ControlIdentity({required this.controller, required this.control});

  final CameraUiController controller;
  final CameraControl control;

  @override
  Widget build(BuildContext context) {
    final bool supportsAuto = _supportsAuto(control);
    final bool auto = supportsAuto && controller.isControlAuto(control);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          _label(control),
          maxLines: 1,
          overflow: TextOverflow.fade,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            controller.valueFor(control),
            maxLines: 1,
            style: const TextStyle(
              color: ZirconColors.accent,
              fontSize: 21,
              height: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _helper(control),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: ZirconColors.textMuted,
            fontSize: 8,
            height: 1.2,
          ),
        ),
        if (supportsAuto) ...<Widget>[
          const SizedBox(height: 7),
          SizedBox(
            height: 25,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(value: true, label: Text('AUTO')),
                ButtonSegment<bool>(value: false, label: Text('MANUAL')),
              ],
              selected: <bool>{auto},
              onSelectionChanged: controller.controlsLocked
                  ? null
                  : (Set<bool> values) =>
                        controller.setControlAuto(control, values.first),
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll<TextStyle>(
                  TextStyle(fontSize: 7, fontWeight: FontWeight.w700),
                ),
                padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
                  EdgeInsets.symmetric(horizontal: 5),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ProfessionalControl extends StatelessWidget {
  const _ProfessionalControl({
    required this.controller,
    required this.control,
    super.key,
  });

  final CameraUiController controller;
  final CameraControl control;

  @override
  Widget build(BuildContext context) {
    final bool enabled =
        !controller.controlsLocked && controller.isControlAvailable(control);
    return switch (control) {
      CameraControl.iso => _isoRuler(enabled),
      CameraControl.shutter => _shutterRuler(enabled),
      CameraControl.focus => _focusRuler(enabled),
      CameraControl.exposureCompensation => _evRuler(enabled),
      CameraControl.whiteBalance => _whiteBalanceRuler(enabled),
      CameraControl.fps => _fpsControl(),
      CameraControl.tint => const _UnavailableControl(
        title: 'TINT CALIBRATION REQUIRED',
        detail:
            'Tint is preserved in the interface but disabled until measured sensor gains and chart calibration are frozen.',
      ),
      CameraControl.lens => const _UnavailableControl(
        title: 'CAMERA 0 • MAIN LENS',
        detail:
            'No other rear physical lens is exposed as an independent Camera2 device.',
        warning: false,
      ),
      CameraControl.zoom => const _UnavailableControl(
        title: 'ZOOM NOT ACTIVE IN THIS NATIVE BASELINE',
        detail:
            'The preserved v0.4 recorder stays at 1×. Smooth Camera2 crop zoom requires a restored and device-tested native engine.',
      ),
    };
  }

  Widget _isoRuler(bool enabled) {
    return _RulerWithHint(
      hint: controller.isControlAuto(control)
          ? 'Swipe to take manual control • logarithmic ⅓-stop scale'
          : 'Swipe left/right • FINE gives ¹⁄₁₂-stop steps',
      child: CinemaRuler(
        value: math.log(controller.manualIso / 50.0) / math.ln2,
        minimum: 0,
        maximum: 4,
        coarseStep: 1 / 3,
        fineStep: 1 / 12,
        haptics: controller.hapticControlFeedback,
        enabled: enabled,
        snapPoints: const <double>[0, 1, 2, 3, 4],
        presets: const <CinemaRulerPreset>[
          CinemaRulerPreset(0, 'ISO 50'),
          CinemaRulerPreset(1, '100'),
          CinemaRulerPreset(2, '200'),
          CinemaRulerPreset(3, '400 HCG*'),
          CinemaRulerPreset(4, '800'),
        ],
        formatValue: (double stops) =>
            'ISO ${(50 * math.pow(2, stops)).round()}',
        onChanged: (double value) =>
            controller.setNumericControlValue(control, value),
      ),
    );
  }

  Widget _shutterRuler(bool enabled) {
    return _RulerWithHint(
      hint: 'Angle follows project FPS • common cinema angles snap precisely',
      child: CinemaRuler(
        value: controller.numericControlValue(control),
        minimum: 11.25,
        maximum: 345.6,
        coarseStep: 1,
        fineStep: .1,
        haptics: controller.hapticControlFeedback,
        enabled: enabled,
        snapPoints: const <double>[45, 90, 144, 172.8, 180, 216, 270],
        presets: const <CinemaRulerPreset>[
          CinemaRulerPreset(90, '90°'),
          CinemaRulerPreset(144, '144°'),
          CinemaRulerPreset(172.8, '172.8°'),
          CinemaRulerPreset(180, '180°'),
          CinemaRulerPreset(216, '216°'),
        ],
        formatValue: _formatAngle,
        onChanged: (double value) =>
            controller.setNumericControlValue(control, value),
      ),
    );
  }

  Widget _focusRuler(bool enabled) {
    return _RulerWithHint(
      hint: controller.isControlAuto(control)
          ? 'Swipe to enter manual focus • native control uses diopters'
          : 'COARSE for setup • FINE for a controlled focus pull',
      child: CinemaRuler(
        value: controller.manualFocusDiopters,
        minimum: 0,
        maximum: 10,
        coarseStep: .1,
        fineStep: .01,
        haptics: controller.hapticControlFeedback,
        enabled: enabled,
        snapPoints: const <double>[0, .333333, 1, 3.333333, 10],
        presets: const <CinemaRulerPreset>[
          CinemaRulerPreset(0, '∞'),
          CinemaRulerPreset(.333333, '3m'),
          CinemaRulerPreset(1, '1m'),
          CinemaRulerPreset(3.333333, '30cm'),
          CinemaRulerPreset(10, '10cm'),
        ],
        formatValue: _formatFocus,
        onChanged: (double value) =>
            controller.setNumericControlValue(control, value),
      ),
    );
  }

  Widget _evRuler(bool enabled) {
    return _RulerWithHint(
      hint: enabled
          ? 'Auto-exposure bias • FINE gives ⅙-stop precision'
          : 'Exposure compensation is available only while ISO is AUTO',
      child: CinemaRuler(
        value: controller.exposureCompensationEv,
        minimum: -4,
        maximum: 4,
        coarseStep: 1 / 3,
        fineStep: 1 / 6,
        haptics: controller.hapticControlFeedback,
        enabled: enabled,
        snapPoints: const <double>[-2, -1, 0, 1, 2],
        presets: const <CinemaRulerPreset>[
          CinemaRulerPreset(-2, '-2'),
          CinemaRulerPreset(-1, '-1'),
          CinemaRulerPreset(0, '0'),
          CinemaRulerPreset(1, '+1'),
          CinemaRulerPreset(2, '+2'),
        ],
        formatValue: (double value) =>
            '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)} EV',
        onChanged: (double value) =>
            controller.setNumericControlValue(control, value),
      ),
    );
  }

  Widget _whiteBalanceRuler(bool enabled) {
    const List<String> labels = <String>[
      'AUTO',
      '3200K',
      '4300K',
      '5600K',
      '6500K',
    ];
    int index = labels.indexOf(controller.whiteBalance);
    if (index < 0) index = 3;
    return _RulerWithHint(
      hint:
          'Vendor Camera2 presets • labels are approximate, not chart-calibrated Kelvin',
      child: CinemaRuler(
        value: index.toDouble(),
        minimum: 0,
        maximum: (labels.length - 1).toDouble(),
        coarseStep: 1,
        fineStep: 1,
        haptics: controller.hapticControlFeedback,
        enabled: enabled,
        showFineMode: false,
        presets: const <CinemaRulerPreset>[
          CinemaRulerPreset(0, 'AUTO'),
          CinemaRulerPreset(1, '3200K'),
          CinemaRulerPreset(2, '4300K'),
          CinemaRulerPreset(3, '5600K'),
          CinemaRulerPreset(4, '6500K'),
        ],
        formatValue: (double value) =>
            labels[value.round().clamp(0, labels.length - 1).toInt()],
        onChanged: (double value) {
          final int next = value.round().clamp(0, labels.length - 1).toInt();
          controller.setControlValue(control, labels[next]);
        },
      ),
    );
  }

  Widget _fpsControl() {
    return Row(
      children: <Widget>[
        Expanded(
          child: _ValueButton(
            value: '24',
            selected: controller.fps == '24',
            enabled: false,
            onTap: () {},
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _ValueButton(
            value: '25',
            selected: controller.fps == '25',
            enabled: false,
            onTap: () {},
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _ValueButton(
            value: '30',
            selected: controller.fps == '30',
            enabled: true,
            onTap: () => controller.setControlValue(control, '30'),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          flex: 2,
          child: _UnavailableControl(
            title: '24/25 LOCKED',
            detail:
                'They remain visible but require manual cadence and encoded PTS qualification.',
          ),
        ),
      ],
    );
  }

  static String _formatAngle(double value) {
    final bool whole = (value - value.round()).abs() < .01;
    return '${whole ? value.round() : value.toStringAsFixed(1)}°';
  }

  static String _formatFocus(double diopters) {
    if (diopters <= .005) return '∞ • 0.00D';
    final double meters = 1 / diopters;
    final String distance = meters >= 10
        ? '${meters.toStringAsFixed(0)}m'
        : meters >= 1
        ? '${meters.toStringAsFixed(1)}m'
        : '${(meters * 100).round()}cm';
    return '$distance • ${diopters.toStringAsFixed(2)}D';
  }
}

class _RulerWithHint extends StatelessWidget {
  const _RulerWithHint({required this.hint, required this.child});

  final String hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          hint,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: ZirconColors.textMuted, fontSize: 8),
        ),
        const SizedBox(height: 5),
        child,
      ],
    );
  }
}

class _UnavailableControl extends StatelessWidget {
  const _UnavailableControl({
    required this.title,
    required this.detail,
    this.warning = true,
  });

  final String title;
  final String detail;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final Color color = warning ? ZirconColors.warning : ZirconColors.accent;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        border: Border.all(color: color.withValues(alpha: .3)),
        borderRadius: BorderRadius.circular(ZirconRadius.md),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            detail,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ZirconColors.textMuted,
              fontSize: 9,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueButton extends StatelessWidget {
  const _ValueButton({
    required this.value,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String value;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color activeColor = enabled
        ? ZirconColors.accent
        : ZirconColors.warning;
    return Material(
      color: selected
          ? activeColor.withValues(alpha: .16)
          : ZirconColors.panelSoft,
      borderRadius: BorderRadius.circular(ZirconRadius.md),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(ZirconRadius.md),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? activeColor : ZirconColors.strokeSoft,
            ),
            borderRadius: BorderRadius.circular(ZirconRadius.md),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                value,
                style: TextStyle(
                  color: enabled
                      ? (selected ? ZirconColors.accent : ZirconColors.text)
                      : ZirconColors.textDim,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                enabled ? (selected ? 'ACTIVE' : 'SELECT') : 'LOCKED',
                style: TextStyle(
                  color: enabled
                      ? (selected ? ZirconColors.accent : ZirconColors.textDim)
                      : ZirconColors.warning,
                  fontSize: 7,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _label(CameraControl control) => switch (control) {
  CameraControl.lens => 'LENS',
  CameraControl.fps => 'FRAME RATE',
  CameraControl.shutter => 'SHUTTER ANGLE',
  CameraControl.iso => 'SENSOR ISO',
  CameraControl.whiteBalance => 'WHITE BALANCE',
  CameraControl.tint => 'TINT',
  CameraControl.focus => 'FOCUS DISTANCE',
  CameraControl.exposureCompensation => 'EXPOSURE BIAS',
  CameraControl.zoom => 'ZOOM',
};

String _helper(CameraControl control) => switch (control) {
  CameraControl.lens => 'Camera 0 only',
  CameraControl.fps => '30 fps qualified for testing',
  CameraControl.shutter => '11.25°–345.6°',
  CameraControl.iso => '50–800 analog range',
  CameraControl.whiteBalance => 'Vendor presets',
  CameraControl.tint => 'Calibration gated',
  CameraControl.focus => '0–10 diopters',
  CameraControl.exposureCompensation => 'AE only • ±4 EV',
  CameraControl.zoom => 'Preserved recorder baseline • 1×',
};

bool _supportsAuto(CameraControl control) =>
    control == CameraControl.iso ||
    control == CameraControl.focus ||
    control == CameraControl.whiteBalance;
