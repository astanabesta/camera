import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zircon_cinema_ui/src/app.dart';
import 'package:zircon_cinema_ui/src/model/camera_ui_controller.dart';
import 'package:zircon_cinema_ui/src/widgets/side_rail.dart';

void main() {
  test('controller enforces monitoring and recording safety rules', () {
    final CameraUiController controller = CameraUiController(
      allowSimulation: true,
    );
    expect(controller.section, AppSection.camera);
    expect(controller.recording, isFalse);
    expect(controller.fps, '30');
    expect(controller.timecode, '00:00:00:00');

    controller.setNumericControlValue(CameraControl.iso, 3);
    expect(controller.iso, '400');
    controller.setNumericControlValue(CameraControl.iso, 6);
    expect(controller.iso, '3200');
    controller.setControlAuto(CameraControl.iso, true);
    expect(controller.iso, 'AUTO');
    controller.setNumericControlValue(CameraControl.shutter, 172.8);
    expect(controller.shutter, '172.8°');
    controller.setNumericControlValue(
      CameraControl.exposureCompensation,
      1 / 3,
    );
    expect(controller.valueFor(CameraControl.exposureCompensation), '+0.3 EV');

    controller.setZoomRatio(2.0, rampDurationMs: 800);
    expect(controller.zoomRatio, 2.0);
    expect(
      controller.numericControlValue(CameraControl.zoom),
      closeTo(1.0, .001),
    );
    controller.setNumericControlValue(CameraControl.zoom, 2.0);
    expect(controller.zoomRatio, closeTo(4.0, .001));
    controller.toggleMonitorTool(MonitorTool.zebra);
    controller.toggleMonitorTool(MonitorTool.falseColor);
    expect(controller.isToolEnabled(MonitorTool.falseColor), isTrue);
    expect(controller.isToolEnabled(MonitorTool.zebra), isFalse);

    expect(controller.controlsLocked, isFalse);
    controller.setLockControlsWhileRecording(true);
    controller.toggleRecording();
    expect(controller.controlsLocked, isTrue);
    controller.setControlValue(CameraControl.iso, '800');
    expect(controller.iso, 'AUTO');
    controller.setSection(AppSection.media);
    expect(controller.section, AppSection.camera);
    controller.toggleRecording();
    controller.dispose();
  });

  test('master mode and tap focus keep explicit camera state', () async {
    final CameraUiController controller = CameraUiController(
      allowSimulation: true,
    );
    expect(controller.operationMode, CameraOperationMode.auto);

    controller.setMasterAuto(false);
    expect(controller.operationMode, CameraOperationMode.manual);
    expect(controller.iso, '50');
    expect(controller.focus, '∞');
    expect(controller.whiteBalance, '5600K');

    controller.setControlAuto(CameraControl.focus, true);
    expect(controller.operationMode, CameraOperationMode.mixed);
    await controller.tapToFocus(.25, .75, lock: true);
    expect(controller.focusPoint, const Offset(.25, .75));
    expect(controller.focusUiState, FocusUiState.locked);
    expect(controller.aeAfLocked, isTrue);

    controller.setMasterAuto(true);
    expect(controller.operationMode, CameraOperationMode.auto);
    expect(controller.sharpnessMode, SharpnessMode.off);
    expect(controller.noiseReductionMode, NoiseReductionMode.minimal);
    controller.setSharpnessMode(SharpnessMode.highQuality);
    controller.setNoiseReductionMode(NoiseReductionMode.off);
    expect(controller.sharpnessMode, SharpnessMode.highQuality);
    expect(controller.noiseReductionMode, NoiseReductionMode.off);
    controller.setRecordingMode(RecordingMode.fhd30);
    controller.setBitratePreset(BitratePreset.max);
    controller.setStabilizationMode(StabilizationMode.electronic);
    expect(controller.resolution, 'FHD');
    expect(controller.fps, '30');
    expect(controller.codec, 'HEVC 100 Mb/s');
    expect(controller.stabilizationMode, StabilizationMode.electronic);
    expect(controller.zoomSpeed, ZoomSpeed.slow);
    expect(ZoomSpeed.slow.targetRateStopsPerSecond, 1.35);
    expect(ZoomSpeed.slow.holdRateStopsPerSecond, .70);
    controller.setZoomSpeed(ZoomSpeed.medium);
    expect(controller.zoomSpeed, ZoomSpeed.medium);
    expect(ZoomSpeed.medium.multiplier, 2.25);
    expect(ZoomSpeed.fast.multiplier, 3.5);
    expect(
      ZoomSpeed.medium.targetRateStopsPerSecond /
          ZoomSpeed.slow.targetRateStopsPerSecond,
      closeTo(2.25, .0001),
    );
    expect(
      ZoomSpeed.fast.targetRateStopsPerSecond /
          ZoomSpeed.slow.targetRateStopsPerSecond,
      closeTo(3.5, .0001),
    );
    controller.dispose();
  });

  testWidgets('full UI works at the target landscape logical size', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(904, 407));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final CameraUiController controller = CameraUiController(
      allowSimulation: true,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(ZirconCinemaApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.textContaining('ZIRCON TEST 01'), findsWidgets);
    expect(find.textContaining('HEVC 80 Mb/s'), findsOneWidget);
    expect(find.text('FPS'), findsOneWidget);
    expect(find.text('ISO'), findsNothing);
    expect(find.text('SHUTTER'), findsNothing);
    expect(find.text('WB'), findsNothing);
    expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('FPS'));
    await tester.pumpAndSettle();
    expect(find.text('24/25 UNQUALIFIED'), findsOneWidget);
    expect(find.text('24 🔒'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('FPS').first);
    await tester.pumpAndSettle();
    controller.setMasterAuto(false);
    await tester.pumpAndSettle();
    expect(find.text('ISO'), findsOneWidget);
    expect(find.text('SHUTTER'), findsOneWidget);
    expect(find.text('WB'), findsOneWidget);
    await tester.tap(find.text('ISO'));
    await tester.pumpAndSettle();
    expect(find.text('50–3200 • 800 ANALOG MAX'), findsOneWidget);
    expect(find.text('AUTO'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.video_library_outlined));
    await tester.pumpAndSettle();
    expect(find.text('MEDIA'), findsWidgets);
    expect(find.text('CLIP METADATA'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    expect(find.text('SETTINGS'), findsWidgets);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Codec'), findsOneWidget);
    expect(find.text('4K'), findsOneWidget);
    expect(find.text('1080p'), findsOneWidget);
    expect(find.text('4:3 1440p'), findsOneWidget);
    expect(find.textContaining('Max 100 Mb/s'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Zoom Speed'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Zoom Speed'), findsOneWidget);
    expect(find.text('Slow'), findsOneWidget);
    expect(find.text('Medium 2.25×'), findsOneWidget);
    expect(find.text('Fast 3.5×'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Monitor'));
    await tester.pumpAndSettle();
    expect(find.text('Frame Guides'), findsOneWidget);
    expect(find.text('False Color'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Processing'));
    await tester.pumpAndSettle();
    expect(find.text('Sharpness'), findsOneWidget);
    expect(find.text('Noise Reduction'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.videocam_outlined).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ZOOM').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('SLOW • LOG₂'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(RecordButton));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('STOP'), findsOneWidget);
    await tester.tap(find.text('FPS'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('24/25 UNQUALIFIED'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(RecordButton));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('REC'), findsOneWidget);
  });

  testWidgets('camera reflows into a functional portrait interface', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(407, 904));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final CameraUiController controller = CameraUiController(
      allowSimulation: true,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(ZirconCinemaApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.stay_current_portrait_rounded), findsOneWidget);
    expect(find.byIcon(Icons.stay_current_landscape_rounded), findsOneWidget);
    expect(find.text('MEDIA'), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.byType(RecordButton), findsOneWidget);
    expect(find.byIcon(Icons.storage_rounded), findsOneWidget);
    expect(
      tester.getCenter(find.byIcon(Icons.storage_rounded)).dy,
      greaterThan(770),
    );
    expect(tester.takeException(), isNull);

    controller.setMasterAuto(false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ISO'));
    await tester.pumpAndSettle();
    expect(find.text('50–3200 • 800 ANALOG MAX'), findsOneWidget);
    expect(find.text('MANUAL'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
