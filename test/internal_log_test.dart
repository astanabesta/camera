import 'package:flutter_test/flutter_test.dart';
import 'package:zircon_cinema_ui/src/color/internal_log.dart';

void main() {
  test('Internal LOG v1 draft meets its design anchors', () {
    expect(ZirconInternalLog.encode(0), 0);
    expect(ZirconInternalLog.encode(1), closeTo(.5, 1e-12));
    expect(ZirconInternalLog.encode(16), closeTo(.94, 1e-12));
    expect(ZirconInternalLog.decode(.5), closeTo(1, 1e-12));
  });

  test('Internal LOG round trips scene-linear exposure', () {
    for (final double stops in <double>[-8, -6, -4, -2, 0, 2, 4]) {
      final double source = ZirconInternalLog.relativeLinearFromStops(stops);
      final double decoded = ZirconInternalLog.decode(
        ZirconInternalLog.encode(source),
      );
      expect(decoded, closeTo(source, source * 1e-10 + 1e-12));
    }
  });

  test('10-bit limited mapping stays legal and monotonic', () {
    int previous = 63;
    for (int i = 0; i <= 1024; i++) {
      final double source = i / 64;
      final int code = ZirconInternalLog.encodeLimited10Bit(source);
      expect(code, inInclusiveRange(64, 940));
      expect(code, greaterThanOrEqualTo(previous));
      previous = code;
    }
    expect(ZirconInternalLog.encodeLimited10Bit(1), 502);
  });
}
