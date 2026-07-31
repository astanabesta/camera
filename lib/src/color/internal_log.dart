import 'dart:math' as math;

enum ZirconImageProfile {
  standard('Standard'),
  natural('Natural'),
  flat('Flat'),
  cine('Cine'),
  internalLog('Internal LOG');

  const ZirconImageProfile(this.label);

  final String label;
}

/// Original scene-linear transfer function designed for Zircon Camera.
///
/// Input is non-negative scene-linear exposure relative to 18% middle gray:
/// `1.0` means middle gray, `2.0` is one stop above, and `0.5` is one stop
/// below. The function is deliberately based on a generic inverse-hyperbolic
/// sine rather than any manufacturer's Log curve.
///
/// Design anchors:
/// - black -> 0.0
/// - 18% middle gray -> 0.5
/// - +4 stops -> 0.94
/// - encoded ceiling -> approximately +4.545 stops
///
/// This transfer is not active in the current direct-ISP 8-bit recorder. It is
/// the tested mathematical foundation for the future RAW/P010 GPU pipeline.
abstract final class ZirconInternalLog {
  static const String curveId = 'ZIRCON_INTERNAL_LOG_V1_DRAFT';
  static const double _k = 11.63004979866391;
  static const double _scale = 0.15880161218454827;

  static double encode(double relativeLinear) {
    if (!relativeLinear.isFinite || relativeLinear <= 0) return 0;
    return (_scale * _asinh(_k * relativeLinear)).clamp(0.0, 1.0).toDouble();
  }

  static double decode(double encoded) {
    if (!encoded.isFinite || encoded <= 0) return 0;
    final double y = encoded.clamp(0.0, 1.0).toDouble();
    return _sinh(y / _scale) / _k;
  }

  static int encodeLimited10Bit(double relativeLinear) {
    // ITU narrow-range 10-bit luma allocation: 64..940.
    return (64 + 876 * encode(relativeLinear)).round().clamp(64, 940).toInt();
  }

  static double decodeLimited10Bit(int codeValue) {
    final int code = codeValue.clamp(64, 940).toInt();
    return decode((code - 64) / 876.0);
  }

  static List<double> generateLinearToLogLut({int size = 4096}) {
    if (size < 2) throw ArgumentError.value(size, 'size', 'must be >= 2');
    // LUT domain spans black through the curve's encoded ceiling.
    final double maximumLinear = decode(1.0);
    return List<double>.generate(size, (int index) {
      final double x = maximumLinear * index / (size - 1);
      return encode(x);
    }, growable: false);
  }

  static double stopsFromMiddleGray(double relativeLinear) {
    if (relativeLinear <= 0) return double.negativeInfinity;
    return math.log(relativeLinear) / math.ln2;
  }

  static double relativeLinearFromStops(double stops) =>
      math.pow(2, stops).toDouble();

  static double _asinh(double x) => math.log(x + math.sqrt(x * x + 1));

  static double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;
}
