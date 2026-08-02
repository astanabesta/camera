import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../model/camera_ui_controller.dart';

class PreviewOverlays extends StatelessWidget {
  const PreviewOverlays({required this.controller, super.key});

  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _OverlayPainter(
          showGrid: controller.isToolEnabled(MonitorTool.grid),
          showFrameGuides: controller.isToolEnabled(MonitorTool.frameGuides),
          showZebra: controller.isToolEnabled(MonitorTool.zebra),
          showFalseColor: controller.isToolEnabled(MonitorTool.falseColor),
          showPeaking: controller.isToolEnabled(MonitorTool.peaking),
          guideRatio: controller.guideRatio.value,
        ),
        // Focus feedback is rendered at the actual tap point by
        // _TapFocusLayer. A permanent centre reticle is misleading after the
        // camera moves or the operator reframes.
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _FocusReticle extends StatelessWidget {
  const _FocusReticle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: ZirconColors.text.withValues(alpha: .7),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: SizedBox(
            width: 3,
            height: 3,
            child: ColoredBox(color: ZirconColors.accent),
          ),
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  const _OverlayPainter({
    required this.showGrid,
    required this.showFrameGuides,
    required this.showZebra,
    required this.showFalseColor,
    required this.showPeaking,
    required this.guideRatio,
  });

  final bool showGrid;
  final bool showFrameGuides;
  final bool showZebra;
  final bool showFalseColor;
  final bool showPeaking;
  final double guideRatio;

  @override
  void paint(Canvas canvas, Size size) {
    if (showFalseColor) _drawFalseColorHint(canvas, size);
    if (showGrid) _drawGrid(canvas, size);
    if (showFrameGuides) _drawFrameGuides(canvas, size);
    if (showZebra) _drawZebraHint(canvas, size);
    if (showPeaking) _drawPeakingHint(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: .24)
      ..strokeWidth = .65;
    for (int i = 1; i < 3; i++) {
      final double x = size.width * i / 3;
      final double y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawFrameGuides(Canvas canvas, Size size) {
    final double guideHeight = size.width / guideRatio;
    if (guideHeight >= size.height) return;
    final double top = (size.height - guideHeight) / 2;
    final Paint shade = Paint()..color = Colors.black.withValues(alpha: .22);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, top), shade);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - top, size.width, top),
      shade,
    );
    final Paint line = Paint()
      ..color = ZirconColors.text.withValues(alpha: .6)
      ..strokeWidth = .8
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromLTWH(0, top, size.width, guideHeight), line);
  }

  void _drawFalseColorHint(Canvas canvas, Size size) {
    final Paint paint = Paint();
    paint.color = const Color(0x40563DFF);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * .68, size.width, size.height * .32),
      paint,
    );
    paint.color = const Color(0x38E6D445);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .53, size.height * .52),
        width: size.width * .34,
        height: size.height * .24,
      ),
      paint,
    );
    paint.color = const Color(0x36FF3C48);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * .76,
        size.height * .07,
        size.width * .2,
        size.height * .19,
      ),
      paint,
    );
  }

  void _drawZebraHint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = ZirconColors.warning.withValues(alpha: .35)
      ..strokeWidth = 2;
    final Rect zone = Rect.fromLTWH(
      size.width * .76,
      size.height * .1,
      size.width * .17,
      size.height * .18,
    );
    canvas.save();
    canvas.clipRect(zone);
    for (double x = zone.left - zone.height; x < zone.right; x += 8) {
      canvas.drawLine(
        Offset(x, zone.bottom),
        Offset(x + zone.height, zone.top),
        paint,
      );
    }
    canvas.restore();
  }

  void _drawPeakingHint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = ZirconColors.record.withValues(alpha: .72)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final Path path = Path()
      ..moveTo(size.width * .18, size.height * .62)
      ..lineTo(size.width * .24, size.height * .52)
      ..lineTo(size.width * .31, size.height * .58)
      ..lineTo(size.width * .38, size.height * .43);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) {
    return showGrid != oldDelegate.showGrid ||
        showFrameGuides != oldDelegate.showFrameGuides ||
        showZebra != oldDelegate.showZebra ||
        showFalseColor != oldDelegate.showFalseColor ||
        showPeaking != oldDelegate.showPeaking ||
        guideRatio != oldDelegate.guideRatio;
  }
}
