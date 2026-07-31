import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../model/camera_ui_controller.dart';

class SideRail extends StatelessWidget {
  const SideRail({required this.controller, super.key, this.showRecord = true});

  final CameraUiController controller;
  final bool showRecord;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      color: ZirconColors.panelStrong,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      child: Column(
        children: <Widget>[
          _RailButton(
            icon: Icons.videocam_outlined,
            label: 'CAMERA',
            selected: controller.section == AppSection.camera,
            onTap: () => controller.setSection(AppSection.camera),
          ),
          const SizedBox(height: 5),
          _RailButton(
            icon: controller.recording
                ? Icons.lock_outline_rounded
                : Icons.video_library_outlined,
            label: 'MEDIA',
            selected: controller.section == AppSection.media,
            enabled: !controller.recording,
            onTap: () => controller.setSection(AppSection.media),
          ),
          const Spacer(),
          if (showRecord &&
              controller.section == AppSection.camera) ...<Widget>[
            RecordButton(
              recording: controller.recording,
              busy: controller.recordBusy,
              enabled: controller.canRecord,
              onTap: controller.toggleRecording,
            ),
            const SizedBox(height: 8),
            Text(
              controller.recordBusy
                  ? 'WAIT'
                  : (controller.recording ? 'STOP' : 'REC'),
              style: TextStyle(
                color: controller.recording
                    ? ZirconColors.record
                    : (controller.cameraReady
                          ? ZirconColors.textMuted
                          : ZirconColors.textDim),
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
          const Spacer(),
          _RailButton(
            icon: controller.recording
                ? Icons.lock_outline_rounded
                : Icons.tune_rounded,
            label: 'SETTINGS',
            selected: controller.section == AppSection.settings,
            enabled: !controller.recording,
            onTap: () => controller.setSection(AppSection.settings),
          ),
        ],
      ),
    );
  }
}

class CameraToolRail extends StatelessWidget {
  const CameraToolRail({
    required this.controller,
    required this.onZoom,
    required this.onLut,
    required this.onStabilization,
    required this.onMonitoring,
    super.key,
  });

  final CameraUiController controller;
  final VoidCallback onZoom;
  final VoidCallback onLut;
  final VoidCallback onStabilization;
  final VoidCallback onMonitoring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      color: const Color(0xFF080C11),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
      child: Column(
        children: <Widget>[
          _ToolButton(
            icon: Icons.center_focus_strong_rounded,
            label: 'FOCUS',
            selected: controller.activeControl == CameraControl.focus,
            onTap: () => controller.selectControl(CameraControl.focus),
          ),
          const SizedBox(height: 3),
          _ToolButton(
            icon: Icons.exposure_rounded,
            label: 'EV',
            selected:
                controller.activeControl == CameraControl.exposureCompensation,
            enabled: controller.isControlAvailable(
              CameraControl.exposureCompensation,
            ),
            onTap: () =>
                controller.selectControl(CameraControl.exposureCompensation),
          ),
          const Spacer(),
          RecordButton(
            recording: controller.recording,
            busy: controller.recordBusy,
            enabled: controller.canRecord,
            size: 48,
            onTap: controller.toggleRecording,
          ),
          const SizedBox(height: 2),
          Text(
            controller.recordBusy
                ? 'WAIT'
                : (controller.recording ? 'STOP' : 'REC'),
            style: TextStyle(
              color: controller.recording
                  ? ZirconColors.record
                  : ZirconColors.textMuted,
              fontSize: 7,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
          const Spacer(),
          _ToolButton(
            icon: Icons.zoom_in_rounded,
            label: 'ZOOM',
            selected: controller.activeControl == CameraControl.zoom,
            onTap: onZoom,
          ),
          const SizedBox(height: 3),
          _ToolButton(
            icon: Icons.gradient_rounded,
            label: 'LUT',
            warning: true,
            onTap: onLut,
          ),
          const SizedBox(height: 3),
          _ToolButton(
            icon: Icons.vibration_rounded,
            label: 'OIS',
            warning: true,
            onTap: onStabilization,
          ),
          const SizedBox(height: 3),
          _ToolButton(
            icon: Icons.monitor_heart_outlined,
            label: 'MON',
            selected: true,
            onTap: onMonitoring,
          ),
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
    this.enabled = true,
    this.warning = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool enabled;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final Color active = warning ? ZirconColors.warning : ZirconColors.accent;
    final Color color = !enabled
        ? ZirconColors.textDim
        : (selected || warning ? active : ZirconColors.textMuted);
    return SizedBox(
      width: 46,
      height: 37,
      child: Material(
        color: selected ? active.withValues(alpha: .12) : Colors.transparent,
        borderRadius: BorderRadius.circular(ZirconRadius.sm),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(ZirconRadius.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 16, color: color),
              const SizedBox(height: 1),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 6.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecordButton extends StatelessWidget {
  const RecordButton({
    required this.recording,
    required this.busy,
    required this.enabled,
    required this.onTap,
    super.key,
    this.size = 58,
  });

  final bool recording;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: recording ? 'Stop real recording' : 'Start real recording',
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: ZirconColors.panelStrong,
            shape: BoxShape.circle,
            border: Border.all(
              color: !enabled
                  ? ZirconColors.textDim
                  : (recording ? ZirconColors.record : ZirconColors.text),
              width: 2,
            ),
            boxShadow: <BoxShadow>[
              if (recording)
                BoxShadow(
                  color: ZirconColors.record.withValues(alpha: .35),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ZirconColors.record,
                    ),
                  )
                : AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: recording ? 22 : 39,
                    height: recording ? 22 : 39,
                    decoration: BoxDecoration(
                      color: enabled
                          ? ZirconColors.record
                          : ZirconColors.textDim,
                      borderRadius: BorderRadius.circular(recording ? 5 : 99),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Color color = !enabled
        ? ZirconColors.textDim
        : (selected ? ZirconColors.accent : ZirconColors.textMuted);
    return SizedBox(
      width: 58,
      height: 52,
      child: Material(
        color: selected ? ZirconColors.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(ZirconRadius.md),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(ZirconRadius.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 21, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 7,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
