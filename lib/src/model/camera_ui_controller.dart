import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../camera/native_camera_engine.dart';

enum AppSection { camera, media, settings }

enum CameraOperationMode { auto, manual, mixed }

enum CaptureOrientation { portrait, landscape }

enum SharpnessMode {
  off('Off', 0),
  fast('Fast', 1),
  highQuality('High Quality', 2);

  const SharpnessMode(this.label, this.camera2Value);
  final String label;
  final int camera2Value;
}

enum NoiseReductionMode {
  off('Off', 0),
  minimal('Minimal', 3),
  highQuality('High Quality', 2);

  const NoiseReductionMode(this.label, this.camera2Value);
  final String label;
  final int camera2Value;
}

enum FocusUiState { hidden, scanning, focused, failed, locked }

enum CameraControl {
  lens,
  fps,
  shutter,
  iso,
  whiteBalance,
  tint,
  focus,
  exposureCompensation,
  zoom,
}

enum MonitorTool {
  frameGuides,
  grid,
  zebra,
  falseColor,
  peaking,
  waveform,
  histogram,
  cleanFeed,
}

enum GuideRatio {
  ratio239('2.39:1', 2.39),
  ratio185('1.85:1', 1.85),
  ratio169('16:9', 16 / 9),
  ratio43('4:3', 4 / 3);

  const GuideRatio(this.label, this.value);

  final String label;
  final double value;
}

enum SettingsPage {
  record,
  camera,
  processing,
  audio,
  monitor,
  liveStream,
  media,
  functionButtons,
  luts,
}

enum CameraRuntimeState {
  idle,
  requestingPermissions,
  opening,
  ready,
  preparingRecording,
  recording,
  paused,
  error,
}

class CameraUiController extends ChangeNotifier {
  CameraUiController({
    NativeCameraEngine? nativeCamera,
    this.allowSimulation = false,
  }) : _nativeCamera = nativeCamera ?? NativeCameraEngine();

  final NativeCameraEngine _nativeCamera;
  final bool allowSimulation;

  AppSection _section = AppSection.camera;
  CameraControl? _activeControl;
  SettingsPage _settingsPage = SettingsPage.record;
  GuideRatio _guideRatio = GuideRatio.ratio239;
  CameraRuntimeState _runtimeState = CameraRuntimeState.idle;
  CameraInitialization? _cameraInitialization;
  StreamSubscription<Map<Object?, Object?>>? _cameraEvents;
  bool _recording = false;
  bool _recordBusy = false;
  bool _lockControlsWhileRecording = false;
  bool _showValidationLabels = true;
  bool _preventAccidentalChanges = true;
  bool _hapticControlFeedback = true;
  Duration _recorded = Duration.zero;
  Timer? _timer;
  Timer? _controlApplyDebounce;
  int _clipCounter = 1;
  String? _cameraError;
  String? _lastClipUri;
  int? _actualIso;
  int? _actualExposureTimeNs;
  int? _actualFrameDurationNs;
  int? _actualRollingShutterSkewNs;
  double? _actualFocusDistanceDiopters;
  double? _actualZoomRatio;
  int _manualIso = 50;
  double _manualFocusDiopters = 0.0;
  double _exposureCompensationEv = 0.0;
  double _zoomRatio = 1.0;
  bool _zoomCommandInFlight = false;
  double? _pendingZoomCommand;
  double? _measuredPreviewFps;
  double? _zoomVelocityStopsPerSecond;
  int _captureFrameGaps = 0;
  String _manualWhiteBalance = '5600K';
  Offset? _focusPoint;
  FocusUiState _focusUiState = FocusUiState.hidden;
  bool _aeAfLocked = false;
  int? _actualAfState;
  CaptureOrientation? _orientationPreference;
  int? _batteryPercent;
  bool _batteryCharging = false;
  int? _storageAvailableBytes;
  int? _storageTotalBytes;
  double? _levelRollDegrees;
  double? _levelPitchDegrees;
  double? _audioLevelDbfs;
  SharpnessMode _sharpnessMode = SharpnessMode.off;
  NoiseReductionMode _noiseReductionMode = NoiseReductionMode.minimal;
  int? _actualEdgeMode;
  int? _actualNoiseReductionMode;

  String lens = 'MAIN';
  String fps = '30';
  String shutter = '180°';
  String iso = 'AUTO';
  String whiteBalance = 'AUTO';
  String tint = '+0';
  String focus = 'AUTO';
  String project = 'ZIRCON TEST 01';
  String codec = 'HEVC 80 Mb/s';
  String resolution = 'UHD';
  String profile = 'DIRECT ISP';

  final Set<MonitorTool> _enabledTools = <MonitorTool>{
    MonitorTool.frameGuides,
    MonitorTool.grid,
    MonitorTool.waveform,
  };

  AppSection get section => _section;
  CameraControl? get activeControl => _activeControl;
  SettingsPage get settingsPage => _settingsPage;
  GuideRatio get guideRatio => _guideRatio;
  CameraRuntimeState get runtimeState => _runtimeState;
  bool get recording => _recording;
  bool get recordBusy => _recordBusy;
  bool get cameraReady =>
      allowSimulation ||
      _runtimeState == CameraRuntimeState.ready ||
      _runtimeState == CameraRuntimeState.recording;
  bool get controlsLocked => _recording && _lockControlsWhileRecording;
  bool get lockControlsWhileRecording => _lockControlsWhileRecording;
  bool get showValidationLabels => _showValidationLabels;
  bool get preventAccidentalChanges => _preventAccidentalChanges;
  bool get hapticControlFeedback => _hapticControlFeedback;
  bool get cleanFeed => _enabledTools.contains(MonitorTool.cleanFeed);
  bool get canRecord => (cameraReady || allowSimulation) && !_recordBusy;
  Duration get recorded => _recorded;
  int? get textureId => _cameraInitialization?.textureId;
  int get previewWidth => _cameraInitialization?.previewWidth ?? 1920;
  int get previewHeight => _cameraInitialization?.previewHeight ?? 1080;
  int get previewQuarterTurns =>
      ((_cameraInitialization?.rotationDegrees ?? 0) ~/ 90) % 4;
  String? get cameraError => _cameraError;
  String? get lastClipUri => _lastClipUri;
  int? get actualIso => _actualIso;
  int? get actualExposureTimeNs => _actualExposureTimeNs;
  int? get actualFrameDurationNs => _actualFrameDurationNs;
  int? get actualRollingShutterSkewNs => _actualRollingShutterSkewNs;
  double? get actualFocusDistanceDiopters => _actualFocusDistanceDiopters;
  double? get actualZoomRatio => _actualZoomRatio;
  int get manualIso => _manualIso;
  double get manualFocusDiopters => _manualFocusDiopters;
  double get exposureCompensationEv => _exposureCompensationEv;
  double get zoomRatio => _zoomRatio;
  double get minimumZoomRatio => _cameraInitialization?.minimumZoomRatio ?? 1.0;
  double get maximumZoomRatio =>
      _cameraInitialization?.maximumZoomRatio ?? 10.0;
  double? get measuredPreviewFps => _measuredPreviewFps;
  double? get zoomVelocityStopsPerSecond => _zoomVelocityStopsPerSecond;
  int get captureFrameGaps => _captureFrameGaps;
  String get manualWhiteBalance => _manualWhiteBalance;
  Offset? get focusPoint => _focusPoint;
  FocusUiState get focusUiState => _focusUiState;
  bool get aeAfLocked => _aeAfLocked;
  int? get actualAfState => _actualAfState;
  CaptureOrientation? get orientationPreference => _orientationPreference;
  int? get batteryPercent => _batteryPercent;
  bool get batteryCharging => _batteryCharging;
  int? get storageAvailableBytes => _storageAvailableBytes;
  int? get storageTotalBytes => _storageTotalBytes;
  double? get levelRollDegrees => _levelRollDegrees;
  double? get levelPitchDegrees => _levelPitchDegrees;
  double? get audioLevelDbfs => _audioLevelDbfs;
  SharpnessMode get sharpnessMode => _sharpnessMode;
  NoiseReductionMode get noiseReductionMode => _noiseReductionMode;
  int? get actualEdgeMode => _actualEdgeMode;
  int? get actualNoiseReductionMode => _actualNoiseReductionMode;
  String get storageAvailableLabel =>
      _formatBytes(_storageAvailableBytes, fallback: '—');
  String get storageTotalLabel =>
      _formatBytes(_storageTotalBytes, fallback: '—');
  double? get storageFreeFraction {
    final int? available = _storageAvailableBytes;
    final int? total = _storageTotalBytes;
    if (available == null || total == null || total <= 0) return null;
    return (available / total).clamp(0.0, 1.0).toDouble();
  }

  String get actualSharpnessLabel => _actualEdgeMode == null
      ? 'Waiting for Camera2 result'
      : switch (_actualEdgeMode) {
          0 => 'Off',
          1 => 'Fast',
          2 => 'High Quality',
          3 => 'Zero Shutter Lag',
          _ => 'Mode $_actualEdgeMode',
        };
  String get actualNoiseReductionLabel => _actualNoiseReductionMode == null
      ? 'Waiting for Camera2 result'
      : switch (_actualNoiseReductionMode) {
          0 => 'Off',
          1 => 'Fast',
          2 => 'High Quality',
          3 => 'Minimal',
          4 => 'Zero Shutter Lag',
          _ => 'Mode $_actualNoiseReductionMode',
        };
  CameraOperationMode get operationMode {
    final bool exposureAuto = iso == 'AUTO';
    final bool focusAuto = focus == 'AUTO';
    final bool wbAuto = whiteBalance == 'AUTO';
    if (exposureAuto && focusAuto && wbAuto) return CameraOperationMode.auto;
    if (!exposureAuto && !focusAuto && !wbAuto) {
      return CameraOperationMode.manual;
    }
    return CameraOperationMode.mixed;
  }

  Set<MonitorTool> get enabledTools =>
      Set<MonitorTool>.unmodifiable(_enabledTools);
  String get clipName => 'ZC_A001_C${_clipCounter.toString().padLeft(3, '0')}';

  int get nominalFps => int.tryParse(fps) ?? 30;

  String get timecode {
    final int totalFrames = (_recorded.inMicroseconds * nominalFps / 1000000)
        .floor();
    final int frames = totalFrames % nominalFps;
    final int totalSeconds = totalFrames ~/ nominalFps;
    final int seconds = totalSeconds % 60;
    final int minutes = (totalSeconds ~/ 60) % 60;
    final int hours = totalSeconds ~/ 3600;
    return '${_two(hours)}:${_two(minutes)}:${_two(seconds)}:${_two(frames)}';
  }

  String get runtimeLabel => switch (_runtimeState) {
    CameraRuntimeState.idle => 'CAMERA IDLE',
    CameraRuntimeState.requestingPermissions => 'ALLOW CAMERA + MIC',
    CameraRuntimeState.opening => 'OPENING CAMERA 0',
    CameraRuntimeState.ready => 'CAMERA2 READY',
    CameraRuntimeState.preparingRecording => 'PREPARING UHD',
    CameraRuntimeState.recording => 'RECORDING UHD30',
    CameraRuntimeState.paused => 'CAMERA PAUSED',
    CameraRuntimeState.error => 'CAMERA ERROR',
  };

  String get actualExposureLabel {
    final int? exposureNs = _actualExposureTimeNs;
    if (exposureNs == null || exposureNs <= 0) return '—';
    final double denominator = 1000000000 / exposureNs;
    if (denominator >= 1) return '1/${denominator.round()}';
    return '${(exposureNs / 1000000000).toStringAsFixed(2)}s';
  }

  Future<void> initializeCamera() async {
    if (allowSimulation || _runtimeState != CameraRuntimeState.idle) return;
    _runtimeState = CameraRuntimeState.requestingPermissions;
    _cameraError = null;
    notifyListeners();
    _cameraEvents ??= _nativeCamera.events.listen(
      _handleCameraEvent,
      onError: (Object error, StackTrace stackTrace) {
        _runtimeState = CameraRuntimeState.error;
        _cameraError = '$error';
        notifyListeners();
      },
    );
    try {
      _cameraInitialization = await _nativeCamera.initialize();
      _runtimeState = CameraRuntimeState.ready;
      _cameraError = null;
      await _applyNativeControls();
    } catch (error) {
      _runtimeState = CameraRuntimeState.error;
      _cameraError = _friendlyPlatformError(error);
    }
    notifyListeners();
  }

  Future<void> retryCamera() async {
    if (allowSimulation || _recording || _recordBusy) return;
    _cameraInitialization = null;
    _cameraError = null;
    _runtimeState = CameraRuntimeState.idle;
    notifyListeners();
    await initializeCamera();
  }

  Future<void> pauseCamera() async {
    if (allowSimulation || _cameraInitialization == null) return;
    try {
      await _nativeCamera.pause();
    } catch (_) {
      // Native lifecycle handling is authoritative; this is best effort.
    }
  }

  Future<void> resumeCamera() async {
    if (allowSimulation || _cameraInitialization == null) return;
    try {
      await _nativeCamera.resume();
    } catch (error) {
      _cameraError = _friendlyPlatformError(error);
      notifyListeners();
    }
  }

  void setSection(AppSection value) {
    if (_section == value || (_recording && value != AppSection.camera)) return;
    _section = value;
    _activeControl = null;
    notifyListeners();
  }

  Future<void> setCaptureOrientation(CaptureOrientation value) async {
    _orientationPreference = value;
    notifyListeners();
    await SystemChrome.setPreferredOrientations(
      value == CaptureOrientation.portrait
          ? <DeviceOrientation>[
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ]
          : <DeviceOrientation>[
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ],
    );
  }

  void setSharpnessMode(SharpnessMode value) {
    if (_sharpnessMode == value) return;
    _sharpnessMode = value;
    notifyListeners();
    _scheduleNativeControlApply();
  }

  void setNoiseReductionMode(NoiseReductionMode value) {
    if (_noiseReductionMode == value) return;
    _noiseReductionMode = value;
    notifyListeners();
    _scheduleNativeControlApply();
  }

  void setSettingsPage(SettingsPage value) {
    if (_settingsPage == value) return;
    _settingsPage = value;
    notifyListeners();
  }

  void selectControl(CameraControl value) {
    if (controlsLocked || !isControlAvailable(value)) return;
    _activeControl = _activeControl == value ? null : value;
    notifyListeners();
  }

  bool isControlAvailable(CameraControl control) {
    if (control == CameraControl.tint) {
      return _cameraInitialization?.tintSupported ?? allowSimulation;
    }
    if (control == CameraControl.exposureCompensation) {
      return iso == 'AUTO';
    }
    return true;
  }

  bool isControlValueSupported(CameraControl control, String value) {
    if (control == CameraControl.fps) return value == '30';
    return true;
  }

  void closeControl() {
    if (_activeControl == null) return;
    _activeControl = null;
    notifyListeners();
  }

  void setControlValue(CameraControl control, String value) {
    if (controlsLocked ||
        !isControlAvailable(control) ||
        !isControlValueSupported(control, value)) {
      return;
    }
    switch (control) {
      case CameraControl.lens:
        lens = value;
        break;
      case CameraControl.fps:
        fps = value;
        break;
      case CameraControl.shutter:
        shutter = value;
        break;
      case CameraControl.iso:
        iso = value;
        final int? parsedIso = int.tryParse(value);
        if (parsedIso != null) _manualIso = parsedIso;
        break;
      case CameraControl.whiteBalance:
        whiteBalance = value;
        if (value != 'AUTO') _manualWhiteBalance = value;
        break;
      case CameraControl.tint:
        tint = value;
        break;
      case CameraControl.focus:
        focus = value;
        if (value != 'AUTO') {
          _manualFocusDiopters = _focusDistanceForUiValue(value);
        }
        break;
      case CameraControl.exposureCompensation:
        _exposureCompensationEv =
            double.tryParse(value.replaceAll('+', '')) ?? 0.0;
        break;
      case CameraControl.zoom:
        _zoomRatio = _parseZoom(
          value,
          _zoomRatio,
        ).clamp(minimumZoomRatio, maximumZoomRatio).toDouble();
        break;
    }
    notifyListeners();
    if (control == CameraControl.zoom) {
      _queueNativeZoomTarget();
    } else {
      _scheduleNativeControlApply();
    }
  }

  String valueFor(CameraControl control) {
    return switch (control) {
      CameraControl.lens => lens,
      CameraControl.fps => fps,
      CameraControl.shutter => shutter,
      CameraControl.iso => iso,
      CameraControl.whiteBalance => whiteBalance,
      CameraControl.tint => tint,
      CameraControl.focus => focus,
      CameraControl.exposureCompensation =>
        '${_exposureCompensationEv >= 0 ? '+' : ''}${_exposureCompensationEv.toStringAsFixed(1)} EV',
      CameraControl.zoom => '${_formatZoom(_zoomRatio)}x',
    };
  }

  double numericControlValue(CameraControl control) {
    return switch (control) {
      CameraControl.iso => mathLog2(_manualIso / 50.0),
      CameraControl.shutter =>
        double.tryParse(shutter.replaceAll('°', '')) ?? 180.0,
      CameraControl.focus => _manualFocusDiopters,
      CameraControl.exposureCompensation => _exposureCompensationEv,
      CameraControl.tint => double.tryParse(tint.replaceAll('+', '')) ?? 0.0,
      CameraControl.whiteBalance =>
        double.tryParse(whiteBalance.replaceAll('K', '')) ?? 5600.0,
      CameraControl.fps => double.tryParse(fps) ?? 30.0,
      CameraControl.zoom => mathLog2(_zoomRatio),
      CameraControl.lens => 0.0,
    };
  }

  void setNumericControlValue(CameraControl control, double value) {
    if (controlsLocked || !isControlAvailable(control)) return;
    switch (control) {
      case CameraControl.iso:
        _manualIso = (50.0 * mathPow2(value)).round().clamp(50, 800).toInt();
        iso = '$_manualIso';
        break;
      case CameraControl.shutter:
        final double angle = value.clamp(11.25, 345.6).toDouble();
        shutter = '${_formatDecimal(angle)}°';
        break;
      case CameraControl.focus:
        _manualFocusDiopters = value.clamp(0.0, 10.0);
        focus = _formatFocusDistance(_manualFocusDiopters);
        break;
      case CameraControl.exposureCompensation:
        _exposureCompensationEv = value.clamp(-4.0, 4.0).toDouble();
        break;
      case CameraControl.tint:
        tint = '${value >= 0 ? '+' : ''}${value.round()}';
        break;
      case CameraControl.whiteBalance:
        final int kelvin = value.round().clamp(2500, 10000).toInt();
        _manualWhiteBalance = '${kelvin}K';
        whiteBalance = _manualWhiteBalance;
        break;
      case CameraControl.fps:
        final String requested = value.round().toString();
        if (isControlValueSupported(control, requested)) fps = requested;
        break;
      case CameraControl.zoom:
        // The ruler operates in log2 space so equal travel gives an equal
        // proportional field-of-view change, matching perceptual zoom.
        _zoomRatio = mathPow2(
          value,
        ).clamp(minimumZoomRatio, maximumZoomRatio).toDouble();
        break;
      case CameraControl.lens:
        break;
    }
    notifyListeners();
    if (control == CameraControl.zoom) {
      _queueNativeZoomTarget();
    } else {
      _scheduleNativeControlApply();
    }
  }

  void setZoomRatio(double ratio, {int rampDurationMs = 120}) {
    if (controlsLocked) return;
    final double clamped = ratio
        .clamp(minimumZoomRatio, maximumZoomRatio)
        .toDouble();
    if ((clamped - _zoomRatio).abs() < .002) return;
    _zoomRatio = clamped;
    notifyListeners();
    _queueNativeZoomTarget();
  }

  void setControlAuto(CameraControl control, bool enabled) {
    if (controlsLocked) return;
    switch (control) {
      case CameraControl.iso:
        iso = enabled ? 'AUTO' : '$_manualIso';
        break;
      case CameraControl.focus:
        focus = enabled ? 'AUTO' : _formatFocusDistance(_manualFocusDiopters);
        break;
      case CameraControl.whiteBalance:
        whiteBalance = enabled ? 'AUTO' : _manualWhiteBalance;
        break;
      default:
        return;
    }
    notifyListeners();
    _scheduleNativeControlApply();
  }

  bool isControlAuto(CameraControl control) {
    return switch (control) {
      CameraControl.iso => iso == 'AUTO',
      CameraControl.focus => focus == 'AUTO',
      CameraControl.whiteBalance => whiteBalance == 'AUTO',
      _ => false,
    };
  }

  void setMasterAuto(bool enabled) {
    if (controlsLocked) return;
    _aeAfLocked = false;
    _focusUiState = FocusUiState.hidden;
    if (enabled) {
      iso = 'AUTO';
      focus = 'AUTO';
      whiteBalance = 'AUTO';
    } else {
      iso = '$_manualIso';
      focus = _formatFocusDistance(_manualFocusDiopters);
      whiteBalance = _manualWhiteBalance;
    }
    notifyListeners();
    if (!allowSimulation) unawaited(_nativeCamera.setAeAfLock(false));
    _scheduleNativeControlApply();
  }

  Future<void> tapToFocus(
    double normalizedX,
    double normalizedY, {
    bool lock = false,
  }) async {
    if (controlsLocked || !cameraReady) return;
    final double x = normalizedX.clamp(0.0, 1.0).toDouble();
    final double y = normalizedY.clamp(0.0, 1.0).toDouble();
    _focusPoint = Offset(x, y);
    _focusUiState = FocusUiState.scanning;
    _aeAfLocked = lock;
    focus = 'AUTO';
    notifyListeners();
    if (allowSimulation) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      _focusUiState = lock ? FocusUiState.locked : FocusUiState.focused;
      notifyListeners();
      return;
    }
    try {
      _controlApplyDebounce?.cancel();
      await _applyNativeControls();
      await _nativeCamera.tapToFocus(x: x, y: y, lock: lock);
    } catch (error) {
      _focusUiState = FocusUiState.failed;
      _cameraError = _friendlyPlatformError(error);
      notifyListeners();
    }
  }

  Future<void> setAeAfLock(bool locked) async {
    if (controlsLocked || !cameraReady) return;
    _aeAfLocked = locked;
    if (_focusPoint != null) {
      _focusUiState = locked ? FocusUiState.locked : FocusUiState.focused;
    }
    notifyListeners();
    if (allowSimulation) return;
    try {
      await _nativeCamera.setAeAfLock(locked);
    } catch (error) {
      _cameraError = _friendlyPlatformError(error);
      notifyListeners();
    }
  }

  void toggleMonitorTool(MonitorTool tool) {
    if (tool == MonitorTool.cleanFeed) {
      if (!_enabledTools.add(tool)) _enabledTools.remove(tool);
    } else {
      if (!_enabledTools.add(tool)) _enabledTools.remove(tool);
      if (tool == MonitorTool.falseColor && _enabledTools.contains(tool)) {
        _enabledTools.remove(MonitorTool.zebra);
      }
      if (tool == MonitorTool.zebra && _enabledTools.contains(tool)) {
        _enabledTools.remove(MonitorTool.falseColor);
      }
      if (tool == MonitorTool.histogram && _enabledTools.contains(tool)) {
        _enabledTools.remove(MonitorTool.waveform);
      }
      if (tool == MonitorTool.waveform && _enabledTools.contains(tool)) {
        _enabledTools.remove(MonitorTool.histogram);
      }
    }
    notifyListeners();
  }

  void restoreControls() {
    if (_enabledTools.remove(MonitorTool.cleanFeed)) notifyListeners();
  }

  bool isToolEnabled(MonitorTool tool) => _enabledTools.contains(tool);

  void setGuideRatio(GuideRatio value) {
    _guideRatio = value;
    _enabledTools.add(MonitorTool.frameGuides);
    notifyListeners();
  }

  void setLockControlsWhileRecording(bool value) {
    _lockControlsWhileRecording = value;
    notifyListeners();
  }

  void setPreventAccidentalChanges(bool value) {
    _preventAccidentalChanges = value;
    notifyListeners();
  }

  void setShowValidationLabels(bool value) {
    _showValidationLabels = value;
    notifyListeners();
  }

  void setHapticControlFeedback(bool value) {
    _hapticControlFeedback = value;
    notifyListeners();
  }

  Future<void> toggleRecording() async {
    if (_recordBusy) return;
    if (allowSimulation) {
      _setRecordingState(!_recording);
      return;
    }
    if (!cameraReady) {
      _cameraError = 'Camera2 is not ready to record.';
      notifyListeners();
      return;
    }
    _recordBusy = true;
    _runtimeState = _recording
        ? CameraRuntimeState.recording
        : CameraRuntimeState.preparingRecording;
    _activeControl = null;
    notifyListeners();
    try {
      if (_recording) {
        final Map<Object?, Object?> response = await _nativeCamera
            .stopRecording();
        final Object? uri = response['uri'];
        if (uri != null) _lastClipUri = '$uri';
        _setRecordingState(false);
        _runtimeState = CameraRuntimeState.ready;
      } else {
        await _nativeCamera.startRecording();
        _setRecordingState(true);
        _runtimeState = CameraRuntimeState.recording;
      }
      _cameraError = null;
    } catch (error) {
      _setRecordingState(false);
      _runtimeState = CameraRuntimeState.error;
      _cameraError = _friendlyPlatformError(error);
    } finally {
      _recordBusy = false;
      notifyListeners();
    }
  }

  Future<void> openLastClip() async {
    if (_lastClipUri == null || allowSimulation) return;
    try {
      await _nativeCamera.openLastClip();
    } catch (error) {
      _cameraError = _friendlyPlatformError(error);
      notifyListeners();
    }
  }

  void _setRecordingState(bool value) {
    _recording = value;
    _activeControl = null;
    if (value) {
      _recorded = Duration.zero;
      final Stopwatch stopwatch = Stopwatch()..start();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 33), (_) {
        _recorded = stopwatch.elapsed;
        notifyListeners();
      });
    } else {
      _timer?.cancel();
      _timer = null;
      if (_recorded > Duration.zero) _clipCounter++;
    }
    notifyListeners();
  }

  void _queueNativeZoomTarget() {
    if (allowSimulation || _cameraInitialization == null) {
      _actualZoomRatio = _zoomRatio;
      return;
    }
    _pendingZoomCommand = _zoomRatio;
    if (!_zoomCommandInFlight) unawaited(_drainNativeZoomTargets());
  }

  Future<void> _drainNativeZoomTargets() async {
    if (_zoomCommandInFlight) return;
    _zoomCommandInFlight = true;
    try {
      while (_pendingZoomCommand != null && _cameraInitialization != null) {
        // Clear before awaiting. Any touch events arriving during the platform
        // call replace this with only the newest target rather than building a
        // backlog of stale Camera2 requests.
        final double target = _pendingZoomCommand!;
        _pendingZoomCommand = null;
        final Map<Object?, Object?> response = await _nativeCamera
            .setZoomTarget(target);
        final Object? actual = response['actualZoomRatio'];
        if (actual is num) _actualZoomRatio = actual.toDouble();
        notifyListeners();
      }
    } catch (error) {
      _cameraError = _friendlyPlatformError(error);
      notifyListeners();
    } finally {
      _zoomCommandInFlight = false;
      if (_pendingZoomCommand != null && _cameraInitialization != null) {
        unawaited(_drainNativeZoomTargets());
      }
    }
  }

  void _scheduleNativeControlApply() {
    if (allowSimulation || _cameraInitialization == null) return;
    _controlApplyDebounce?.cancel();
    _controlApplyDebounce = Timer(const Duration(milliseconds: 40), () {
      unawaited(_applyNativeControls());
    });
  }

  Future<void> _applyNativeControls() async {
    final double angle = double.tryParse(shutter.replaceAll('°', '')) ?? 180.0;
    final int exposureTimeNs = ((1000000000 / nominalFps) * (angle / 360))
        .round();
    final bool useAutoExposure = iso == 'AUTO';
    final int manualIso = _manualIso;
    final bool useAutoFocus = focus == 'AUTO';
    final double focusDistance = _manualFocusDiopters;
    try {
      await _nativeCamera.setControls(<String, Object>{
        'autoExposure': useAutoExposure,
        'iso': manualIso,
        'exposureTimeNs': exposureTimeNs,
        'autoFocus': useAutoFocus,
        'focusDistanceDiopters': focusDistance,
        'exposureCompensationEv': _exposureCompensationEv,
        'zoomRatio': _zoomRatio,
        'whiteBalance': whiteBalance,
        'tint': int.tryParse(tint.replaceAll('+', '')) ?? 0,
        'ois': true,
        'sharpnessMode': _sharpnessMode.camera2Value,
        'noiseReductionMode': _noiseReductionMode.camera2Value,
      });
    } catch (error) {
      _cameraError = _friendlyPlatformError(error);
      notifyListeners();
    }
  }

  void _handleCameraEvent(Map<Object?, Object?> event) {
    final String type = '${event['type'] ?? ''}';
    if (type == 'metadata') {
      _actualIso = _eventInt(event['iso']);
      _actualExposureTimeNs = _eventInt(event['exposureTimeNs']);
      _actualFrameDurationNs = _eventInt(event['frameDurationNs']);
      _actualRollingShutterSkewNs = _eventInt(event['rollingShutterSkewNs']);
      final Object? focusValue = event['focusDistanceDiopters'];
      if (focusValue is num) {
        _actualFocusDistanceDiopters = focusValue.toDouble();
      }
      final Object? zoomValue = event['zoomRatio'];
      if (zoomValue is num) _actualZoomRatio = zoomValue.toDouble();
      final Object? measuredFps = event['measuredPreviewFps'];
      if (measuredFps is num) _measuredPreviewFps = measuredFps.toDouble();
      final Object? zoomVelocity = event['zoomVelocityStopsPerSecond'];
      if (zoomVelocity is num) {
        _zoomVelocityStopsPerSecond = zoomVelocity.toDouble();
      }
      _captureFrameGaps =
          _eventInt(event['captureFrameGaps']) ?? _captureFrameGaps;
      _actualAfState = _eventInt(event['afState']);
      final Object? nativeLock = event['aeAfLocked'];
      if (nativeLock is bool) _aeAfLocked = nativeLock;
      final Object? pointX = event['focusPointX'];
      final Object? pointY = event['focusPointY'];
      if (pointX is num && pointY is num) {
        _focusPoint = Offset(pointX.toDouble(), pointY.toDouble());
      }
      _focusUiState = switch (_actualAfState) {
        1 || 3 => FocusUiState.scanning,
        2 || 4 => _aeAfLocked ? FocusUiState.locked : FocusUiState.focused,
        5 || 6 => FocusUiState.failed,
        _ => _focusUiState,
      };
      _batteryPercent = _eventInt(event['batteryPercent']) ?? _batteryPercent;
      final Object? charging = event['batteryCharging'];
      if (charging is bool) _batteryCharging = charging;
      _storageAvailableBytes =
          _eventInt(event['storageAvailableBytes']) ?? _storageAvailableBytes;
      _storageTotalBytes =
          _eventInt(event['storageTotalBytes']) ?? _storageTotalBytes;
      final Object? audioDb = event['audioLevelDbfs'];
      if (audioDb is num) _audioLevelDbfs = audioDb.toDouble();
      _actualEdgeMode = _eventInt(event['edgeMode']) ?? _actualEdgeMode;
      _actualNoiseReductionMode =
          _eventInt(event['noiseReductionMode']) ?? _actualNoiseReductionMode;
    } else if (type == 'level') {
      final Object? roll = event['rollDegrees'];
      final Object? pitch = event['pitchDegrees'];
      if (roll is num) _levelRollDegrees = roll.toDouble();
      if (pitch is num) _levelPitchDegrees = pitch.toDouble();
    } else if (type == 'state') {
      final String state = '${event['state'] ?? ''}';
      _runtimeState = switch (state) {
        'opening' => CameraRuntimeState.opening,
        'ready' => CameraRuntimeState.ready,
        'preparingRecording' => CameraRuntimeState.preparingRecording,
        'recording' => CameraRuntimeState.recording,
        'paused' => CameraRuntimeState.paused,
        _ => _runtimeState,
      };
      final Object? uri = event['uri'];
      if (uri != null && state == 'ready') _lastClipUri = '$uri';
    } else if (type == 'error') {
      _runtimeState = CameraRuntimeState.error;
      _cameraError = '${event['message'] ?? 'Unknown Camera2 error'}';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controlApplyDebounce?.cancel();
    unawaited(_cameraEvents?.cancel());
    if (!allowSimulation) unawaited(_nativeCamera.dispose());
    super.dispose();
  }

  static int? _eventInt(Object? value) => value is num ? value.toInt() : null;

  static double _focusDistanceForUiValue(String value) {
    return switch (value) {
      '0.1m' => 10.0,
      '0.3m' => 3.333333,
      '1m' => 1.0,
      '3m' => 0.333333,
      '∞' => 0.0,
      _ => 0.0,
    };
  }

  static double mathLog2(double value) => math.log(value) / math.ln2;

  static double mathPow2(double value) => math.pow(2.0, value).toDouble();

  static String _formatDecimal(double value) {
    if ((value - value.round()).abs() < 0.001) return value.round().toString();
    return value.toStringAsFixed(1);
  }

  static String _formatFocusDistance(double diopters) {
    if (diopters <= 0.005) return '∞';
    final double meters = 1.0 / diopters;
    if (meters >= 10) return '${meters.toStringAsFixed(0)}m';
    if (meters >= 1) return '${meters.toStringAsFixed(1)}m';
    return '${(meters * 100).round()}cm';
  }

  static double _parseZoom(String value, double fallback) {
    final double? parsed = double.tryParse(
      value.toLowerCase().replaceAll('x', '').trim(),
    );
    return parsed?.clamp(1.0, 10.0).toDouble() ?? fallback;
  }

  static String _formatZoom(double value) {
    if ((value - value.round()).abs() < 0.005) return value.round().toString();
    return value.toStringAsFixed(value < 2 ? 2 : 1);
  }

  static String _formatBytes(int? bytes, {required String fallback}) {
    if (bytes == null || bytes < 0) return fallback;
    const double gib = 1024 * 1024 * 1024;
    final double value = bytes / gib;
    return value >= 100
        ? '${value.toStringAsFixed(0)} GB'
        : '${value.toStringAsFixed(1)} GB';
  }

  static String _friendlyPlatformError(Object error) {
    final String value = '$error';
    if (value.contains('PERMISSION_DENIED')) {
      return 'Camera and microphone permissions were denied. Enable both in Android Settings.';
    }
    if (value.contains('UNSUPPORTED_DEVICE')) {
      return 'This build only supports Xiaomi 23090RA98I (zircon).';
    }
    return value;
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

const Map<CameraControl, List<String>> cameraControlOptions =
    <CameraControl, List<String>>{
      CameraControl.lens: <String>['MAIN'],
      CameraControl.fps: <String>['24', '25', '30'],
      CameraControl.shutter: <String>['90°', '144°', '172.8°', '180°', '216°'],
      CameraControl.iso: <String>['AUTO', '50', '100', '200', '400', '800'],
      CameraControl.whiteBalance: <String>[
        'AUTO',
        '3200K',
        '4300K',
        '5600K',
        '6500K',
      ],
      CameraControl.tint: <String>['−20', '−10', '+0', '+10', '+20'],
      CameraControl.focus: <String>['AUTO', '0.1m', '0.3m', '1m', '3m', '∞'],
      CameraControl.exposureCompensation: <String>[
        '-2.0',
        '-1.0',
        '+0.0',
        '+1.0',
        '+2.0',
      ],
      CameraControl.zoom: <String>['1x', '2x', '4x', '10x'],
    };
