import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../model/camera_ui_controller.dart';
import 'glass_panel.dart';

class MonitorBar extends StatelessWidget {
  const MonitorBar({required this.controller, super.key});

  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    const List<_ToolSpec> tools = <_ToolSpec>[
      _ToolSpec(MonitorTool.frameGuides, 'GUIDES', Icons.crop_free_rounded),
      _ToolSpec(MonitorTool.grid, 'GRID', Icons.grid_3x3_rounded),
      _ToolSpec(MonitorTool.zebra, 'ZEBRA', Icons.texture_rounded),
      _ToolSpec(MonitorTool.falseColor, 'FALSE', Icons.gradient_rounded),
      _ToolSpec(MonitorTool.peaking, 'PEAK', Icons.filter_center_focus_rounded),
      _ToolSpec(MonitorTool.waveform, 'WAVE', Icons.monitor_heart_outlined),
      _ToolSpec(MonitorTool.histogram, 'HIST', Icons.area_chart_outlined),
      _ToolSpec(MonitorTool.cleanFeed, 'CLEAN', Icons.fullscreen_rounded),
    ];

    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      color: ZirconColors.panelStrong,
      borderRadius: ZirconRadius.md,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: tools
            .map((_ToolSpec spec) {
              final bool enabled = controller.isToolEnabled(spec.tool);
              return _MonitorButton(
                label: spec.label,
                icon: spec.icon,
                enabled: enabled,
                onTap: () => controller.toggleMonitorTool(spec.tool),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _MonitorButton extends StatelessWidget {
  const _MonitorButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = enabled ? ZirconColors.accent : ZirconColors.textMuted;
    return SizedBox(
      width: 53,
      height: 40,
      child: Material(
        color: enabled ? ZirconColors.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(ZirconRadius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ZirconRadius.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 16, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 7,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WaveformScope extends StatelessWidget {
  const WaveformScope({super.key, this.width = 132, this.height = 48});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: EdgeInsets.zero,
      color: ZirconColors.panelStrong,
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: _WaveformPainter()),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint grid = Paint()
      ..color = ZirconColors.stroke.withValues(alpha: .55)
      ..strokeWidth = .5;
    for (int i = 1; i < 4; i++) {
      final double y = size.height * i / 4;
      canvas.drawLine(Offset.zero.translate(0, y), Offset(size.width, y), grid);
    }

    final Paint trace = Paint()
      ..color = ZirconColors.accent.withValues(alpha: .8)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (int layer = 0; layer < 7; layer++) {
      final Path path = Path();
      for (int x = 0; x <= size.width.floor(); x += 2) {
        final double wave = math.sin(x * .065 + layer * .8) * 5;
        final double detail = math.sin(x * .19 + layer) * 2.5;
        final double y = size.height * .57 + wave + detail + layer - 3;
        if (x == 0) {
          path.moveTo(x.toDouble(), y);
        } else {
          path.lineTo(x.toDouble(), y);
        }
      }
      canvas.drawPath(
        path,
        trace
          ..color = ZirconColors.accent.withValues(alpha: .16 + layer * .035),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HistogramScope extends StatelessWidget {
  const HistogramScope({super.key, this.width = 106, this.height = 48});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: EdgeInsets.zero,
      color: ZirconColors.panelStrong,
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: _HistogramPainter()),
      ),
    );
  }
}

class _HistogramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint grid = Paint()
      ..color = ZirconColors.stroke.withValues(alpha: .5)
      ..strokeWidth = .5;
    canvas.drawLine(
      Offset(0, size.height * .5),
      Offset(size.width, size.height * .5),
      grid,
    );

    final Paint fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: <Color>[Color(0xCC3DD6CF), Color(0x223DD6CF)],
      ).createShader(Offset.zero & size);
    final Path path = Path()..moveTo(0, size.height);
    for (int x = 0; x <= size.width.floor(); x += 2) {
      final double normalized = x / size.width;
      final double peakA = math.exp(-math.pow((normalized - .31) / .17, 2));
      final double peakB =
          .72 * math.exp(-math.pow((normalized - .68) / .12, 2));
      final double y = size.height - 4 - (peakA + peakB) * size.height * .56;
      path.lineTo(x.toDouble(), y);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AudioMeters extends StatelessWidget {
  const AudioMeters({super.key});

  @override
  Widget build(BuildContext context) {
    return const GlassPanel(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: ZirconColors.panelStrong,
      child: SizedBox(
        width: 118,
        height: 35,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _MeterRow(label: 'L', value: .67),
            _MeterRow(label: 'R', value: .53),
          ],
        ),
      ),
    );
  }
}

class _MeterRow extends StatelessWidget {
  const _MeterRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 10,
          child: Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 7,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  const ColoredBox(color: ZirconColors.stroke),
                  FractionallySizedBox(
                    widthFactor: value,
                    alignment: Alignment.centerLeft,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            ZirconColors.good,
                            ZirconColors.warning,
                            ZirconColors.record,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToolSpec {
  const _ToolSpec(this.tool, this.label, this.icon);

  final MonitorTool tool;
  final String label;
  final IconData icon;
}
