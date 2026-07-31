import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/tokens.dart';

class CinemaRulerPreset {
  const CinemaRulerPreset(this.value, this.label);

  final double value;
  final String label;
}

class CinemaRuler extends StatefulWidget {
  const CinemaRuler({
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.coarseStep,
    required this.fineStep,
    required this.formatValue,
    required this.onChanged,
    super.key,
    this.snapPoints = const <double>[],
    this.presets = const <CinemaRulerPreset>[],
    this.haptics = true,
    this.showFineMode = true,
    this.enabled = true,
  });

  final double value;
  final double minimum;
  final double maximum;
  final double coarseStep;
  final double fineStep;
  final String Function(double value) formatValue;
  final ValueChanged<double> onChanged;
  final List<double> snapPoints;
  final List<CinemaRulerPreset> presets;
  final bool haptics;
  final bool showFineMode;
  final bool enabled;

  @override
  State<CinemaRuler> createState() => _CinemaRulerState();
}

class _CinemaRulerState extends State<CinemaRuler> {
  bool _fine = false;
  double _dragRemainder = 0;

  double get _step => _fine ? widget.fineStep : widget.coarseStep;
  double get _pixelsPerStep => _fine ? 18 : 8;

  @override
  Widget build(BuildContext context) {
    final Color active = widget.enabled
        ? ZirconColors.accent
        : ZirconColors.textDim;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            _NudgeButton(
              icon: Icons.remove_rounded,
              enabled: widget.enabled && widget.value > widget.minimum,
              onTap: () => _nudge(-1),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: widget.enabled
                    ? (_) {
                        _dragRemainder = 0;
                        if (widget.haptics) HapticFeedback.selectionClick();
                      }
                    : null,
                onHorizontalDragUpdate: widget.enabled
                    ? _handleHorizontalDrag
                    : null,
                onHorizontalDragEnd: widget.enabled
                    ? _handleHorizontalDragEnd
                    : null,
                child: Container(
                  height: 62,
                  decoration: BoxDecoration(
                    color: ZirconColors.panelSoft,
                    borderRadius: BorderRadius.circular(ZirconRadius.md),
                    border: Border.all(color: ZirconColors.strokeSoft),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      CustomPaint(
                        painter: _CinemaRulerPainter(
                          value: widget.value,
                          minimum: widget.minimum,
                          maximum: widget.maximum,
                          step: _step,
                          formatValue: widget.formatValue,
                          color: active,
                        ),
                      ),
                      Align(
                        alignment: Alignment.topCenter,
                        child: Container(width: 2, height: 43, color: active),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          transform: Matrix4.translationValues(0, 1, 0),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: ZirconColors.panelStrong,
                            border: Border.all(color: active),
                            borderRadius: BorderRadius.circular(
                              ZirconRadius.pill,
                            ),
                          ),
                          child: Text(
                            widget.formatValue(widget.value),
                            style: TextStyle(
                              color: active,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .25,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 7),
            _NudgeButton(
              icon: Icons.add_rounded,
              enabled: widget.enabled && widget.value < widget.maximum,
              onTap: () => _nudge(1),
            ),
            if (widget.showFineMode) ...<Widget>[
              const SizedBox(width: 7),
              SizedBox(
                width: 54,
                height: 42,
                child: Material(
                  color: _fine
                      ? ZirconColors.accentSoft
                      : ZirconColors.panelSoft,
                  borderRadius: BorderRadius.circular(ZirconRadius.sm),
                  child: InkWell(
                    onTap: widget.enabled
                        ? () {
                            setState(() => _fine = !_fine);
                            if (widget.haptics) {
                              HapticFeedback.mediumImpact();
                            }
                          }
                        : null,
                    borderRadius: BorderRadius.circular(ZirconRadius.sm),
                    child: Center(
                      child: Text(
                        _fine ? 'FINE' : 'COARSE',
                        style: TextStyle(
                          color: _fine
                              ? ZirconColors.accent
                              : ZirconColors.textMuted,
                          fontSize: 7,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (widget.presets.isNotEmpty) ...<Widget>[
          const SizedBox(height: 7),
          SizedBox(
            height: 27,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.presets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 5),
              itemBuilder: (BuildContext context, int index) {
                final CinemaRulerPreset preset = widget.presets[index];
                final bool selected =
                    (preset.value - widget.value).abs() <= _step * .35;
                return Material(
                  color: selected
                      ? ZirconColors.accentSoft
                      : ZirconColors.panelSoft,
                  borderRadius: BorderRadius.circular(ZirconRadius.pill),
                  child: InkWell(
                    onTap: widget.enabled
                        ? () => _commit(preset.value, forceHaptic: true)
                        : null,
                    borderRadius: BorderRadius.circular(ZirconRadius.pill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selected
                              ? ZirconColors.accent
                              : ZirconColors.strokeSoft,
                        ),
                        borderRadius: BorderRadius.circular(ZirconRadius.pill),
                      ),
                      child: Text(
                        preset.label,
                        style: TextStyle(
                          color: selected
                              ? ZirconColors.accent
                              : ZirconColors.textMuted,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  void _handleHorizontalDrag(DragUpdateDetails details) {
    _dragRemainder += details.delta.dx;
    while (_dragRemainder.abs() >= _pixelsPerStep) {
      // Pulling the scale left increases the selected value.
      final int direction = _dragRemainder < 0 ? 1 : -1;
      _nudge(direction);
      _dragRemainder += direction * _pixelsPerStep;
    }
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() > 900) {
      final int direction = velocity < 0 ? 1 : -1;
      final int extraSteps = (velocity.abs() / 900).round().clamp(1, 4).toInt();
      for (int i = 0; i < extraSteps; i++) {
        _nudge(direction, haptic: false);
      }
      if (widget.haptics) HapticFeedback.selectionClick();
    }
    _dragRemainder = 0;
  }

  void _nudge(int direction, {bool haptic = true}) {
    _commit(
      widget.value + direction * _step,
      forceHaptic: haptic && widget.haptics,
    );
  }

  void _commit(double rawValue, {bool forceHaptic = false}) {
    double value = rawValue.clamp(widget.minimum, widget.maximum).toDouble();
    for (final double point in widget.snapPoints) {
      if ((value - point).abs() <= _step * .45) {
        value = point;
        break;
      }
    }
    if ((value - widget.value).abs() < _step * .01) return;
    widget.onChanged(value);
    if (forceHaptic) HapticFeedback.selectionClick();
  }
}

class _NudgeButton extends StatelessWidget {
  const _NudgeButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Material(
        color: ZirconColors.panelSoft,
        borderRadius: BorderRadius.circular(ZirconRadius.sm),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(ZirconRadius.sm),
          child: Icon(
            icon,
            color: enabled ? ZirconColors.text : ZirconColors.textDim,
            size: 19,
          ),
        ),
      ),
    );
  }
}

class _CinemaRulerPainter extends CustomPainter {
  const _CinemaRulerPainter({
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.step,
    required this.formatValue,
    required this.color,
  });

  final double value;
  final double minimum;
  final double maximum;
  final double step;
  final String Function(double value) formatValue;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const double spacing = 14;
    final Paint minorPaint = Paint()
      ..color = ZirconColors.textMuted.withValues(alpha: .55)
      ..strokeWidth = 1;
    final Paint majorPaint = Paint()
      ..color = color.withValues(alpha: .9)
      ..strokeWidth = 1.3;

    final int halfTicks = (size.width / spacing / 2).ceil() + 1;
    for (int i = -halfTicks; i <= halfTicks; i++) {
      final double tickValue = value + i * step;
      if (tickValue < minimum - step || tickValue > maximum + step) continue;
      final double x = size.width / 2 + i * spacing;
      final bool major = i % 5 == 0;
      final double top = major ? 8 : 15;
      final double bottom = major ? 34 : 29;
      canvas.drawLine(
        Offset(x, top),
        Offset(x, bottom),
        major ? majorPaint : minorPaint,
      );

      if (major && i != 0) {
        final TextPainter text = TextPainter(
          text: TextSpan(
            text: _shortLabel(formatValue(tickValue)),
            style: const TextStyle(
              color: ZirconColors.textDim,
              fontSize: 7,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: spacing * 4.5);
        text.paint(canvas, Offset(x - text.width / 2, 37));
      }
    }

    final Paint fadePaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[
          ZirconColors.panelStrong,
          Colors.transparent,
          Colors.transparent,
          ZirconColors.panelStrong,
        ],
        stops: <double>[0, .18, .82, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, fadePaint);
  }

  static String _shortLabel(String value) {
    return value
        .replaceAll('ISO ', '')
        .replaceAll(' EV', '')
        .replaceAll('°', '');
  }

  @override
  bool shouldRepaint(covariant _CinemaRulerPainter oldDelegate) {
    return value != oldDelegate.value ||
        step != oldDelegate.step ||
        minimum != oldDelegate.minimum ||
        maximum != oldDelegate.maximum ||
        color != oldDelegate.color;
  }
}
