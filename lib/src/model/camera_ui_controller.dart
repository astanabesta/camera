import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

enum RecordingMode {
  uhd30('4K', 3840, 2160, 30, 'UHD'),
  fhd30('1080p', 1920, 1080, 30, 'FHD'),
  fourThree30('4:3 1440p', 1920, 1440, 30, '4:3 1440p');

  const RecordingMode(
    this.label,
    this.width,
    this.height,
    this.fps,
    this.hudLabel,
  );
  final String label;
  final int width;
  final int height;
  final int fps;
  final String hudLabel;
}


enum RecordBitDepth {
  eightBit('8-bit SDR', 8),
  tenBit('10-bit SDR', 10);

  const RecordBitDepth(this.label, this.depth);
  final String label;
  final int depth;
}

enum BitratePreset {
  low('Low', 20000000),
  medium('Medium', 50000000),
  high('High', 80000000),
  max('Max', 100000000);

  const BitratePreset(this.label, this.bitsPerSecond);
  final String label;
  final int bitsPerSecond;
  String get display => '${bitsPerSecond ~/ 1000000} Mb/s';
}

enum StabilizationMode {
  off('Off', 0),
  optical('Optical', 1),
  electronic('Electronic', 2);

  const StabilizationMode(this.label, this.nativeValue);
  final String label;
  final int nativeValue;
}

enum ZoomSpeed {
  // Slow intentionally preserves the exact v0.9-v0.12 tuning.
  slow('Slow', 1.0, 1.35, 0.70, 4.0),
  medium('Medium', 2.25, 3.0375, 1.575, 9.0),
  fast('Fast', 3.5, 4.725, 2.45, 14.0);

  const ZoomSpeed(
    this.label,
    this.multiplier,
    this.targetRateStopsPerSecond,
    this.holdRateStopsPerSecond,
    this.accelerationStopsPerSecondSquared,
  );
  final String label;
  final double multiplier;
  final double targetRateStopsPerSecond;
  final double holdRateStopsPerSecond;
  final double accelerationStopsPerSecondSquared;

  String get settingsLabel =>
      this == ZoomSpeed.slow ? label : '$label ${multiplier}×';
  String get compactLabel => switch (this) {
    ZoomSpeed.slow => 'SLOW',
    ZoomSpeed.medium => 'MED 2.25×',
    ZoomSpeed.fast => 'FAST 3.5×',
  };
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

  static const String _preferencesKey = 'zircon.camera.preferences.v1';
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
  // High-frequency recording clock is deliberately separate from the main
  // controller notifier: only timecode widgets should rebuild every frame.
  final ValueNotifier<Duration> _recordingClock =
      ValueNotifier<Duration>(Duration.zero);
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
  Timer? _focusIndicatorTimer;
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
  RecordingMode _recordingMode = RecordingMode.uhd30;
  RecordBitDepth _recordBitDepth = RecordBitDepth.tenBit;
  bool _logProfile = false;
  BitratePreset _bitratePreset = BitratePreset.high;
  StabilizationMode _stabilizationMode = StabilizationMode.optical;
  ZoomSpeed _zoomSpeed = ZoomSpeed.slow;
  int? _actualEdgeMode;
  int? _actualNoiseReductionMode;
  int? _actualOisMode;
  int? _actualVideoStabilizationMode;
  bool _tenBitPreflightBusy = false;
  String? _tenBitPreflightResult;
  bool _tenBitSessionBusy = false;
  String? _tenBitSessionResult;
  bool _tenBitRecordingBusy = false;
  String? _tenBitRecordingResult;
  int _previewRotationDegrees = 0;

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

  bool _showQuickTools = false;

  AppSection get section => _section;
  CameraControl? get activeControl => _activeControl;
  bool get showQuickTools => _showQuickTools;

  void toggleQuickTools() {
    _showQuickTools = !_showQuickTools;
    notifyListeners();
  }

  void hideQuickTools() {
    if (_showQuickTools) {
      _showQuickTools = false;
      notifyListeners();
    }
  }

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
  ValueListenable<Duration> get recordingClock => _recordingClock;
  int? get textureId => _cameraInitialization?.textureId;
  int get previewWidth => _cameraInitialization?.previewWidth ?? 1920;
  int get previewHeight => _cameraInitialization?.previewHeight ?? 1080;
  int get previewQuarterTurns => (_previewRotationDegrees ~/ 90) % 4;
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
  RecordingMode get recordingMode => _recordingMode;
  RecordBitDepth get recordBitDepth => _recordBitDepth;
  bool get logProfile => _logProfile;
  BitratePreset get bitratePreset => _bitratePreset;
  StabilizationMode get stabilizationMode => _stabilizationMode;
  ZoomSpeed get zoomSpeed => _zoomSpeed;
  int? get actualEdgeMode => _actualEdgeMode;
  int? get actualNoiseReductionMode => _actualNoiseReductionMode;
  int? get actualOisMode => _actualOisMode;
  int? get actualVideoStabilizationMode => _actualVideoStabilizationMode;
  bool get tenBitPreflightBusy => _tenBitPreflightBusy;
  String? get tenBitPreflightResult => _tenBitPreflightResult;
  bool get tenBitSessionBusy => _tenBitSessionBusy;
  String? get tenBitSessionResult => _tenBitSessionResult;
  bool get tenBitRecordingBusy => _tenBitRecordingBusy;
  String? get tenBitRecordingResult => _tenBitRecordingResult;
  String get storageAvailableLabel =>
      _formatBytes(_storageAvailableBytes, fallback: '—');
  String get storageTotalLabel =>
      _formatBytes(_storageTotalBytes, fallback: '—');
  // Reserve 256 MiB so recorder finalization and MediaStore bookkeeping do not
  // run the device completely out of space.
  int? get estimatedRecordingSeconds {
    final int? available = _storageAvailableBytes;
    if (available == null) return null;
    const int reserveBytes = 256 * 1024 * 1024;
    final int usableBytes = available - reserveBytes;
    if (usableBytes <= 0) return 0;
    // Add the current AAC request and a small MP4/container allowance.
    final int bitsPerSecond = bitratePreset.bitsPerSecond + 250000;
    return (usableBytes * 8 ~/ bitsPerSecond).clamp(0, 1 << 31).toInt();
  }

  String get remainingRecordTimeLabel {
    final int? seconds = estimatedRecordingSeconds;
    if (seconds == null) return '— remaining';
    final int hours = seconds ~/ 3600;
    final int minutes = (seconds % 3600) ~/ 60;
    return hours > 0 ? '${hours}h ${minutes}m remaining' : '${minutes}m remaining';
  }

  bool get hasSafeRecordingStorage => (estimatedRecordingSeconds ?? 1) > 0;

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
  String get actualStabilizationLabel {
    if (_actualVideoStabilizationMode == 1) return 'Electronic • result';
    if (_actualOisMode == 1) return 'Optical • result';
    if (_actualVideoStabilizationMode == 0 && _actualOisMode == 0) {
      return 'Off • result';
    }
    return 'Waiting for Camera2 result';
  }

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

  String get timecode => timecodeFor(_recorded);

  String timecodeFor(Duration recorded) {
    final int totalFrames = (recorded.inMicroseconds * nominalFps / 1000000)
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
    CameraRuntimeState.preparingRecording => 'PREPARING $resolution',
    CameraRuntimeState.recording => 'RECORDING $resolution$fps',
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

  Future<void> loadPreferences() async {
    try {
      final SharedPreferences preferences = await SharedPreferences.getInstance();
      final String? raw = preferences.getString(_preferencesKey);
      if (raw == null) return;
      final Map<String, dynamic> values = jsonDecode(raw) as Map<String, dynamic>;
      _recordingMode = RecordingMode.values[values['recordingMode'] as int? ?? _recordingMode.index];
      _recordBitDepth = RecordBitDepth.values[values['recordBitDepth'] as int? ?? _recordBitDepth.index];
      _logProfile = values['logProfile'] as bool? ?? false;
      _bitratePreset = BitratePreset.values[values['bitrate'] as int? ?? _bitratePreset.index];
      _stabilizationMode = StabilizationMode.values[values['stabilization'] as int? ?? _stabilizationMode.index];
      _zoomSpeed = ZoomSpeed.values[values['zoomSpeed'] as int? ?? _zoomSpeed.index];
      _sharpnessMode = SharpnessMode.values[values['sharpness'] as int? ?? _sharpnessMode.index];
      _noiseReductionMode = NoiseReductionMode.values[values['noiseReduction'] as int? ?? _noiseReductionMode.index];
      _guideRatio = GuideRatio.values[values['guideRatio'] as int? ?? _guideRatio.index];
      _lockControlsWhileRecording = values['lockControls'] as bool? ?? _lockControlsWhileRecording;
      _hapticControlFeedback = values['haptics'] as bool? ?? _hapticControlFeedback;
      final List<dynamic>? tools = values['tools'] as List<dynamic>?;
      if (tools != null) {
        _enabledTools
          ..clear()
          ..addAll(tools.whereType<String>().map((String name) => MonitorTool.values.firstWhere(
                (MonitorTool value) => value.name == name,
                orElse: () => MonitorTool.grid,
              )));
      }
      resolution = _recordingMode.hudLabel;
      fps = '${_recordingMode.fps}';
      codec = 'HEVC ${_bitratePreset.display}';
      notifyListeners();
    } catch (_) {
      // Preferences are optional; a malformed old value must never block camera launch.
    }
  }

  Future<void> _savePreferences() async {
    try {
      final SharedPreferences preferences = await SharedPreferences.getInstance();
      await preferences.setString(_preferencesKey, jsonEncode(<String, Object>{
        'recordingMode': _recordingMode.index,
        'recordBitDepth': _recordBitDepth.index,
        'bitrate': _bitratePreset.index,
        'stabilization': _stabilizationMode.index,
        'zoomSpeed': _zoomSpeed.index,
        'sharpness': _sharpnessMode.index,
        'noiseReduction': _noiseReductionMode.index,
        'guideRatio': _guideRatio.index,
        'lockControls': _lockControlsWhileRecording,
        'haptics': _hapticControlFeedback,
        'tools': _enabledTools.map((MonitorTool value) => value.name).toList(),
      }));
    } catch (_) {
      // Saving a preference must not interrupt a camera operation.
    }
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
      _previewRotationDegrees = _cameraInitialization!.rotationDegrees;
      _runtimeState = CameraRuntimeState.ready;
      _cameraError = null;
      await _nativeCamera.setVolumeZoomEnabled(_section == AppSection.camera);
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
    if (!allowSimulation && _cameraInitialization != null) {
      unawaited(_nativeCamera.setVolumeZoomEnabled(value == AppSection.camera));
    }
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
    // Android updates Display rotation after the orientation request. Refresh
    // until Camera2 reports a rotation parity matching the selected layout.
    for (int attempt = 0; attempt < 6; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await refreshPreviewOrientation();
      final bool portraitRotation = previewQuarterTurns.isOdd;
      if (portraitRotation == (value == CaptureOrientation.portrait)) break;
    }
  }

  Future<void> refreshPreviewOrientation() async {
    if (allowSimulation || _cameraInitialization == null) return;
    try {
      final Map<Object?, Object?> response = await _nativeCamera
          .getOrientation();
      final Object? degrees = response['rotationDegrees'];
      if (degrees is num) {
        final int next = degrees.toInt();
        if (_previewRotationDegrees != next) {
          _previewRotationDegrees = next;
          notifyListeners();
        }
      }
    } catch (_) {
      // Orientation refresh is best effort; the last valid value remains.
    }
  }

  void setSharpnessMode(SharpnessMode value) {
    if (_sharpnessMode == value) return;
    _sharpnessMode = value;
    notifyListeners();
    unawaited(_savePreferences());
    _scheduleNativeControlApply();
  }

  void setNoiseReductionMode(NoiseReductionMode value) {
    if (_noiseReductionMode == value) return;
    _noiseReductionMode = value;
    notifyListeners();
    unawaited(_savePreferences());
    _scheduleNativeControlApply();
  }

  void setRecordingMode(RecordingMode value) {
    if (_recording || _recordingMode == value) return;
    _recordingMode = value;
    resolution = value.hudLabel;
    fps = '${value.fps}';
    notifyListeners();
    unawaited(_savePreferences());
    _scheduleNativeControlApply();
  }

  
  
  void setLogProfile(bool value) {
    if (_recording || _logProfile == value) return;
    _logProfile = value;
    notifyListeners();
    _scheduleNativeControlApply();
  }

  void setRecordBitDepth(RecordBitDepth value) {
    if (_recording || _recordBitDepth == value) return;
    _recordBitDepth = value;
    notifyListeners();
    _scheduleNativeControlApply();
  }

  void setBitratePreset(BitratePreset value) {
    if (_recording || _bitratePreset == value) return;
    _bitratePreset = value;
    codec = 'HEVC ${value.display}';
    notifyListeners();
    unawaited(_savePreferences());
    _scheduleNativeControlApply();
  }

  void setStabilizationMode(StabilizationMode value) {
    if (_stabilizationMode == value) return;
    _stabilizationMode = value;
    notifyListeners();
    unawaited(_savePreferences());
    _scheduleNativeControlApply();
  }

  void cycleStabilizationMode() {
    const List<StabilizationMode> modes = StabilizationMode.values;
    setStabilizationMode(
      modes[(modes.indexOf(_stabilizationMode) + 1) % modes.length],
    );
  }

  void setZoomSpeed(ZoomSpeed value) {
    if (_zoomSpeed == value) return;
    _zoomSpeed = value;
    notifyListeners();
    unawaited(_savePreferences());
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
        _manualIso = (50.0 * mathPow2(value)).round().clamp(50, 3200).toInt();
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
    _activeControl = null;
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

  void _scheduleFocusIndicatorDismiss({Duration delay = const Duration(milliseconds: 900)}) {
    _focusIndicatorTimer?.cancel();
    if (_aeAfLocked) return;
    _focusIndicatorTimer = Timer(delay, () {
      if (_aeAfLocked) return;
      _focusUiState = FocusUiState.hidden;
      _focusPoint = null;
      notifyListeners();
    });
  }

  Future<void> tapToFocus(
    double normalizedX,
    double normalizedY, {
    bool lock = false,
  }) async {
    if (controlsLocked || !cameraReady) return;
    final double x = normalizedX.clamp(0.0, 1.0).toDouble();
    final double y = normalizedY.clamp(0.0, 1.0).toDouble();
    _focusIndicatorTimer?.cancel();
    _focusPoint = Offset(x, y);
    _focusUiState = FocusUiState.scanning;
    _aeAfLocked = lock;
    focus = 'AUTO';
    notifyListeners();
    if (allowSimulation) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      _focusUiState = lock ? FocusUiState.locked : FocusUiState.focused;
      _scheduleFocusIndicatorDismiss();
      notifyListeners();
      return;
    }
    try {
      _controlApplyDebounce?.cancel();
      await _applyNativeControls();
      await _nativeCamera.tapToFocus(x: x, y: y, lock: lock);
    } catch (error) {
      _focusUiState = FocusUiState.failed;
      _scheduleFocusIndicatorDismiss(delay: const Duration(milliseconds: 1200));
      _cameraError = _friendlyPlatformError(error);
      notifyListeners();
    }
  }

  Future<void> setAeAfLock(bool locked) async {
    if (controlsLocked || !cameraReady) return;
    _aeAfLocked = locked;
    if (_focusPoint != null) {
      _focusUiState = locked ? FocusUiState.locked : FocusUiState.focused;
      if (!locked) _scheduleFocusIndicatorDismiss();
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
    unawaited(_savePreferences());
  }

  void restoreControls() {
    if (_enabledTools.remove(MonitorTool.cleanFeed)) notifyListeners();
  }

  bool isToolEnabled(MonitorTool tool) => _enabledTools.contains(tool);

  void setGuideRatio(GuideRatio value) {
    _guideRatio = value;
    _enabledTools.add(MonitorTool.frameGuides);
    notifyListeners();
    unawaited(_savePreferences());
  }

  void setLockControlsWhileRecording(bool value) {
    _lockControlsWhileRecording = value;
    notifyListeners();
    unawaited(_savePreferences());
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

  Future<void> runTenBitRec709Preflight() async {
    if (allowSimulation || !cameraReady || _tenBitPreflightBusy) return;
    _tenBitPreflightBusy = true;
    _tenBitPreflightResult = null;
    notifyListeners();
    try {
      final Map<Object?, Object?> result =
          await _nativeCamera.runTenBitRec709Preflight();
      _tenBitPreflightResult = '${result['result'] ?? 'No result returned'}';
    } catch (error) {
      _tenBitPreflightResult = _friendlyPlatformError(error);
    } finally {
      _tenBitPreflightBusy = false;
      notifyListeners();
    }
  }

  Future<void> runTenBitRec709SessionTest() async {
    if (allowSimulation || !cameraReady || recording || _tenBitSessionBusy) return;
    _tenBitSessionBusy = true;
    _tenBitSessionResult = null;
    notifyListeners();
    try {
      final Map<Object?, Object?> result =
          await _nativeCamera.runTenBitRec709SessionTest();
      _tenBitSessionResult = [
        '${result['result'] ?? 'No result returned'}',
        if (result['format'] != null) 'Format: ${result['format']}',
        if (result['width'] != null && result['height'] != null)
          'Size: ${result['width']}×${result['height']}',
        if (result['planes'] != null) 'Planes: ${result['planes']}',
        if (result['planeLayout'] != null) 'Layout: ${result['planeLayout']}',
        if (result['validFrames'] != null) 'Valid frames: ${result['validFrames']}',
      ].join('\n');
    } catch (error) {
      _tenBitSessionResult = _friendlyPlatformError(error);
    } finally {
      _tenBitSessionBusy = false;
      notifyListeners();
    }
  }

  Future<void> runTenBitDiagnosticRecording() async {
    if (allowSimulation || recording || _tenBitRecordingBusy) return;
    _tenBitRecordingBusy = true;
    _tenBitRecordingResult = null;
    notifyListeners();
    try {
      final Map<Object?, Object?> result = await _nativeCamera.runTenBitDiagnosticRecording();
      _tenBitRecordingResult = [
        '${result['result'] ?? 'No result returned'}',
        if (result['requestedProfile'] != null) 'Requested: ${result['requestedProfile']}',
        if (result['submittedFrames'] != null) 'Submitted: ${result['submittedFrames']}',
        if (result['encodedFrames'] != null) 'Encoded: ${result['encodedFrames']}',
        if (result['uri'] != null) 'File: ${result['uri']}',
      ].join('\n');
    } catch (error) {
      _tenBitRecordingResult = _friendlyPlatformError(error);
    } finally {
      _tenBitRecordingBusy = false;
      notifyListeners();
    }
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
    if (!_recording && !hasSafeRecordingStorage) {
      _cameraError = 'Not enough free storage to start a safe recording.';
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
        _controlApplyDebounce?.cancel();
        await _applyNativeControls();
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
      _recordingClock.value = Duration.zero;
      final Stopwatch stopwatch = Stopwatch()..start();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 33), (_) {
        _recorded = stopwatch.elapsed;
        _recordingClock.value = _recorded;
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
            .setZoomTarget(
              target,
              targetRateStopsPerSecond: _zoomSpeed.targetRateStopsPerSecond,
              accelerationStopsPerSecondSquared:
                  _zoomSpeed.accelerationStopsPerSecondSquared,
            );
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
        'recordWidth': _recordingMode.width,
        'recordHeight': _recordingMode.height,
        'recordFps': _recordingMode.fps,
        'recordBitDepth': _recordBitDepth.depth,
        'logProfile': _logProfile,
        'videoBitRate': _bitratePreset.bitsPerSecond,
        'stabilizationMode': _stabilizationMode.nativeValue,
        'zoomTargetRateStopsPerSecond': _zoomSpeed.targetRateStopsPerSecond,
        'zoomHoldRateStopsPerSecond': _zoomSpeed.holdRateStopsPerSecond,
        'zoomAccelerationStopsPerSecondSquared':
            _zoomSpeed.accelerationStopsPerSecondSquared,
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
      final bool volumeZoomActive = event['volumeZoomActive'] == true;
      final Object? returnedTarget = event['zoomTargetRatio'];
      if (volumeZoomActive && zoomValue is num) {
        _zoomRatio = zoomValue.toDouble();
      } else if (returnedTarget is num) {
        _zoomRatio = returnedTarget.toDouble();
      }
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
      // Only react to AF results while a user tap is actively being resolved.
      // Continuous-video AF keeps reporting focused states after the operator
      // reframes; it must not resurrect an old tap marker.
      if (_focusUiState == FocusUiState.scanning || _aeAfLocked) {
        final FocusUiState nextFocusState = switch (_actualAfState) {
          1 || 3 => FocusUiState.scanning,
          2 || 4 => _aeAfLocked ? FocusUiState.locked : FocusUiState.focused,
          5 || 6 => FocusUiState.failed,
          _ => _focusUiState,
        };
        if (nextFocusState != _focusUiState) {
          _focusUiState = nextFocusState;
          if (nextFocusState == FocusUiState.focused) {
            _scheduleFocusIndicatorDismiss();
          } else if (nextFocusState == FocusUiState.failed) {
            _scheduleFocusIndicatorDismiss(
              delay: const Duration(milliseconds: 1200),
            );
          }
        }
      }
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
      _actualOisMode = _eventInt(event['oisMode']) ?? _actualOisMode;
      _actualVideoStabilizationMode =
          _eventInt(event['videoStabilizationMode']) ??
          _actualVideoStabilizationMode;
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
    _focusIndicatorTimer?.cancel();
    _recordingClock.dispose();
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
      CameraControl.iso: <String>[
        'AUTO',
        '50',
        '100',
        '200',
        '400',
        '800',
        '1600',
        '3200',
      ],
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
