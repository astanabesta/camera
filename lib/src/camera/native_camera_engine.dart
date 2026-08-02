import 'package:flutter/services.dart';

class CameraInitialization {
  const CameraInitialization({
    required this.textureId,
    required this.previewWidth,
    required this.previewHeight,
    required this.recordWidth,
    required this.recordHeight,
    required this.fps,
    required this.rotationDegrees,
    required this.engine,
    required this.recorder,
    required this.tintSupported,
    required this.minimumZoomRatio,
    required this.maximumZoomRatio,
  });

  factory CameraInitialization.fromMap(Map<Object?, Object?> map) {
    return CameraInitialization(
      textureId: _int(map['textureId']),
      previewWidth: _int(map['previewWidth']),
      previewHeight: _int(map['previewHeight']),
      recordWidth: _int(map['recordWidth']),
      recordHeight: _int(map['recordHeight']),
      fps: _int(map['fps']),
      rotationDegrees: _int(map['rotationDegrees']),
      engine: '${map['engine'] ?? 'Camera2'}',
      recorder: '${map['recorder'] ?? 'MediaRecorder'}',
      tintSupported: map['tintSupported'] == true,
      minimumZoomRatio: _double(map['minimumZoomRatio'], 1.0),
      maximumZoomRatio: _double(map['maximumZoomRatio'], 10.0),
    );
  }

  final int textureId;
  final int previewWidth;
  final int previewHeight;
  final int recordWidth;
  final int recordHeight;
  final int fps;
  final int rotationDegrees;
  final String engine;
  final String recorder;
  final bool tintSupported;
  final double minimumZoomRatio;
  final double maximumZoomRatio;

  static int _int(Object? value) => value is num ? value.toInt() : 0;
  static double _double(Object? value, double fallback) =>
      value is num ? value.toDouble() : fallback;
}

class NativeCameraEngine {
  static const MethodChannel _methods = MethodChannel(
    'ai.arena.zirconcinema/camera',
  );
  static const EventChannel _events = EventChannel(
    'ai.arena.zirconcinema/camera_events',
  );

  Stream<Map<Object?, Object?>>? _eventStream;

  Stream<Map<Object?, Object?>> get events {
    return _eventStream ??= _events
        .receiveBroadcastStream()
        .where((Object? event) => event is Map)
        .cast<Map<Object?, Object?>>();
  }

  Future<CameraInitialization> initialize() async {
    final Map<Object?, Object?> response = await _invokeMap('initialize', null);
    return CameraInitialization.fromMap(response);
  }

  Future<void> setControls(Map<String, Object> controls) async {
    await _methods.invokeMethod<void>('setControls', controls);
  }

  Future<Map<Object?, Object?>> setZoomTarget(
    double zoomRatio, {
    required double targetRateStopsPerSecond,
    required double accelerationStopsPerSecondSquared,
  }) {
    return _invokeMap('setZoomTarget', <String, Object>{
      'zoomRatio': zoomRatio,
      'zoomTargetRateStopsPerSecond': targetRateStopsPerSecond,
      'zoomAccelerationStopsPerSecondSquared':
          accelerationStopsPerSecondSquared,
    });
  }

  Future<void> setVolumeZoomEnabled(bool enabled) {
    return _methods.invokeMethod<void>('setVolumeZoomEnabled', <String, Object>{
      'enabled': enabled,
    });
  }

  Future<Map<Object?, Object?>> getOrientation() {
    return _invokeMap('getOrientation', null);
  }

  Future<Map<Object?, Object?>> tapToFocus({
    required double x,
    required double y,
    bool lock = false,
  }) {
    return _invokeMap('tapToFocus', <String, Object>{
      'x': x.clamp(0.0, 1.0),
      'y': y.clamp(0.0, 1.0),
      'lock': lock,
    });
  }

  Future<Map<Object?, Object?>> setAeAfLock(bool locked) {
    return _invokeMap('setAeAfLock', <String, Object>{'locked': locked});
  }

  Future<Map<Object?, Object?>> runTenBitRec709Preflight() {
    return _invokeMap('runTenBitRec709Preflight', null);
  }

  Future<Map<Object?, Object?>> runTenBitRec709SessionTest() {
    return _invokeMap('runTenBitRec709SessionTest', null);
  }

  Future<Map<Object?, Object?>> runTenBitDiagnosticRecording() {
    return _invokeMap('runTenBitDiagnosticRecording', null);
  }

  Future<Map<Object?, Object?>> startRecording() {
    return _invokeMap('startRecording', null);
  }

  Future<Map<Object?, Object?>> stopRecording() {
    return _invokeMap('stopRecording', null);
  }

  Future<void> pause() => _methods.invokeMethod<void>('pause');

  Future<void> resume() => _methods.invokeMethod<void>('resume');

  Future<String?> openLastClip() {
    return _methods.invokeMethod<String>('openLastClip');
  }

  Future<void> dispose() => _methods.invokeMethod<void>('dispose');

  Future<Map<Object?, Object?>> _invokeMap(
    String method,
    Object? arguments,
  ) async {
    final Object? response = await _methods.invokeMethod<Object?>(
      method,
      arguments,
    );
    if (response is Map<Object?, Object?>) return response;
    throw PlatformException(
      code: 'INVALID_RESPONSE',
      message: '$method did not return a map',
      details: response,
    );
  }
}
