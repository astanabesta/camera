import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../model/camera_ui_controller.dart';
import 'glass_panel.dart';

class ParameterTile extends StatelessWidget {
  const ParameterTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
    this.width = 86,
    this.warning = false,
    this.locked = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final double width;
  final bool warning;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final Color activeColor = warning
        ? ZirconColors.warning
        : ZirconColors.accent;
    return SizedBox(
      width: width,
      height: 54,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: locked ? null : onTap,
          borderRadius: BorderRadius.circular(ZirconRadius.md),
          child: GlassPanel(
            blur: 8,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            borderColor: selected ? activeColor : ZirconColors.strokeSoft,
            color: selected
                ? activeColor.withValues(alpha: .13)
                : ZirconColors.panel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      locked ? Icons.lock_outline_rounded : icon,
                      size: 11,
                      color: locked
                          ? ZirconColors.textDim
                          : (selected ? activeColor : ZirconColors.textMuted),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          label,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                      color: locked
                          ? ZirconColors.textDim
                          : (selected ? activeColor : ZirconColors.text),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ParameterStrip extends StatelessWidget {
  const ParameterStrip({required this.controller, super.key});

  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    const List<_ParameterSpec> specs = <_ParameterSpec>[
      _ParameterSpec(CameraControl.lens, 'LENS', Icons.camera_outlined),
      _ParameterSpec(CameraControl.fps, 'FPS', Icons.speed_rounded),
      _ParameterSpec(
        CameraControl.shutter,
        'SHUTTER',
        Icons.shutter_speed_rounded,
      ),
      _ParameterSpec(CameraControl.iso, 'ISO', Icons.exposure_outlined),
      _ParameterSpec(
        CameraControl.whiteBalance,
        'WB',
        Icons.thermostat_outlined,
      ),
      _ParameterSpec(CameraControl.tint, 'TINT', Icons.colorize_outlined),
      _ParameterSpec(
        CameraControl.focus,
        'FOCUS',
        Icons.center_focus_strong_rounded,
      ),
      _ParameterSpec(
        CameraControl.exposureCompensation,
        'EV',
        Icons.exposure_rounded,
      ),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: specs
          .map((_ParameterSpec spec) {
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ParameterTile(
                label: spec.label,
                value: controller.valueFor(spec.control),
                icon: spec.icon,
                selected: controller.activeControl == spec.control,
                warning: spec.control == CameraControl.fps,
                locked:
                    controller.controlsLocked ||
                    !controller.isControlAvailable(spec.control),
                onTap: () => controller.selectControl(spec.control),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _ParameterSpec {
  const _ParameterSpec(this.control, this.label, this.icon);

  final CameraControl control;
  final String label;
  final IconData icon;
}
