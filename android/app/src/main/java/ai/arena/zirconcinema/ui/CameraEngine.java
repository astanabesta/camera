package ai.arena.zirconcinema.ui;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.graphics.ImageFormat;
import android.graphics.Rect;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CaptureRequest;
import android.hardware.camera2.CaptureResult;
import android.hardware.camera2.TotalCaptureResult;
import android.hardware.camera2.params.MeteringRectangle;
import android.hardware.camera2.params.StreamConfigurationMap;
import android.hardware.camera2.params.TonemapCurve;
import android.hardware.camera2.params.DynamicRangeProfiles;
import android.hardware.camera2.params.SessionConfiguration;
import android.hardware.camera2.params.OutputConfiguration;
import java.util.concurrent.Executor;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.media.Image;
import android.media.ImageReader;
import android.media.ImageWriter;
import android.media.MediaCodec;
import android.media.MediaCodecInfo;
import android.media.MediaCodecList;
import android.media.MediaFormat;
import android.media.MediaMuxer;
import android.media.MediaRecorder;
import android.net.Uri;
import android.os.BatteryManager;
import android.os.Build;
import android.os.Environment;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.ParcelFileDescriptor;
import android.os.StatFs;
import android.os.SystemClock;
import android.provider.MediaStore;
import android.util.Range;
import android.util.Rational;
import android.util.Size;
import android.view.Surface;

import java.io.FileNotFoundException;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.Arrays;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.concurrent.atomic.AtomicBoolean;

import io.flutter.plugin.common.MethodChannel;
import io.flutter.view.TextureRegistry;

/**
 * Device-specific Camera2 engine for Xiaomi 23090RA98I camera ID 0.
 *
 * This class is an original implementation. MotionCam's GPL repository was
 * reviewed only for high-level architecture (native camera state separation,
 * explicit metadata, and bounded RAW buffers); no MotionCam source is copied.
 */
public final class CameraEngine implements SensorEventListener {
    public interface EventEmitter {
        void emit(Map<String, Object> event);
    }

    private static final String CAMERA_ID = "0";
    private static final int PREVIEW_WIDTH = 1920;
    private static final int PREVIEW_HEIGHT = 1080;
    private static final int DEFAULT_RECORD_WIDTH = 3840;
    private static final int DEFAULT_RECORD_HEIGHT = 2160;
    private static final int DEFAULT_RECORD_FPS = 30;
    private static final int DEFAULT_VIDEO_BIT_RATE = 80_000_000;
    private static final int MAX_VIDEO_BIT_RATE = 100_000_000;
    private static final int AUDIO_BIT_RATE = 192_000;
    private static final int AUDIO_SAMPLE_RATE = 48_000;
    private static final double LOG_2 = Math.log(2.0);
    // Zircon-specific starting values. Final tuning is based on measured
    // capture-result cadence, not assumed 30 fps timer ticks.
    // Slow is intentionally the original v0.9-v0.12 zoom tuning.
    private static final double DEFAULT_ZOOM_TARGET_RATE_STOPS_PER_SECOND = 1.35;
    private static final double DEFAULT_ZOOM_HOLD_RATE_STOPS_PER_SECOND = 0.70;
    private static final double DEFAULT_ZOOM_ACCEL_STOPS_PER_SECOND_SQUARED = 4.0;
    private static final double ZOOM_POSITION_EPSILON_STOPS = 0.0005;
    private static final double ZOOM_VELOCITY_EPSILON = 0.005;

    private final Activity activity;
    private final TextureRegistry textureRegistry;
    private final EventEmitter eventEmitter;
    private final CameraManager cameraManager;
    private final SensorManager sensorManager;
    private final Sensor levelSensor;
    private final AtomicBoolean disposed = new AtomicBoolean(false);
    private long lastLevelEventMs;

    private HandlerThread cameraThread;
    private Handler cameraHandler;
    private TextureRegistry.SurfaceProducer textureProducer;
    private Surface previewSurface;
    private Size previewSize = new Size(PREVIEW_WIDTH, PREVIEW_HEIGHT);
    private CameraCharacteristics characteristics;
    private CameraDevice cameraDevice;
    private CameraCaptureSession captureSession;
    private CaptureRequest.Builder repeatingBuilder;

    private MediaRecorder mediaRecorder;
    private Surface recorderSurface;
    private ParcelFileDescriptor recordingFileDescriptor;
    private ImageReader p010Reader;
    private ImageWriter p010Writer;
    private Uri recordingUri;
    private Uri lastClipUri;
    private MethodChannel.Result pendingInitializeResult;
    private MethodChannel.Result pendingRecordStartResult;

    private volatile boolean initialized;
    private boolean opening;
    private boolean recording;
    private boolean autoExposure = true;
    private boolean autoFocus = true;
    private int requestedIso = 50;
    private long requestedExposureNs = 16_666_667L;
    private float requestedFocusDistance = 0.0f;
    private float requestedExposureCompensationEv = 0.0f;
    private String requestedWhiteBalance = "AUTO";
    private int requestedSharpnessMode = CaptureRequest.EDGE_MODE_OFF;
    private int requestedNoiseReductionMode = CaptureRequest.NOISE_REDUCTION_MODE_MINIMAL;
    private int requestedRecordWidth = DEFAULT_RECORD_WIDTH;
    private int requestedRecordHeight = DEFAULT_RECORD_HEIGHT;
    private int requestedRecordFps = DEFAULT_RECORD_FPS;
    private int requestedVideoBitRate = DEFAULT_VIDEO_BIT_RATE;
    private int requestedBitDepth = 10;
    private boolean requestedLogProfile = false;
    private boolean requestedHlgProfile = false;
    private String requestedFilmStyle = "Standard";
    private float shadowLift = 0.0f;
    private float highlightRollOff = 0.0f;
    // 0=off, 1=optical, 2=electronic.
    private int requestedStabilizationMode = 1;
    private MeteringRectangle[] requestedAfRegions;
    private MeteringRectangle[] requestedAeRegions;
    private boolean tapAfActive;
    private long lastTapAfTimeMs;
    private boolean aeAfLocked;
    private float focusPointX = 0.5f;
    private float focusPointY = 0.5f;
    private float[] lastGravity = new float[3];
    private static final float MOTION_THRESHOLD = 2.5f;

    // Single-lens smooth zoom state. All fields are owned by cameraHandler.
    // Touch/UI events only update targetZoomLog2. Capture results advance the
    // ramp once per actual camera frame, so touch-event jitter never controls
    // Camera2 request pacing.
    private float minimumZoomRatio = 1.0f;
    private float maximumZoomRatio = 10.0f;
    private double zoomLog2 = 0.0;
    private double targetZoomLog2 = 0.0;
    private double zoomVelocityStopsPerSecond = 0.0;
    private float actualZoomRatio = 1.0f;
    private boolean zoomControllerActive;
    private long lastZoomSensorTimestampNs;
    private long lastZoomUpdateFrameNumber = -1L;
    private float lastSubmittedZoomRatio = Float.NaN;
    private long lastSensorTimestampNs;
    private double captureIntervalEmaNs;
    private long lastCaptureFrameNumber = -1L;
    private long captureFrameGaps;
    private volatile boolean volumeZoomEnabled = true;
    private int volumeZoomDirection;
    private long volumeZoomKeyDownMs;
    private double zoomDriveVelocityTarget;
    private boolean zoomDriveBraking;
    private double zoomTargetRateStopsPerSecond =
            DEFAULT_ZOOM_TARGET_RATE_STOPS_PER_SECOND;
    private double zoomHoldRateStopsPerSecond =
            DEFAULT_ZOOM_HOLD_RATE_STOPS_PER_SECOND;
    private double zoomAccelerationStopsPerSecondSquared =
            DEFAULT_ZOOM_ACCEL_STOPS_PER_SECOND_SQUARED;
    private int captureResultCounter;

    public CameraEngine(Activity activity, TextureRegistry textureRegistry,
                        EventEmitter eventEmitter) {
        this.activity = activity;
        this.textureRegistry = textureRegistry;
        this.eventEmitter = eventEmitter;
        this.cameraManager = (CameraManager) activity.getSystemService(Context.CAMERA_SERVICE);
        this.sensorManager = (SensorManager) activity.getSystemService(Context.SENSOR_SERVICE);
        Sensor gravity = sensorManager == null ? null :
                sensorManager.getDefaultSensor(Sensor.TYPE_GRAVITY);
        this.levelSensor = gravity != null ? gravity :
                (sensorManager == null ? null :
                        sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER));
    }

    public void initialize(MethodChannel.Result result) {
        if (disposed.get()) {
            replyError(result, "DISPOSED", "Camera engine is disposed", null);
            return;
        }
        if (!isTargetDevice()) {
            replyError(result, "UNSUPPORTED_DEVICE",
                    "Zircon Cinema camera engine only supports Xiaomi 23090RA98I (zircon). " +
                            "Detected " + Build.MANUFACTURER + " " + Build.MODEL + " / " + Build.DEVICE,
                    null);
            return;
        }
        if (initialized && textureProducer != null) {
            pendingInitializeResult = result;
            startThread();
            cameraHandler.post(() -> {
                if (captureSession != null && cameraDevice != null) {
                    completeInitialization();
                } else if (cameraDevice != null) {
                    createPreviewSession();
                } else {
                    resume();
                }
            });
            return;
        }
        pendingInitializeResult = result;
        try {
            // MethodChannel handlers run on Android's platform thread. Flutter
            // texture resources must be created here, never on Camera2's worker.
            ensurePreviewProducerOnPlatformThread();
        } catch (Throwable error) {
            failInitialization(
                    detailedMessage("Flutter preview surface creation failed", error), error);
            return;
        }

        startThread();
        cameraHandler.post(() -> {
            try {
                characteristics = cameraManager.getCameraCharacteristics(CAMERA_ID);
            } catch (Throwable error) {
                failInitialization(
                        detailedMessage("Camera2 characteristics query failed for camera 0", error),
                        error);
                return;
            }

            try {
                configureZoomRange();
                initialized = true;
                startLevelSensor();
                emitState("opening", null);
                openCamera();
            } catch (Throwable error) {
                failInitialization(
                        detailedMessage("Camera2 open request failed for camera 0", error), error);
            }
        });
    }

    public void updateControls(Map<String, Object> values, MethodChannel.Result result) {
        if (!initialized) {
            replyError(result, "NOT_READY", "Camera is not initialized", null);
            return;
        }
        cameraHandler.post(() -> {
            try {
                autoExposure = booleanValue(values.get("autoExposure"), autoExposure);
                autoFocus = booleanValue(values.get("autoFocus"), autoFocus);
                if (!autoExposure) aeAfLocked = false;
                if (!autoFocus) {
                    tapAfActive = false;
                    requestedAfRegions = null;
                }
                requestedIso = intValue(values.get("iso"), requestedIso);
                requestedExposureNs = longValue(values.get("exposureTimeNs"), requestedExposureNs);
                requestedFocusDistance = floatValue(
                        values.get("focusDistanceDiopters"), requestedFocusDistance);
                requestedExposureCompensationEv = floatValue(
                        values.get("exposureCompensationEv"),
                        requestedExposureCompensationEv);
                Object wb = values.get("whiteBalance");
                if (wb != null) requestedWhiteBalance = String.valueOf(wb);
                requestedSharpnessMode = intValue(
                        values.get("sharpnessMode"), requestedSharpnessMode);
                requestedNoiseReductionMode = intValue(
                        values.get("noiseReductionMode"), requestedNoiseReductionMode);
                requestedLogProfile = booleanValue(values.get("logProfile"), requestedLogProfile);
                requestedHlgProfile = booleanValue(values.get("hlgProfile"), requestedHlgProfile);
                Object filmStyleObj = values.get("filmStyle");
                if (filmStyleObj != null) requestedFilmStyle = String.valueOf(filmStyleObj);
                shadowLift = floatValue(values.get("shadowLift"), shadowLift);
                highlightRollOff = floatValue(values.get("highlightRollOff"), highlightRollOff);
                updateZoomSpeedConfiguration(values);
                Object zoom = values.get("zoomRatio");
                if (zoom instanceof Number) {
                    setZoomTargetInternal(((Number) zoom).floatValue());
                }
                updateRecordingConfiguration(values);
                requestedStabilizationMode = clamp(
                        intValue(values.get("stabilizationMode"),
                                requestedStabilizationMode), 0, 2);
                updateRepeatingRequest();
                Map<String, Object> response = new HashMap<>();
                response.put("applied", true);
                response.put("tintSupported", false);
                response.put("autoExposure", autoExposure);
                response.put("autoFocus", autoFocus);
                response.put("sharpnessModeRequested", requestedSharpnessMode);
                response.put("noiseReductionModeRequested", requestedNoiseReductionMode);
                response.put("recordWidth", requestedRecordWidth);
                response.put("recordBitDepth", requestedBitDepth);
                response.put("recordHeight", requestedRecordHeight);
                response.put("recordFps", requestedRecordFps);
                response.put("videoBitRate", requestedVideoBitRate);
                response.put("stabilizationModeRequested", requestedStabilizationMode);
                response.put("zoomTargetRateStopsPerSecond",
                        zoomTargetRateStopsPerSecond);
                response.put("zoomHoldRateStopsPerSecond",
                        zoomHoldRateStopsPerSecond);
                response.put("zoomAccelerationStopsPerSecondSquared",
                        zoomAccelerationStopsPerSecondSquared);
                replySuccess(result, response);
            } catch (Throwable error) {
                replyError(result, "CONTROL_FAILED", "Unable to apply camera controls", error);
            }
        });
    }

    private void updateRecordingConfiguration(Map<String, Object> values) {
        requestedBitDepth = intValue(values.get("recordBitDepth"), requestedBitDepth);
        int width = intValue(values.get("recordWidth"), requestedRecordWidth);
        int height = intValue(values.get("recordHeight"), requestedRecordHeight);
        int fps = intValue(values.get("recordFps"), requestedRecordFps);
        boolean supportedSize =
                (width == 3840 && height == 2160) ||
                (width == 1920 && height == 1080) ||
                (width == 1920 && height == 1440);
        if (supportedSize && fps == 30) {
            requestedRecordWidth = width;
            requestedRecordHeight = height;
            requestedRecordFps = fps;
        }
        requestedVideoBitRate = clamp(
                intValue(values.get("videoBitRate"), requestedVideoBitRate),
                1_000_000, MAX_VIDEO_BIT_RATE);
    }

    private long requestedFrameDurationNs() {
        return Math.max(1L, 1_000_000_000L / Math.max(1, requestedRecordFps));
    }

    private void updateZoomSpeedConfiguration(Map<String, Object> values) {
        zoomTargetRateStopsPerSecond = clamp(
                floatValue(values.get("zoomTargetRateStopsPerSecond"),
                        (float) zoomTargetRateStopsPerSecond), 0.10f, 5.0f);
        zoomHoldRateStopsPerSecond = clamp(
                floatValue(values.get("zoomHoldRateStopsPerSecond"),
                        (float) zoomHoldRateStopsPerSecond), 0.10f, 5.0f);
        zoomAccelerationStopsPerSecondSquared = clamp(
                floatValue(values.get("zoomAccelerationStopsPerSecondSquared"),
                        (float) zoomAccelerationStopsPerSecondSquared), 0.25f, 20.0f);
    }

    /**
     * Latest-target-wins zoom command. This method never submits a Camera2
     * request directly; the capture callback advances the ramp at actual frame
     * cadence and keeps preview/recording in the existing capture session.
     */
    public void setZoomTarget(Map<String, Object> values, MethodChannel.Result result) {
        if (!initialized || cameraHandler == null) {
            replyError(result, "NOT_READY", "Camera is not initialized", null);
            return;
        }
        cameraHandler.post(() -> {
            try {
                updateZoomSpeedConfiguration(values);
                float target = floatValue(values.get("zoomRatio"), actualZoomRatio);
                setZoomTargetInternal(target);
                Map<String, Object> response = new HashMap<>();
                response.put("accepted", true);
                response.put("targetZoomRatio", zoomRatioFromLog(targetZoomLog2));
                response.put("actualZoomRatio", actualZoomRatio);
                response.put("minimumZoomRatio", minimumZoomRatio);
        response.put("logProfileSupported", true);
                response.put("maximumZoomRatio", maximumZoomRatio);
                response.put("zoomTargetRateStopsPerSecond",
                        zoomTargetRateStopsPerSecond);
                response.put("zoomAccelerationStopsPerSecondSquared",
                        zoomAccelerationStopsPerSecondSquared);
                replySuccess(result, response);
            } catch (Throwable error) {
                replyError(result, "ZOOM_TARGET_FAILED",
                        "Unable to set smooth zoom target", error);
            }
        });
    }

    public void setVolumeZoomEnabled(boolean enabled) {
        volumeZoomEnabled = enabled;
        if (!enabled && cameraHandler != null) {
            cameraHandler.post(() -> releaseVolumeZoom(false));
        }
    }

    public boolean handleVolumeZoomKey(int direction, boolean pressed) {
        if (!volumeZoomEnabled || !initialized || cameraHandler == null ||
                direction == 0) return false;
        cameraHandler.post(() -> {
            if (pressed) {
                if (volumeZoomDirection == direction) return;
                volumeZoomDirection = direction;
                volumeZoomKeyDownMs = SystemClock.elapsedRealtime();
                zoomDriveVelocityTarget = direction * zoomHoldRateStopsPerSecond;
                zoomDriveBraking = false;
                zoomControllerActive = true;
            } else if (volumeZoomDirection == direction) {
                long duration = SystemClock.elapsedRealtime() - volumeZoomKeyDownMs;
                releaseVolumeZoom(duration < 220L);
            }
        });
        return true;
    }

    private void releaseVolumeZoom(boolean tap) {
        int direction = volumeZoomDirection;
        volumeZoomDirection = 0;
        zoomDriveVelocityTarget = 0.0;
        if (tap && direction != 0) {
            // A quick press nudges by one twelfth of a stop. A hold remains a
            // continuous velocity control and decelerates when released.
            double next = zoomLog2 + direction / 12.0;
            setZoomTargetInternal(zoomRatioFromLog(next));
        } else {
            zoomDriveBraking = Math.abs(zoomVelocityStopsPerSecond) >
                    ZOOM_VELOCITY_EPSILON;
            zoomControllerActive = zoomDriveBraking;
            targetZoomLog2 = zoomLog2;
        }
    }

    public void getOrientation(MethodChannel.Result result) {
        Map<String, Object> response = new HashMap<>();
        response.put("rotationDegrees", previewRotationDegrees());
        response.put("displayRotationDegrees",
                rotationToDegrees(activity.getDisplay().getRotation()));
        replySuccess(result, response);
    }

    /**
     * Applies real Camera2 AF/AE metering regions in displayed-preview
     * coordinates. x and y are normalized after Flutter rotation.
     */
    /**
     * Capability preflight only. It does not claim that camera frames or an
     * encoded bitstream are 10-bit; those require the later P010/Main10 ramp
     * diagnostic.
     */
    public void runTenBitRec709Preflight(MethodChannel.Result result) {
        if (!initialized || characteristics == null || cameraHandler == null) {
            replyError(result, "NOT_READY", "Camera must be ready before running the 10-bit preflight", null);
            return;
        }
        cameraHandler.post(() -> {
            try {
                Map<String, Object> response = new HashMap<>();
                StreamConfigurationMap streams = characteristics.get(
                        CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);
                boolean p010Uhd30 = false;
                if (streams != null && Build.VERSION.SDK_INT >= 33) {
                    Size[] sizes = streams.getOutputSizes(ImageFormat.YCBCR_P010);
                    if (sizes != null) {
                        for (Size size : sizes) {
                            if (size.getWidth() == 3840 && size.getHeight() == 2160) {
                                long duration = streams.getOutputMinFrameDuration(
                                        ImageFormat.YCBCR_P010, size);
                                p010Uhd30 = duration > 0 && duration <= 33_333_334L;
                                break;
                            }
                        }
                    }
                }
                boolean hevcEncoder = false;
                boolean main10Advertised = false;
                for (MediaCodecInfo codec : new MediaCodecList(
                        MediaCodecList.ALL_CODECS).getCodecInfos()) {
                    if (!codec.isEncoder()) continue;
                    for (String type : codec.getSupportedTypes()) {
                        if (!"video/hevc".equalsIgnoreCase(type)) continue;
                        hevcEncoder = true;
                        MediaCodecInfo.CodecCapabilities caps = codec.getCapabilitiesForType(type);
                        for (MediaCodecInfo.CodecProfileLevel level : caps.profileLevels) {
                            if (level.profile == MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10) {
                                main10Advertised = true;
                            }
                        }
                    }
                }
                response.put("p010Uhd30Advertised", p010Uhd30);
                response.put("hevcEncoderFound", hevcEncoder);
                response.put("hevcMain10Advertised", main10Advertised);
                response.put("result", p010Uhd30 && hevcEncoder
                        ? "PROMISING — actual P010/Main10 encode test required"
                        : "BLOCKED — required public capability is absent");
                response.put("nextGate", "Run actual P010 camera session and encoded ramp test");
                replySuccess(result, response);
            } catch (Throwable error) {
                replyError(result, "TEN_BIT_PREFLIGHT_FAILED",
                        "Unable to inspect 10-bit Rec.709 capabilities", error);
            }
        });
    }

    /**
     * Step 2: create a real STANDARD-dynamic-range P010 session and acquire
     * one frame. This intentionally does not encode anything yet.
     */
    public void runTenBitRec709SessionTest(MethodChannel.Result result) {
        if (!initialized || cameraDevice == null || cameraHandler == null || recording) {
            replyError(result, "NOT_READY",
                    "Camera must be ready and not recording for the P010 session test", null);
            return;
        }
        cameraHandler.post(() -> {
            if (Build.VERSION.SDK_INT < 33) {
                replyError(result, "UNSUPPORTED", "P010 requires Android 13 or later", null);
                return;
            }
            final AtomicBoolean replied = new AtomicBoolean(false);
            final int[] validFrames = {0};
            final long[] firstTimestampNs = {0L};
            final long[] lastTimestampNs = {0L};
            final ImageReader reader;
            final Surface sessionPreview;
            try {
                reader = ImageReader.newInstance(3840, 2160, ImageFormat.YCBCR_P010, 2);
                sessionPreview = obtainPreviewSurface();
                closeSession();
            } catch (Throwable error) {
                replyError(result, "P010_SETUP_FAILED", "Unable to create P010 test surfaces", error);
                return;
            }
            final Runnable restorePreview = () -> {
                try { reader.close(); } catch (Throwable ignored) {}
                if (cameraDevice != null && !disposed.get() && !recording) createPreviewSession();
            };
            reader.setOnImageAvailableListener(source -> {
                Image image = null;
                try {
                    image = source.acquireLatestImage();
                    if (image == null || replied.get()) return;
                    final boolean expectedFormat = image.getFormat() == ImageFormat.YCBCR_P010;
                    final boolean expectedSize = image.getWidth() == 3840 && image.getHeight() == 2160;
                    if (!expectedFormat || !expectedSize) {
                        if (replied.compareAndSet(false, true)) {
                            replyError(result, "P010_FRAME_MISMATCH",
                                    "Received frame was not YCBCR_P010 at 3840x2160", null);
                            cameraHandler.post(restorePreview);
                        }
                        return;
                    }
                    long timestamp = image.getTimestamp();
                    if (validFrames[0] == 0) firstTimestampNs[0] = timestamp;
                    lastTimestampNs[0] = timestamp;
                    validFrames[0]++;
                    if (validFrames[0] >= 30 && replied.compareAndSet(false, true)) {
                        StringBuilder planeLayout = new StringBuilder();
                        Image.Plane[] planes = image.getPlanes();
                        for (int plane = 0; plane < planes.length; plane++) {
                            if (plane > 0) planeLayout.append(" | ");
                            Image.Plane value = planes[plane];
                            planeLayout.append("P").append(plane)
                                    .append(" row=").append(value.getRowStride())
                                    .append(" px=").append(value.getPixelStride())
                                    .append(" bytes=").append(value.getBuffer().remaining());
                        }
                        Map<String, Object> response = new HashMap<>();
                        response.put("session", "PASS");
                        response.put("frame", "PASS");
                        response.put("format", image.getFormat());
                        response.put("width", image.getWidth());
                        response.put("height", image.getHeight());
                        response.put("planes", planes.length);
                        response.put("planeLayout", planeLayout.toString());
                        response.put("validFrames", validFrames[0]);
                        response.put("firstTimestampNs", firstTimestampNs[0]);
                        response.put("lastTimestampNs", lastTimestampNs[0]);
                        response.put("result", "P010 UHD validation passed: 30 exact-format frames received");
                        replySuccess(result, response);
                        cameraHandler.post(restorePreview);
                    }
                } catch (Throwable error) {
                    if (replied.compareAndSet(false, true)) {
                        replyError(result, "P010_FRAME_FAILED", "P010 frame validation failed", error);
                        cameraHandler.post(restorePreview);
                    }
                } finally {
                    if (image != null) image.close();
                }
            }, cameraHandler);
            try {
                cameraDevice.createCaptureSession(Arrays.asList(sessionPreview, reader.getSurface()),
                        new CameraCaptureSession.StateCallback() {
                            @Override public void onConfigured(CameraCaptureSession session) {
                                if (cameraDevice == null || disposed.get()) { session.close(); return; }
                                try {
                                    captureSession = session;
                                    CaptureRequest.Builder request = cameraDevice.createCaptureRequest(
                                            CameraDevice.TEMPLATE_PREVIEW);
                                    request.addTarget(sessionPreview);
                                    request.addTarget(reader.getSurface());
                                    applyControls(request);
                                    session.setRepeatingRequest(request.build(), captureCallback, cameraHandler);
                                } catch (Throwable error) {
                                    if (replied.compareAndSet(false, true)) {
                                        replyError(result, "P010_CAPTURE_FAILED", "Unable to capture P010 test frame", error);
                                        restorePreview.run();
                                    }
                                }
                            }
                            @Override public void onConfigureFailed(CameraCaptureSession session) {
                                if (replied.compareAndSet(false, true)) {
                                    replyError(result, "P010_SESSION_FAILED", "Camera2 rejected the UHD P010 session", null);
                                    restorePreview.run();
                                }
                            }
                        }, cameraHandler);
                cameraHandler.postDelayed(() -> {
                    if (replied.compareAndSet(false, true)) {
                        replyError(result, "P010_TIMEOUT",
                                "Fewer than 30 valid UHD P010 frames arrived within 5 seconds", null);
                        restorePreview.run();
                    }
                }, 5000);
            } catch (Throwable error) {
                if (replied.compareAndSet(false, true)) {
                    replyError(result, "P010_SESSION_FAILED", "Unable to create UHD P010 session", error);
                    restorePreview.run();
                }
            }
        });
    }

        /** Step 3: encode a known 10-bit P010 ramp and preserve the MP4 for inspection. */
    public void runTenBitDiagnosticRecording(MethodChannel.Result result) {
        if (cameraDevice == null || cameraHandler == null || recording) {
            replyError(result, "NOT_READY", "Camera must be ready and not recording for the 10-bit diagnostic", null);
            return;
        }
        cameraHandler.post(() -> {
            final int width = 3840;
            final int height = 2160;
            final int frameCount = 90; // 3 seconds at 30 fps
            final int fps = 30;
            
            final AtomicBoolean replied = new AtomicBoolean(false);
            final int[] received = {0};
            final int[] submitted = {0};
            final int[] encoded = {0};
            final int[] dropped = {0};
            final boolean[] inputDone = {false};
            final boolean[] outputDone = {false};
            final long[] startTimeMs = {0};
            
            try {
                ContentValues values = new ContentValues();
                values.put(MediaStore.Video.Media.DISPLAY_NAME,
                        "ZC_Main10_P010_Diag_" + System.currentTimeMillis() + ".mp4");
                values.put(MediaStore.Video.Media.MIME_TYPE, "video/mp4");
                values.put(MediaStore.Video.Media.RELATIVE_PATH,
                        Environment.DIRECTORY_MOVIES + "/ZirconCinema/Diagnostics");
                values.put(MediaStore.Video.Media.IS_PENDING, 1);
                final Uri uri = activity.getContentResolver().insert(
                        MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY), values);
                if (uri == null) throw new IOException("MediaStore insert failed");
                final ParcelFileDescriptor fd = activity.getContentResolver().openFileDescriptor(uri, "rw");
                if (fd == null) throw new IOException("Unable to open diagnostic output");

                MediaFormat format = MediaFormat.createVideoFormat("video/hevc", width, height);
                format.setInteger(MediaFormat.KEY_COLOR_FORMAT,
                        MediaCodecInfo.CodecCapabilities.COLOR_FormatYUVP010);
                format.setInteger(MediaFormat.KEY_PROFILE,
                        MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10);
                format.setInteger(MediaFormat.KEY_FRAME_RATE, fps);
                format.setInteger(MediaFormat.KEY_BIT_RATE, 80_000_000);
                format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1);
                format.setInteger(MediaFormat.KEY_COLOR_STANDARD,
                        MediaFormat.COLOR_STANDARD_BT709);
                format.setInteger(MediaFormat.KEY_COLOR_TRANSFER,
                        MediaFormat.COLOR_TRANSFER_SDR_VIDEO);
                format.setInteger(MediaFormat.KEY_COLOR_RANGE,
                        MediaFormat.COLOR_RANGE_LIMITED);
                
                final MediaCodec codec = MediaCodec.createEncoderByType("video/hevc");
                codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE);
                codec.start();
                
                final MediaMuxer muxer = new MediaMuxer(fd.getFileDescriptor(), MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);
                final int[] track = {-1};
                final boolean[] muxerStarted = {false};
                
                final ImageReader reader = ImageReader.newInstance(width, height, ImageFormat.YCBCR_P010, 4);
                final Surface sessionPreview = obtainPreviewSurface();
                closeSession();
                
                final Runnable finishAndReply = () -> {
                    if (!replied.compareAndSet(false, true)) return;
                    try { if (muxerStarted[0]) muxer.stop(); muxer.release(); } catch (Throwable ignored) {}
                    try { codec.stop(); codec.release(); } catch (Throwable ignored) {}
                    try { fd.close(); } catch (Throwable ignored) {}
                    try { reader.close(); } catch (Throwable ignored) {}
                    
                    long actualDurationMs = SystemClock.elapsedRealtime() - startTimeMs[0];
                    
                    ContentValues done = new ContentValues(); 
                    done.put(MediaStore.Video.Media.IS_PENDING, 0);
                    activity.getContentResolver().update(uri, done, null, null);
                    
                    Map<String, Object> response = new HashMap<>();
                    response.put("requestedProfile", "HEVC Main10");
                    response.put("input", "Camera2 P010 3840x2160");
                    response.put("receivedFrames", received[0]);
                    response.put("submittedFrames", submitted[0]);
                    response.put("encodedFrames", encoded[0]);
                    response.put("droppedFrames", dropped[0]);
                    response.put("actualDurationMs", actualDurationMs);
                    response.put("uri", uri.toString());
                    response.put("result", "Main10 diagnostic MP4 created — inspect bitstream");
                    replySuccess(result, response);
                    
                    if (cameraDevice != null && !disposed.get() && !recording) createPreviewSession();
                };

                final Runnable processOutputs = () -> {
                    MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
                    while (true) {
                        int output = codec.dequeueOutputBuffer(info, 0);
                        if (output == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                            track[0] = muxer.addTrack(codec.getOutputFormat());
                            muxer.start(); muxerStarted[0] = true;
                        } else if (output >= 0) {
                            ByteBuffer data = codec.getOutputBuffer(output);
                            if (data != null && info.size > 0 && muxerStarted[0]) {
                                data.position(info.offset); data.limit(info.offset + info.size);
                                muxer.writeSampleData(track[0], data, info);
                                encoded[0]++;
                            }
                            if ((info.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                                outputDone[0] = true;
                            }
                            codec.releaseOutputBuffer(output, false);
                        } else {
                            break;
                        }
                    }
                    if (outputDone[0]) finishAndReply.run();
                };

                reader.setOnImageAvailableListener(source -> {
                    if (outputDone[0]) {
                        try { Image i = source.acquireNextImage(); if (i!=null) i.close(); } catch(Throwable t){}
                        return;
                    }
                    Image image = null;
                    try {
                        image = source.acquireNextImage();
                        if (image == null) return;
                        
                        received[0]++;
                        
                        if (startTimeMs[0] == 0) startTimeMs[0] = SystemClock.elapsedRealtime();

                        processOutputs.run();
                        
                        if (!inputDone[0]) {
                            int index = codec.dequeueInputBuffer(0);
                            if (index >= 0) {
                                ByteBuffer input = codec.getInputBuffer(index);
                                if (submitted[0] < frameCount) {
                                    copyP010Image(image, input);
                                    codec.queueInputBuffer(index, 0, width * height * 3,
                                            submitted[0] * 1_000_000L / fps, 0);
                                    submitted[0]++;
                                } else {
                                    codec.queueInputBuffer(index, 0, 0,
                                            frameCount * 1_000_000L / fps,
                                            MediaCodec.BUFFER_FLAG_END_OF_STREAM);
                                    inputDone[0] = true;
                                }
                            } else {
                                dropped[0]++;
                            }
                        }
                    } catch (Throwable error) {
                        if (replied.compareAndSet(false, true)) {
                            replyError(result, "MAIN10_DIAGNOSTIC_FAILED", "Diagnostic pipeline failed", error);
                            if (cameraDevice != null && !disposed.get() && !recording) createPreviewSession();
                        }
                    } finally {
                        if (image != null) image.close();
                        processOutputs.run();
                    }
                }, cameraHandler);
                
                cameraDevice.createCaptureSession(Arrays.asList(sessionPreview, reader.getSurface()),
                        new CameraCaptureSession.StateCallback() {
                            @Override public void onConfigured(CameraCaptureSession session) {
                                if (cameraDevice == null || disposed.get()) { session.close(); return; }
                                try {
                                    captureSession = session;
                                    CaptureRequest.Builder request = cameraDevice.createCaptureRequest(
                                            CameraDevice.TEMPLATE_RECORD);
                                    request.addTarget(sessionPreview);
                                    request.addTarget(reader.getSurface());
                                    applyControls(request);
                                    session.setRepeatingRequest(request.build(), captureCallback, cameraHandler);
                                } catch (Throwable error) {
                                    if (replied.compareAndSet(false, true)) {
                                        replyError(result, "DIAGNOSTIC_CAPTURE_FAILED", "Unable to start requests", error);
                                        finishAndReply.run();
                                    }
                                }
                            }
                            @Override public void onConfigureFailed(CameraCaptureSession session) {
                                if (replied.compareAndSet(false, true)) {
                                    replyError(result, "DIAGNOSTIC_SESSION_FAILED", "Camera2 rejected diagnostic session", null);
                                    finishAndReply.run();
                                }
                            }
                        }, cameraHandler);
                        
                cameraHandler.postDelayed(() -> {
                    if (!outputDone[0]) finishAndReply.run();
                }, 8000); // 8 seconds absolute maximum timeout
                
            } catch (Throwable error) {
                if (replied.compareAndSet(false, true)) {
                    replyError(result, "DIAGNOSTIC_SETUP_FAILED", "Setup failed", error);
                    if (cameraDevice != null && !disposed.get() && !recording) createPreviewSession();
                }
            }
        });
    }

    private static void copyP010Image(Image image, ByteBuffer output) {
        output.clear();
        Image.Plane[] planes = image.getPlanes();
        int width = image.getWidth();
        int height = image.getHeight();
        
        // Plane 0: Luma (Y)
        ByteBuffer yBuf = planes[0].getBuffer();
        int yRowStride = planes[0].getRowStride();
        int yPixStride = planes[0].getPixelStride();
        
        if (yRowStride == width * 2 && yPixStride == 2) {
            yBuf.position(0);
            yBuf.limit(width * height * 2);
            output.put(yBuf);
        } else {
            for (int r = 0; r < height; r++) {
                yBuf.position(r * yRowStride);
                yBuf.limit(r * yRowStride + width * 2);
                output.put(yBuf);
            }
        }
        
        // Plane 1 & 2: Chroma (U & V)
        ByteBuffer uBuf = planes[1].getBuffer();
        ByteBuffer vBuf = planes[2].getBuffer();
        int uRowStride = planes[1].getRowStride();
        int vRowStride = planes[2].getRowStride();
        int uPixStride = planes[1].getPixelStride();
        int vPixStride = planes[2].getPixelStride();
        
        int uvWidth = width / 2;
        int uvHeight = height / 2;
        
        if (uPixStride == 4 && vPixStride == 4) {
            // Android P010 fast path: U and V are already interleaved
            // Just copy rows of Plane 1
            for (int r = 0; r < uvHeight; r++) {
                uBuf.position(r * uRowStride);
                uBuf.limit(r * uRowStride + uvWidth * 4);
                output.put(uBuf);
            }
        } else {
            // Slow manual pack
            for (int r = 0; r < uvHeight; r++) {
                for (int c = 0; c < uvWidth; c++) {
                    short uVal = uBuf.getShort(r * uRowStride + c * uPixStride);
                    short vVal = vBuf.getShort(r * vRowStride + c * vPixStride);
                    output.putShort(uVal);
                    output.putShort(vVal);
                }
            }
        }
    }


    public void tapToFocus(Map<String, Object> values, MethodChannel.Result result) {
        if (!initialized || cameraHandler == null) {
            replyError(result, "NOT_READY", "Camera is not initialized", null);
            return;
        }
        cameraHandler.post(() -> {
            try {
                if (captureSession == null || repeatingBuilder == null) {
                    throw new IllegalStateException("Camera capture session is unavailable");
                }
                focusPointX = clamp01(floatValue(values.get("x"), 0.5f));
                focusPointY = clamp01(floatValue(values.get("y"), 0.5f));
                boolean lockAfterFocus = booleanValue(values.get("lock"), false);
                Rect crop = meteringCropRegion();
                requestedAfRegions = supportedRegion(
                        CameraCharacteristics.CONTROL_MAX_REGIONS_AF,
                        meteringRectangle(crop, focusPointX, focusPointY, 0.09f));
                requestedAeRegions = supportedRegion(
                        CameraCharacteristics.CONTROL_MAX_REGIONS_AE,
                        meteringRectangle(crop, focusPointX, focusPointY, 0.14f));
                autoFocus = true;
                tapAfActive = true;
                lastTapAfTimeMs = SystemClock.elapsedRealtime();
                // Meter first. A long press locks AE only after the new point
                // has had time to settle; locking before the trigger would
                // freeze exposure at the previous region.
                aeAfLocked = false;

                applyControls(repeatingBuilder);
                setSafely(repeatingBuilder, CaptureRequest.CONTROL_AF_TRIGGER,
                        CaptureRequest.CONTROL_AF_TRIGGER_CANCEL);
                captureSession.capture(
                        repeatingBuilder.build(), captureCallback, cameraHandler);

                setSafely(repeatingBuilder, CaptureRequest.CONTROL_AF_TRIGGER,
                        CaptureRequest.CONTROL_AF_TRIGGER_START);
                setSafely(repeatingBuilder, CaptureRequest.CONTROL_AE_PRECAPTURE_TRIGGER,
                        CaptureRequest.CONTROL_AE_PRECAPTURE_TRIGGER_START);
                captureSession.capture(
                        repeatingBuilder.build(), captureCallback, cameraHandler);

                setSafely(repeatingBuilder, CaptureRequest.CONTROL_AF_TRIGGER,
                        CaptureRequest.CONTROL_AF_TRIGGER_IDLE);
                setSafely(repeatingBuilder, CaptureRequest.CONTROL_AE_PRECAPTURE_TRIGGER,
                        CaptureRequest.CONTROL_AE_PRECAPTURE_TRIGGER_IDLE);
                captureSession.setRepeatingRequest(
                        repeatingBuilder.build(), captureCallback, cameraHandler);
                if (lockAfterFocus) {
                    cameraHandler.postDelayed(() -> {
                        if (!tapAfActive || captureSession == null || repeatingBuilder == null) {
                            return;
                        }
                        try {
                            aeAfLocked = true;
                            updateRepeatingRequest();
                        } catch (Throwable error) {
                            emitError("LOCK_FAILED", "Unable to lock metered AE/AF point", error);
                        }
                    }, 650L);
                }

                Map<String, Object> response = new HashMap<>();
                response.put("accepted", true);
                response.put("x", focusPointX);
                response.put("y", focusPointY);
                response.put("locked", lockAfterFocus);
                response.put("afRegionSupported", requestedAfRegions != null);
                response.put("aeRegionSupported", requestedAeRegions != null);
                replySuccess(result, response);
            } catch (Throwable error) {
                replyError(result, "TAP_FOCUS_FAILED",
                        "Unable to apply Camera2 focus/metering point", error);
            }
        });
    }

    public void setAeAfLock(boolean locked, MethodChannel.Result result) {
        if (!initialized || cameraHandler == null) {
            replyError(result, "NOT_READY", "Camera is not initialized", null);
            return;
        }
        cameraHandler.post(() -> {
            try {
                aeAfLocked = locked;
                if (!locked) {
                    tapAfActive = false;
                    requestedAfRegions = null;
                    requestedAeRegions = null;
                }
                updateRepeatingRequest();
                Map<String, Object> response = new HashMap<>();
                response.put("locked", aeAfLocked);
                replySuccess(result, response);
            } catch (Throwable error) {
                replyError(result, "LOCK_FAILED", "Unable to change AE/AF lock", error);
            }
        });
    }

    public void startRecording(MethodChannel.Result result) {
        if (!initialized || cameraDevice == null) {
            replyError(result, "NOT_READY", "Camera is not ready", null);
            return;
        }
        if (recording || pendingRecordStartResult != null) {
            replyError(result, "ALREADY_RECORDING", "Recording is already active or starting", null);
            return;
        }
        pendingRecordStartResult = result;
        cameraHandler.post(() -> {
            try {
                emitState("preparingRecording", null);
                closeSession();
                prepareRecorder();
                createRecordingSession();
            } catch (Throwable error) {
                failRecordStart("Unable to prepare UHD HEVC recorder", error);
            }
        });
    }

    public void stopRecording(MethodChannel.Result result) {
        if (!recording && pendingRecordStartResult == null) {
            Map<String, Object> response = new HashMap<>();
            response.put("stopped", false);
            response.put("uri", lastClipUri == null ? null : lastClipUri.toString());
            replySuccess(result, response);
            return;
        }
        cameraHandler.post(() -> stopRecordingInternal(result, true));
    }

    public void pause() {
        stopLevelSensor();
        if (!initialized || cameraHandler == null) return;
        cameraHandler.post(() -> {
            if (recording || pendingRecordStartResult != null) {
                stopRecordingInternal(null, false);
            }
            closeCameraOnly();
            emitState("paused", null);
        });
    }

    public void resume() {
        if (!initialized || disposed.get()) return;
        startLevelSensor();
        startThread();
        cameraHandler.post(() -> {
            if (cameraDevice == null && !opening) {
                try {
                    emitState("opening", null);
                    openCamera();
                } catch (Throwable error) {
                    emitError("RESUME_FAILED", "Unable to reopen camera", error);
                }
            }
        });
    }

    public Uri getLastClipUri() {
        return lastClipUri;
    }

    public void dispose() {
        if (!disposed.compareAndSet(false, true)) return;
        stopLevelSensor();
        if (cameraHandler != null) {
            cameraHandler.post(() -> {
                if (recording || pendingRecordStartResult != null) {
                    stopRecordingInternal(null, false);
                }
                closeCameraOnly();
                releasePreviewSurface();
            });
        } else {
            releasePreviewSurface();
        }
        stopThread();
    }

    private void startLevelSensor() {
        if (sensorManager == null || levelSensor == null || disposed.get()) return;
        sensorManager.unregisterListener(this);
        sensorManager.registerListener(this, levelSensor, SensorManager.SENSOR_DELAY_GAME);
    }

    private void stopLevelSensor() {
        if (sensorManager != null) sensorManager.unregisterListener(this);
    }

    @Override
    public void onSensorChanged(SensorEvent event) {
        if (event == null || event.values.length < 3 || disposed.get()) return;
        long now = SystemClock.elapsedRealtime();

        // Focus reset on motion logic
        if (tapAfActive && !aeAfLocked && event.sensor.getType() == Sensor.TYPE_GRAVITY) {
            float delta = 0;
            for (int i = 0; i < 3; i++) {
                delta += Math.abs(event.values[i] - lastGravity[i]);
                lastGravity[i] = event.values[i];
            }
            // If movement is detected or 8 seconds passed, return to continuous AF
            if (delta > MOTION_THRESHOLD || (now - lastTapAfTimeMs > 8000L)) {
                tapAfActive = false;
                requestedAfRegions = null;
                cameraHandler.post(() -> {
                    try {
                        updateRepeatingRequest();
                    } catch (Throwable ignored) {}
                });
            }
        } else if (event.sensor.getType() == Sensor.TYPE_GRAVITY) {
            for (int i = 0; i < 3; i++) lastGravity[i] = event.values[i];
        }

        if (now - lastLevelEventMs < 100L) return;
        lastLevelEventMs = now;
        float x = event.values[0];
        float y = event.values[1];
        float z = event.values[2];
        float screenX;
        float screenY;
        switch (activity.getDisplay().getRotation()) {
            case Surface.ROTATION_90 -> { screenX = -y; screenY = x; }
            case Surface.ROTATION_180 -> { screenX = -x; screenY = -y; }
            case Surface.ROTATION_270 -> { screenX = y; screenY = -x; }
            default -> { screenX = x; screenY = y; }
        }
        Map<String, Object> level = new HashMap<>();
        level.put("type", "level");
        level.put("rollDegrees", Math.toDegrees(Math.atan2(screenX, screenY)));
        level.put("pitchDegrees", Math.toDegrees(Math.atan2(
                z, Math.sqrt(screenX * screenX + screenY * screenY))));
        emit(level);
    }

    @Override
    public void onAccuracyChanged(Sensor sensor, int accuracy) {
    }

    private void startThread() {
        if (cameraThread != null && cameraThread.isAlive()) return;
        cameraThread = new HandlerThread("ZirconCamera2");
        cameraThread.start();
        cameraHandler = new Handler(cameraThread.getLooper());
    }

    private void stopThread() {
        HandlerThread thread = cameraThread;
        cameraThread = null;
        cameraHandler = null;
        if (thread != null) thread.quitSafely();
    }

    private void ensurePreviewProducerOnPlatformThread() {
        if (textureProducer != null) return;
        textureProducer = textureRegistry.createSurfaceProducer();
        textureProducer.setSize(previewSize.getWidth(), previewSize.getHeight());
        textureProducer.setCallback(new TextureRegistry.SurfaceProducer.Callback() {
            @Override
            public void onSurfaceAvailable() {
                previewSurface = null;
                if (initialized && !disposed.get()) resume();
            }

            @Override
            public void onSurfaceCleanup() {
                Handler handler = cameraHandler;
                if (handler != null) {
                    handler.post(() -> {
                        closeCameraOnly();
                        previewSurface = null;
                    });
                } else {
                    previewSurface = null;
                }
            }
        });
    }

    private Surface obtainPreviewSurface() {
        if (textureProducer == null) {
            throw new IllegalStateException("Flutter SurfaceProducer is null");
        }
        Surface surface = textureProducer.getSurface();
        if (surface == null || !surface.isValid()) {
            throw new IllegalStateException("Flutter preview Surface is unavailable or invalid");
        }
        previewSurface = surface;
        return surface;
    }

    @SuppressLint("MissingPermission")
    private void openCamera() throws CameraAccessException {
        if (opening || cameraDevice != null) return;
        opening = true;
        cameraManager.openCamera(CAMERA_ID, cameraStateCallback, cameraHandler);
    }

    private final CameraDevice.StateCallback cameraStateCallback = new CameraDevice.StateCallback() {
        @Override
        public void onOpened(CameraDevice camera) {
            opening = false;
            cameraDevice = camera;
            createPreviewSession();
        }

        @Override
        public void onDisconnected(CameraDevice camera) {
            opening = false;
            camera.close();
            cameraDevice = null;
            emitError("CAMERA_DISCONNECTED", "Camera 0 disconnected", null);
        }

        @Override
        public void onError(CameraDevice camera, int error) {
            opening = false;
            camera.close();
            cameraDevice = null;
            String message = "Camera2 open callback failed: " +
                    cameraErrorName(error) + " (code " + error + ")";
            failInitialization(message, null);
            emitError("CAMERA_ERROR", message, null);
        }
    };

    private void createPreviewSession() {
        if (cameraDevice == null) return;
        closeSession();
        final Surface sessionPreviewSurface;
        try {
            sessionPreviewSurface = obtainPreviewSurface();
            cameraDevice.createCaptureSession(
                    List.of(sessionPreviewSurface),
                    new CameraCaptureSession.StateCallback() {
                        @Override
                        public void onConfigured(CameraCaptureSession session) {
                            if (cameraDevice == null || disposed.get()) {
                                session.close();
                                return;
                            }
                            captureSession = session;
                            try {
                                repeatingBuilder = cameraDevice.createCaptureRequest(
                                        CameraDevice.TEMPLATE_PREVIEW);
                                repeatingBuilder.addTarget(sessionPreviewSurface);
                                applyControls(repeatingBuilder);
                                captureSession.setRepeatingRequest(
                                        repeatingBuilder.build(), captureCallback, cameraHandler);
                                emitState("ready", null);
                                completeInitialization();
                            } catch (Throwable error) {
                                failInitialization(
                                        detailedMessage("Camera2 repeating preview request failed", error),
                                        error);
                            }
                        }

                        @Override
                        public void onConfigureFailed(CameraCaptureSession session) {
                            failInitialization(
                                    "Camera2 preview session configuration failed for 1920x1080 PRIVATE SurfaceProducer",
                                    null);
                        }
                    },
                    cameraHandler);
        } catch (Throwable error) {
            failInitialization(
                    detailedMessage("Camera2 preview session creation failed", error), error);
        }
    }

    private void createRecordingSession() throws CameraAccessException {
        if (cameraDevice == null || recorderSurface == null) {
            throw new IllegalStateException("Recorder surface is unavailable");
        }
        final Surface sessionPreviewSurface = obtainPreviewSurface();
        
        Surface cameraTargetSurface = recorderSurface;
        try {
            if (requestedBitDepth == 10 && Build.VERSION.SDK_INT >= 33) {
                p010Writer = ImageWriter.newInstance(recorderSurface, 4, ImageFormat.YCBCR_P010);
                p010Reader = ImageReader.newInstance(requestedRecordWidth, requestedRecordHeight, ImageFormat.YCBCR_P010, 4);
                p010Reader.setOnImageAvailableListener(reader -> {
                    try {
                        Image image = reader.acquireNextImage();
                        if (image != null) {
                            if (p010Writer != null && recording) {
                                image.setTimestamp(System.nanoTime());
                                p010Writer.queueInputImage(image);
                            } else {
                                image.close();
                            }
                        }
                    } catch (Throwable ignored) {}
                }, cameraHandler);
                cameraTargetSurface = p010Reader.getSurface();
            }
        } catch (Throwable e) {
            emitError("BRIDGE_FAILED", "Hardware P010 bridge failed, falling back to 8-bit surface", e);
            cameraTargetSurface = recorderSurface;
        }

        final Surface finalTargetSurface = cameraTargetSurface;

        
        CameraCaptureSession.StateCallback stateCallback = new CameraCaptureSession.StateCallback() {
            @Override
            public void onConfigured(CameraCaptureSession session) {
                if (cameraDevice == null || mediaRecorder == null) {
                    session.close();
                    failRecordStart("Recorder was released during session setup", null);
                    return;
                }
                captureSession = session;
                try {
                    repeatingBuilder = cameraDevice.createCaptureRequest(CameraDevice.TEMPLATE_RECORD);
                    repeatingBuilder.addTarget(sessionPreviewSurface);
                    repeatingBuilder.addTarget(finalTargetSurface);
                    
                    // If HLG is requested, Camera2 handles the tonemap profile itself (HLG10 dynamic range)
                    applyControls(repeatingBuilder);
                    
                    captureSession.setRepeatingRequest(repeatingBuilder.build(), captureCallback, cameraHandler);
                    mediaRecorder.start();
                    recording = true;
                    emitState("recording", recordingUri == null ? null : recordingUri.toString());
                    Map<String, Object> response = new HashMap<>();
                    response.put("recording", true);
                    response.put("uri", recordingUri == null ? null : recordingUri.toString());
                    response.put("width", requestedRecordWidth);
                    response.put("height", requestedRecordHeight);
                    response.put("fps", requestedRecordFps);
                    
                    String codecStr = "HEVC Main 8-bit";
                    if (requestedBitDepth == 10) {
                        codecStr = requestedHlgProfile ? "HEVC Main10 HLG (BT.2020)" : "HEVC Main10 10-bit SDR";
                    }
                    response.put("codec", codecStr);
                    
                    response.put("videoBitRate", requestedVideoBitRate);
                    response.put("audio", "AAC 48kHz");
                    MethodChannel.Result pending = pendingRecordStartResult;
                    pendingRecordStartResult = null;
                    replySuccess(pending, response);
                } catch (Throwable error) {
                    failRecordStart("Unable to start MediaRecorder", error);
                }
            }

            @Override
            public void onConfigureFailed(CameraCaptureSession session) {
                failRecordStart("Camera2 UHD recording session configuration failed", null);
            }
        };

        if (Build.VERSION.SDK_INT >= 33 && requestedHlgProfile) {
            try {
                OutputConfiguration previewConfig = new OutputConfiguration(sessionPreviewSurface);
                OutputConfiguration recordConfig = new OutputConfiguration(finalTargetSurface);
                recordConfig.setDynamicRangeProfile(DynamicRangeProfiles.HLG10);
                previewConfig.setDynamicRangeProfile(DynamicRangeProfiles.HLG10);
                
                SessionConfiguration sessionConfig = new SessionConfiguration(
                        SessionConfiguration.SESSION_REGULAR,
                        Arrays.asList(previewConfig, recordConfig),
                        new Executor() {
                            @Override
                            public void execute(Runnable command) {
                                cameraHandler.post(command);
                            }
                        },
                        stateCallback);
                cameraDevice.createCaptureSession(sessionConfig);
            } catch (Throwable e) {
                emitError("HLG_SESSION_FAILED", "Device rejected HLG10 session profile", e);
                // Fallback to standard session
                try {
                    cameraDevice.createCaptureSession(
                            Arrays.asList(sessionPreviewSurface, finalTargetSurface),
                            stateCallback, cameraHandler);
                } catch (CameraAccessException ex) {
                    failRecordStart("Camera2 UHD recording fallback session failed", ex);
                }
            }
        } else {
            cameraDevice.createCaptureSession(
                    Arrays.asList(sessionPreviewSurface, finalTargetSurface),
                    stateCallback, cameraHandler);
        }
    }

    private final CameraCaptureSession.CaptureCallback captureCallback =
            new CameraCaptureSession.CaptureCallback() {
                @Override
                public void onCaptureStarted(CameraCaptureSession session,
                                             CaptureRequest request,
                                             long timestamp,
                                             long frameNumber) {
                    // Capture-start callbacks arrive earlier and with less
                    // variable ISP/result latency than onCaptureCompleted.
                    // Advancing here keeps request submission aligned to the
                    // actual sensor cadence instead of delayed metadata timing.
                    updateCaptureCadence(timestamp, frameNumber);
                    updateZoomController(timestamp, frameNumber);
                }

                @Override
                public void onCaptureCompleted(CameraCaptureSession session,
                                               CaptureRequest request,
                                               TotalCaptureResult result) {
                    captureResultCounter++;
                    Long sensorTimestamp = result.get(CaptureResult.SENSOR_TIMESTAMP);
                    Float returnedZoom = result.get(CaptureResult.CONTROL_ZOOM_RATIO);
                    if (returnedZoom != null && returnedZoom > 0.0f) {
                        actualZoomRatio = returnedZoom;
                    }
                    int metadataInterval = zoomControllerActive ? 3 : 15;
                    if ((captureResultCounter % metadataInterval) != 0) return;
                    Map<String, Object> event = new HashMap<>();
                    event.put("type", "metadata");
                    event.put("state", recording ? "recording" : "ready");
                    putNumber(event, "sensorTimestampNs", sensorTimestamp);
                    event.put("zoomRatio", actualZoomRatio);
                    event.put("zoomTargetRatio", zoomRatioFromLog(targetZoomLog2));
                    event.put("zoomVelocityStopsPerSecond", zoomVelocityStopsPerSecond);
                    event.put("zoomTargetRateStopsPerSecond",
                            zoomTargetRateStopsPerSecond);
                    event.put("zoomHoldRateStopsPerSecond",
                            zoomHoldRateStopsPerSecond);
                    if (captureIntervalEmaNs > 0.0) {
                        event.put("measuredPreviewFps", 1_000_000_000.0 / captureIntervalEmaNs);
                        event.put("captureIntervalEmaNs", captureIntervalEmaNs);
                    }
                    event.put("captureFrameGaps", captureFrameGaps);
                    event.put("volumeZoomActive",
                            volumeZoomDirection != 0 || zoomDriveBraking);
                    putNumber(event, "iso", result.get(CaptureResult.SENSOR_SENSITIVITY));
                    putNumber(event, "exposureTimeNs", result.get(CaptureResult.SENSOR_EXPOSURE_TIME));
                    putNumber(event, "frameDurationNs", result.get(CaptureResult.SENSOR_FRAME_DURATION));
                    putNumber(event, "rollingShutterSkewNs",
                            result.get(CaptureResult.SENSOR_ROLLING_SHUTTER_SKEW));
                    Integer aeIndex = result.get(
                            CaptureResult.CONTROL_AE_EXPOSURE_COMPENSATION);
                    if (aeIndex != null) {
                        event.put("exposureCompensationIndex", aeIndex);
                        Rational step = characteristics.get(
                                CameraCharacteristics.CONTROL_AE_COMPENSATION_STEP);
                        if (step != null) {
                            event.put("exposureCompensationEv",
                                    aeIndex * step.doubleValue());
                        }
                    }
                    Float focus = result.get(CaptureResult.LENS_FOCUS_DISTANCE);
                    if (focus != null) event.put("focusDistanceDiopters", focus.doubleValue());
                    putNumber(event, "afState", result.get(CaptureResult.CONTROL_AF_STATE));
                    putNumber(event, "aeState", result.get(CaptureResult.CONTROL_AE_STATE));
                    putNumber(event, "edgeMode", result.get(CaptureResult.EDGE_MODE));
                    putNumber(event, "noiseReductionMode",
                            result.get(CaptureResult.NOISE_REDUCTION_MODE));
                    putNumber(event, "oisMode",
                            result.get(CaptureResult.LENS_OPTICAL_STABILIZATION_MODE));
                    putNumber(event, "videoStabilizationMode",
                            result.get(CaptureResult.CONTROL_VIDEO_STABILIZATION_MODE));
                    event.put("aeAfLocked", aeAfLocked);
                    if (requestedAfRegions != null || requestedAeRegions != null) {
                        event.put("focusPointX", focusPointX);
                        event.put("focusPointY", focusPointY);
                    }
                    event.put("frameNumber", result.getFrameNumber());
                    if ((captureResultCounter % 30) == 0) appendDeviceTelemetry(event);
                    if (recording && mediaRecorder != null) {
                        try {
                            int amplitude = mediaRecorder.getMaxAmplitude();
                            double dbfs = amplitude <= 0
                                    ? -60.0
                                    : 20.0 * Math.log10(amplitude / 32767.0);
                            event.put("audioLevelDbfs",
                                    Math.max(-60.0, Math.min(0.0, dbfs)));
                        } catch (RuntimeException ignored) {
                        }
                    }
                    emit(event);
                }
            };

    private void configureZoomRange() {
        Range<Float> range = characteristics == null ? null : characteristics.get(
                CameraCharacteristics.CONTROL_ZOOM_RATIO_RANGE);
        if (range != null && range.getLower() != null && range.getUpper() != null) {
            minimumZoomRatio = Math.max(1.0f, range.getLower());
            maximumZoomRatio = Math.max(minimumZoomRatio, range.getUpper());
        } else {
            minimumZoomRatio = 1.0f;
            Float digitalMaximum = characteristics == null ? null : characteristics.get(
                    CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM);
            maximumZoomRatio = digitalMaximum == null
                    ? 10.0f : Math.max(1.0f, digitalMaximum);
        }
        float initial = clamp(actualZoomRatio, minimumZoomRatio, maximumZoomRatio);
        zoomLog2 = log2(initial);
        targetZoomLog2 = zoomLog2;
        actualZoomRatio = initial;
        zoomVelocityStopsPerSecond = 0.0;
        zoomControllerActive = false;
    }

    private void setZoomTargetInternal(float targetRatio) {
        volumeZoomDirection = 0;
        zoomDriveVelocityTarget = 0.0;
        zoomDriveBraking = false;
        float clamped = clamp(targetRatio, minimumZoomRatio, maximumZoomRatio);
        targetZoomLog2 = log2(clamped);
        if (Math.abs(targetZoomLog2 - zoomLog2) <= ZOOM_POSITION_EPSILON_STOPS) {
            zoomLog2 = targetZoomLog2;
            zoomVelocityStopsPerSecond = 0.0;
            zoomControllerActive = false;
        } else {
            zoomControllerActive = true;
        }
    }

    private void updateCaptureCadence(Long timestampNs, long frameNumber) {
        if (timestampNs != null && timestampNs > 0L) {
            if (lastSensorTimestampNs > 0L && timestampNs > lastSensorTimestampNs) {
                long interval = timestampNs - lastSensorTimestampNs;
                if (interval > 1_000_000L && interval < 500_000_000L) {
                    captureIntervalEmaNs = captureIntervalEmaNs <= 0.0
                            ? interval
                            : captureIntervalEmaNs * 0.90 + interval * 0.10;
                }
            }
            lastSensorTimestampNs = timestampNs;
        }
        if (lastCaptureFrameNumber >= 0L && frameNumber > lastCaptureFrameNumber + 1L) {
            captureFrameGaps += frameNumber - lastCaptureFrameNumber - 1L;
        }
        lastCaptureFrameNumber = frameNumber;
    }

    private void updateZoomController(long sensorTimestampNs, long frameNumber) {
        if (frameNumber == lastZoomUpdateFrameNumber) return;
        lastZoomUpdateFrameNumber = frameNumber;
        if (!zoomControllerActive || sensorTimestampNs <= 0L ||
                repeatingBuilder == null || captureSession == null) {
            if (sensorTimestampNs > 0L) lastZoomSensorTimestampNs = sensorTimestampNs;
            return;
        }
        if (lastZoomSensorTimestampNs <= 0L || sensorTimestampNs <= lastZoomSensorTimestampNs) {
            lastZoomSensorTimestampNs = sensorTimestampNs;
            return;
        }
        double dt = (sensorTimestampNs - lastZoomSensorTimestampNs) / 1_000_000_000.0;
        lastZoomSensorTimestampNs = sensorTimestampNs;
        dt = Math.max(1.0 / 240.0, Math.min(0.100, dt));

        if (zoomDriveVelocityTarget != 0.0 || zoomDriveBraking) {
            zoomVelocityStopsPerSecond = moveToward(
                    zoomVelocityStopsPerSecond,
                    zoomDriveVelocityTarget,
                    zoomAccelerationStopsPerSecondSquared * dt);
            zoomLog2 += zoomVelocityStopsPerSecond * dt;
            double minimumLog = log2(minimumZoomRatio);
            double maximumLog = log2(maximumZoomRatio);
            if (zoomLog2 <= minimumLog || zoomLog2 >= maximumLog) {
                zoomLog2 = Math.max(minimumLog, Math.min(maximumLog, zoomLog2));
                zoomVelocityStopsPerSecond = 0.0;
                if (zoomDriveVelocityTarget == 0.0 ||
                        (zoomLog2 <= minimumLog && zoomDriveVelocityTarget < 0.0) ||
                        (zoomLog2 >= maximumLog && zoomDriveVelocityTarget > 0.0)) {
                    zoomControllerActive = false;
                }
            }
            if (zoomDriveVelocityTarget == 0.0 &&
                    Math.abs(zoomVelocityStopsPerSecond) <= ZOOM_VELOCITY_EPSILON) {
                zoomVelocityStopsPerSecond = 0.0;
                zoomDriveBraking = false;
                zoomControllerActive = false;
                targetZoomLog2 = zoomLog2;
            }
            submitZoomRequest();
            return;
        }

        double distance = targetZoomLog2 - zoomLog2;
        double absoluteDistance = Math.abs(distance);
        if (absoluteDistance <= ZOOM_POSITION_EPSILON_STOPS &&
                Math.abs(zoomVelocityStopsPerSecond) <= ZOOM_VELOCITY_EPSILON) {
            zoomLog2 = targetZoomLog2;
            zoomVelocityStopsPerSecond = 0.0;
            zoomControllerActive = false;
            submitZoomRequest();
            return;
        }

        double direction = Math.signum(distance);
        // Braking speed derived from v² = 2*a*d. Far from the target this is
        // capped at the phone-tuned maximum; close to it, velocity tapers down.
        double brakingSpeed = Math.sqrt(
                2.0 * zoomAccelerationStopsPerSecondSquared * absoluteDistance);
        double desiredVelocity = direction * Math.min(
                zoomTargetRateStopsPerSecond, brakingSpeed);
        zoomVelocityStopsPerSecond = moveToward(
                zoomVelocityStopsPerSecond,
                desiredVelocity,
                zoomAccelerationStopsPerSecondSquared * dt);

        double step = zoomVelocityStopsPerSecond * dt;
        if (Math.signum(step) == direction && Math.abs(step) >= absoluteDistance) {
            zoomLog2 = targetZoomLog2;
            zoomVelocityStopsPerSecond = 0.0;
            zoomControllerActive = false;
        } else {
            zoomLog2 += step;
            zoomLog2 = Math.max(log2(minimumZoomRatio),
                    Math.min(log2(maximumZoomRatio), zoomLog2));
        }
        submitZoomRequest();
    }

    private void submitZoomRequest() {
        if (repeatingBuilder == null || captureSession == null) return;
        float ratio = zoomRatioFromLog(zoomLog2);
        if (Float.isFinite(lastSubmittedZoomRatio) &&
                Math.abs(ratio - lastSubmittedZoomRatio) < 0.00002f) return;
        try {
            setSafely(repeatingBuilder, CaptureRequest.CONTROL_ZOOM_RATIO, ratio);
            captureSession.setRepeatingRequest(
                    repeatingBuilder.build(), captureCallback, cameraHandler);
            lastSubmittedZoomRatio = ratio;
        } catch (Throwable error) {
            zoomControllerActive = false;
            zoomVelocityStopsPerSecond = 0.0;
            emitError("ZOOM_RAMP_FAILED", "Camera2 smooth zoom request failed", error);
        }
    }

    private void updateRepeatingRequest() throws CameraAccessException {
        if (repeatingBuilder == null || captureSession == null) return;
        applyControls(repeatingBuilder);
        captureSession.setRepeatingRequest(
                repeatingBuilder.build(), captureCallback, cameraHandler);
    }

    private void applyControls(CaptureRequest.Builder builder) {
        builder.set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_AUTO);
        int electronic = requestedStabilizationMode == 2
                ? CaptureRequest.CONTROL_VIDEO_STABILIZATION_MODE_ON
                : CaptureRequest.CONTROL_VIDEO_STABILIZATION_MODE_OFF;
        int optical = requestedStabilizationMode == 1
                ? CaptureRequest.LENS_OPTICAL_STABILIZATION_MODE_ON
                : CaptureRequest.LENS_OPTICAL_STABILIZATION_MODE_OFF;
        setSafely(builder, CaptureRequest.CONTROL_VIDEO_STABILIZATION_MODE,
                electronic);
        setSafely(builder, CaptureRequest.LENS_OPTICAL_STABILIZATION_MODE,
                optical);
        // The UI calls these controls Sharpness and Noise Reduction. Camera2's
        // public request key for sharpness processing is EDGE_MODE.
        setSafely(builder, CaptureRequest.EDGE_MODE, requestedSharpnessMode);
        setSafely(builder, CaptureRequest.NOISE_REDUCTION_MODE,
                requestedNoiseReductionMode);
        setSafely(builder, CaptureRequest.CONTROL_ZOOM_RATIO,
                zoomRatioFromLog(zoomLog2));

        if (autoExposure) {
            builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON);
            setSafely(builder, CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE,
                    new Range<>(requestedRecordFps, requestedRecordFps));
            setSafely(builder, CaptureRequest.CONTROL_AE_EXPOSURE_COMPENSATION,
                    exposureCompensationIndex(requestedExposureCompensationEv));
            setSafely(builder, CaptureRequest.CONTROL_AE_LOCK, aeAfLocked);
            if (requestedAeRegions != null) {
                setSafely(builder, CaptureRequest.CONTROL_AE_REGIONS, requestedAeRegions);
            }
        } else {
            setSafely(builder, CaptureRequest.CONTROL_AE_LOCK, false);
            setSafely(builder, CaptureRequest.CONTROL_AE_EXPOSURE_COMPENSATION, 0);
            builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_OFF);
            Range<Integer> isoRange = characteristics.get(
                    CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE);
            Range<Long> exposureRange = characteristics.get(
                    CameraCharacteristics.SENSOR_INFO_EXPOSURE_TIME_RANGE);
            int iso = isoRange == null ? requestedIso : clamp(
                    requestedIso, isoRange.getLower(), isoRange.getUpper());
            long exposure = exposureRange == null ? requestedExposureNs : clamp(
                    requestedExposureNs, exposureRange.getLower(), exposureRange.getUpper());
            long frameDurationNs = requestedFrameDurationNs();
            exposure = Math.min(exposure, frameDurationNs - 1_000_000L);
            builder.set(CaptureRequest.SENSOR_SENSITIVITY, iso);
            builder.set(CaptureRequest.SENSOR_EXPOSURE_TIME, exposure);
            builder.set(CaptureRequest.SENSOR_FRAME_DURATION, frameDurationNs);
        }

        if (autoFocus) {
            builder.set(CaptureRequest.CONTROL_AF_MODE,
                    tapAfActive
                            ? CaptureRequest.CONTROL_AF_MODE_AUTO
                            : CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_VIDEO);
            if (requestedAfRegions != null) {
                setSafely(builder, CaptureRequest.CONTROL_AF_REGIONS, requestedAfRegions);
            }
        } else {
            builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_OFF);
            Float minimumFocus = characteristics.get(
                    CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE);
            float max = minimumFocus == null ? 10.0f : minimumFocus;
            builder.set(CaptureRequest.LENS_FOCUS_DISTANCE,
                    Math.max(0.0f, Math.min(max, requestedFocusDistance)));
        }

        builder.set(CaptureRequest.CONTROL_AWB_MODE,
                whiteBalanceMode(requestedWhiteBalance));
                
        if (requestedHlgProfile && Build.VERSION.SDK_INT >= 33) {
            // HLG handles its own tonemapping via the DynamicRangeProfile
            // Do not override TONEMAP_MODE
        } else if (requestedLogProfile) {
            builder.set(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_CONTRAST_CURVE);
            builder.set(CaptureRequest.TONEMAP_CURVE, createLogTonemapCurve());
        } else {
            builder.set(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_CONTRAST_CURVE);
            switch (requestedFilmStyle) {
                case "Cinematic":
                    builder.set(CaptureRequest.TONEMAP_CURVE, createCinematicCurve());
                    break;
                case "Fuji":
                    builder.set(CaptureRequest.TONEMAP_CURVE, createFujiCurve());
                    break;
                case "Vivid":
                    builder.set(CaptureRequest.TONEMAP_CURVE, createVividCurve());
                    break;
                default:
                    // Apply a "Safe" Rec.709 curve that prevents shadows from crushing in 10-bit SDR
                    builder.set(CaptureRequest.TONEMAP_CURVE, createSafeRec709Curve());
                    break;
            }
        }
    }

    
    private TonemapCurve createLogTonemapCurve() {
        // Create a custom flattened S-curve to preserve highlights and lift shadows.
        // Format: [in_0, out_0, in_1, out_1, ..., in_N, out_N] on a 0.0 to 1.0 scale.
        // Aggressively flat pseudo-log curve to maximize dynamic range
        float[] curve = new float[] {
            0.0000f, 0.0000f, // MUST anchor at 0.0 to prevent black level corruption
            0.0100f, 0.1500f, // Extreme lift on the absolute black floor
            0.0200f, 0.2200f, 
            0.0500f, 0.3200f, // Push shadows out of the crushed zone
            0.1000f, 0.4200f, 
            0.2000f, 0.5200f, // Mid-gray sits much higher
            0.3000f, 0.6000f, 
            0.4000f, 0.6800f,
            0.6000f, 0.8200f, // Long, smooth shoulder for highlight roll-off
            0.8000f, 0.9400f,
            1.0000f, 1.0000f  // MUST anchor at 1.0 to prevent highlight solarization/artifacts
        };
        return new TonemapCurve(curve, curve, curve);
    }

    private void prepareRecorder() throws IOException {
        releaseRecorder(false);
        ContentResolver resolver = activity.getContentResolver();
        ContentValues values = new ContentValues();
        String timestamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US)
                .format(new Date());
        String mode = requestedRecordWidth + "x" + requestedRecordHeight +
                "_" + requestedRecordFps + "fps_" +
                (requestedVideoBitRate / 1_000_000) + "Mbps";
        values.put(MediaStore.Video.Media.DISPLAY_NAME,
                "ZC_" + timestamp + "_" + mode + "_HEVC.mp4");
        values.put(MediaStore.Video.Media.MIME_TYPE, "video/mp4");
        values.put(MediaStore.Video.Media.RELATIVE_PATH,
                Environment.DIRECTORY_MOVIES + "/ZirconCinema");
        values.put(MediaStore.Video.Media.IS_PENDING, 1);
        recordingUri = resolver.insert(
                MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY), values);
        if (recordingUri == null) throw new IOException("MediaStore insert returned null");
        recordingFileDescriptor = resolver.openFileDescriptor(recordingUri, "rw");
        if (recordingFileDescriptor == null) {
            throw new FileNotFoundException("Unable to open MediaStore output");
        }

        mediaRecorder = new MediaRecorder(activity);
        mediaRecorder.setAudioSource(MediaRecorder.AudioSource.MIC);
        mediaRecorder.setVideoSource(MediaRecorder.VideoSource.SURFACE);
        mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
        mediaRecorder.setOutputFile(recordingFileDescriptor.getFileDescriptor());
        mediaRecorder.setVideoEncoder(MediaRecorder.VideoEncoder.HEVC);
        if (requestedBitDepth == 10 && Build.VERSION.SDK_INT >= 26) {
            mediaRecorder.setVideoEncodingProfileLevel(
                    MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10,
                    MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel51);
        }
        mediaRecorder.setVideoSize(requestedRecordWidth, requestedRecordHeight);
        mediaRecorder.setVideoFrameRate(requestedRecordFps);
        mediaRecorder.setVideoEncodingBitRate(requestedVideoBitRate);
        mediaRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
        mediaRecorder.setAudioSamplingRate(AUDIO_SAMPLE_RATE);
        mediaRecorder.setAudioChannels(2);
        mediaRecorder.setAudioEncodingBitRate(AUDIO_BIT_RATE);
        mediaRecorder.setOrientationHint(recordingOrientationHint());
        mediaRecorder.prepare();
        recorderSurface = mediaRecorder.getSurface();
    }

    private void stopRecordingInternal(MethodChannel.Result result, boolean recreatePreview) {
        Uri completedUri = recordingUri;
        boolean stoppedCleanly = false;
        try {
            if (captureSession != null) {
                try {
                    captureSession.stopRepeating();
                    captureSession.abortCaptures();
                } catch (CameraAccessException ignored) {
                }
            }
            if (recording && mediaRecorder != null) {
                mediaRecorder.stop();
                stoppedCleanly = true;
            }
        } catch (RuntimeException error) {
            emitError("RECORD_STOP_FAILED",
                    "Recorder stopped before a valid MP4 could be finalized", error);
        } finally {
            recording = false;
            pendingRecordStartResult = null;
            closeSession();
            releaseRecorder(stoppedCleanly);
        }

        if (stoppedCleanly && completedUri != null) {
            lastClipUri = completedUri;
            ContentValues values = new ContentValues();
            values.put(MediaStore.Video.Media.IS_PENDING, 0);
            activity.getContentResolver().update(completedUri, values, null, null);
            emitState("ready", completedUri.toString());
        } else if (completedUri != null) {
            activity.getContentResolver().delete(completedUri, null, null);
        }

        if (recreatePreview && cameraDevice != null && !disposed.get()) {
            createPreviewSession();
        }

        if (result != null) {
            Map<String, Object> response = new HashMap<>();
            response.put("stopped", stoppedCleanly);
            response.put("uri", stoppedCleanly && completedUri != null
                    ? completedUri.toString() : null);
            replySuccess(result, response);
        }
    }

    private void failRecordStart(String message, Throwable error) {
        MethodChannel.Result result = pendingRecordStartResult;
        pendingRecordStartResult = null;
        recording = false;
        closeSession();
        releaseRecorder(false);
        replyError(result, "RECORD_START_FAILED", message, error);
        emitError("RECORD_START_FAILED", message, error);
        if (cameraDevice != null && !disposed.get()) createPreviewSession();
    }

    private void releaseRecorder(boolean keepMediaStoreItem) {
        if (p010Reader != null) {
            try { p010Reader.close(); } catch (Throwable ignored) {}
            p010Reader = null;
        }
        if (p010Writer != null) {
            try { p010Writer.close(); } catch (Throwable ignored) {}
            p010Writer = null;
        }
        if (recorderSurface != null) {
            recorderSurface.release();
            recorderSurface = null;
        }
        if (mediaRecorder != null) {
            try {
                mediaRecorder.reset();
            } catch (RuntimeException ignored) {
            }
            mediaRecorder.release();
            mediaRecorder = null;
        }
        if (recordingFileDescriptor != null) {
            try {
                recordingFileDescriptor.close();
            } catch (IOException ignored) {
            }
            recordingFileDescriptor = null;
        }
        if (!keepMediaStoreItem && recordingUri != null) {
            activity.getContentResolver().delete(recordingUri, null, null);
        }
        recordingUri = null;
    }

    private void closeSession() {
        if (captureSession != null) {
            try {
                captureSession.stopRepeating();
            } catch (Throwable ignored) {
            }
            captureSession.close();
            captureSession = null;
        }
        repeatingBuilder = null;
        lastZoomSensorTimestampNs = 0L;
        lastZoomUpdateFrameNumber = -1L;
        lastSubmittedZoomRatio = Float.NaN;
    }

    private void closeCameraOnly() {
        closeSession();
        if (cameraDevice != null) {
            cameraDevice.close();
            cameraDevice = null;
        }
        opening = false;
    }

    private void releasePreviewSurface() {
        // SurfaceProducer owns and may replace the Surface. Do not release the
        // cached Surface independently; release the producer as one unit.
        previewSurface = null;
        if (textureProducer != null) {
            textureProducer.setCallback(null);
            textureProducer.release();
            textureProducer = null;
        }
    }

    private void completeInitialization() {
        MethodChannel.Result result = pendingInitializeResult;
        pendingInitializeResult = null;
        replySuccess(result, initializationPayload());
    }

    private void failInitialization(String message, Throwable error) {
        MethodChannel.Result result = pendingInitializeResult;
        pendingInitializeResult = null;
        replyError(result, "INITIALIZATION_FAILED", message, error);
        emitError("INITIALIZATION_FAILED", message, error);
    }

    private Map<String, Object> initializationPayload() {
        Map<String, Object> response = new HashMap<>();
        response.put("textureId", textureProducer == null ? null : textureProducer.id());
        response.put("previewWidth", previewSize.getWidth());
        response.put("previewHeight", previewSize.getHeight());
        response.put("recordWidth", requestedRecordWidth);
                response.put("recordBitDepth", requestedBitDepth);
        response.put("recordHeight", requestedRecordHeight);
        response.put("fps", requestedRecordFps);
        response.put("videoBitRate", requestedVideoBitRate);
        response.put("cameraId", CAMERA_ID);
        response.put("rotationDegrees", previewRotationDegrees());
        response.put("engine", "Camera2");
        response.put("recorder", "MediaRecorder HEVC Main + AAC");
        response.put("tintSupported", false);
        response.put("minimumZoomRatio", minimumZoomRatio);
        response.put("logProfileSupported", true);
        response.put("maximumZoomRatio", maximumZoomRatio);
        response.put("zoomController", "capture-result-timed log2 ramp");
        Range<Integer> aeRange = characteristics == null ? null : characteristics.get(
                CameraCharacteristics.CONTROL_AE_COMPENSATION_RANGE);
        Rational aeStep = characteristics == null ? null : characteristics.get(
                CameraCharacteristics.CONTROL_AE_COMPENSATION_STEP);
        if (aeRange != null && aeStep != null) {
            response.put("exposureCompensationMinEv",
                    aeRange.getLower() * aeStep.doubleValue());
            response.put("exposureCompensationMaxEv",
                    aeRange.getUpper() * aeStep.doubleValue());
            response.put("exposureCompensationStepEv", aeStep.doubleValue());
        }
        return response;
    }

    private void emitState(String state, String uri) {
        Map<String, Object> event = new HashMap<>();
        event.put("type", "state");
        event.put("state", state);
        if (uri != null) event.put("uri", uri);
        emit(event);
    }

    private void emitError(String code, String message, Throwable error) {
        Map<String, Object> event = new HashMap<>();
        event.put("type", "error");
        event.put("state", "error");
        event.put("code", code);
        event.put("message", message);
        if (error != null) event.put("detail", error.toString());
        emit(event);
    }

    private void emit(Map<String, Object> event) {
        activity.runOnUiThread(() -> eventEmitter.emit(event));
    }

    private void appendDeviceTelemetry(Map<String, Object> event) {
        try {
            Intent battery = activity.registerReceiver(
                    null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
            if (battery != null) {
                int level = battery.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
                int scale = battery.getIntExtra(BatteryManager.EXTRA_SCALE, 100);
                if (level >= 0 && scale > 0) {
                    event.put("batteryPercent", Math.round(level * 100.0f / scale));
                }
                int status = battery.getIntExtra(
                        BatteryManager.EXTRA_STATUS, BatteryManager.BATTERY_STATUS_UNKNOWN);
                event.put("batteryCharging",
                        status == BatteryManager.BATTERY_STATUS_CHARGING ||
                                status == BatteryManager.BATTERY_STATUS_FULL);
            }
        } catch (Throwable ignored) {
        }
        try {
            StatFs stat = new StatFs(Environment.getDataDirectory().getAbsolutePath());
            event.put("storageAvailableBytes", stat.getAvailableBytes());
            event.put("storageTotalBytes", stat.getTotalBytes());
        } catch (Throwable ignored) {
        }
    }

    private MeteringRectangle[] supportedRegion(
            CameraCharacteristics.Key<Integer> maximumRegionsKey,
            MeteringRectangle region) {
        Integer maximum = characteristics == null ? null : characteristics.get(maximumRegionsKey);
        if (maximum == null || maximum <= 0 || region == null) return null;
        return new MeteringRectangle[]{region};
    }

    private Rect meteringCropRegion() {
        Rect active = characteristics == null ? null : characteristics.get(
                CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE);
        if (active == null || active.width() <= 0 || active.height() <= 0) {
            return new Rect(0, 0, 4080, 3060);
        }
        // Public preview/record streams are 16:9 while the active array is 4:3.
        // Meter against the centered 16:9 sensor crop used by UHD/preview.
        double targetAspect = (double) PREVIEW_WIDTH / (double) PREVIEW_HEIGHT;
        double activeAspect = (double) active.width() / (double) active.height();
        if (activeAspect < targetAspect) {
            int height = Math.max(1, (int) Math.round(active.width() / targetAspect));
            int top = active.top + (active.height() - height) / 2;
            return new Rect(active.left, top, active.right, top + height);
        }
        int width = Math.max(1, (int) Math.round(active.height() * targetAspect));
        int left = active.left + (active.width() - width) / 2;
        return new Rect(left, active.top, left + width, active.bottom);
    }

    private MeteringRectangle meteringRectangle(
            Rect crop, float displayX, float displayY, float sizeFraction) {
        float sensorX;
        float sensorY;
        switch (previewRotationDegrees()) {
            case 90 -> {
                sensorX = displayY;
                sensorY = 1.0f - displayX;
            }
            case 180 -> {
                sensorX = 1.0f - displayX;
                sensorY = 1.0f - displayY;
            }
            case 270 -> {
                sensorX = 1.0f - displayY;
                sensorY = displayX;
            }
            default -> {
                sensorX = displayX;
                sensorY = displayY;
            }
        }
        int centerX = crop.left + Math.round(clamp01(sensorX) * (crop.width() - 1));
        int centerY = crop.top + Math.round(clamp01(sensorY) * (crop.height() - 1));
        int half = Math.max(24,
                Math.round(Math.min(crop.width(), crop.height()) * sizeFraction * 0.5f));
        int left = clamp(centerX - half, crop.left, Math.max(crop.left, crop.right - 2));
        int top = clamp(centerY - half, crop.top, Math.max(crop.top, crop.bottom - 2));
        int right = clamp(centerX + half, left + 1, crop.right);
        int bottom = clamp(centerY + half, top + 1, crop.bottom);
        return new MeteringRectangle(
                new Rect(left, top, right, bottom),
                MeteringRectangle.METERING_WEIGHT_MAX);
    }

    private int previewRotationDegrees() {
        Integer sensorOrientation = characteristics == null ? null : characteristics.get(
                CameraCharacteristics.SENSOR_ORIENTATION);
        int displayDegrees = rotationToDegrees(activity.getDisplay().getRotation());
        int sensor = sensorOrientation == null ? 90 : sensorOrientation;
        return (sensor - displayDegrees + 360) % 360;
    }

    private int recordingOrientationHint() {
        return previewRotationDegrees();
    }

    private static int rotationToDegrees(int rotation) {
        return switch (rotation) {
            case Surface.ROTATION_90 -> 90;
            case Surface.ROTATION_180 -> 180;
            case Surface.ROTATION_270 -> 270;
            default -> 0;
        };
    }

    private int exposureCompensationIndex(float ev) {
        Range<Integer> range = characteristics.get(
                CameraCharacteristics.CONTROL_AE_COMPENSATION_RANGE);
        Rational step = characteristics.get(
                CameraCharacteristics.CONTROL_AE_COMPENSATION_STEP);
        if (range == null || step == null || step.floatValue() <= 0.0f) return 0;
        int index = Math.round(ev / step.floatValue());
        return clamp(index, range.getLower(), range.getUpper());
    }

    private static int whiteBalanceMode(String value) {
        return switch (value) {
            case "3200K" -> CaptureRequest.CONTROL_AWB_MODE_INCANDESCENT;
            case "4300K" -> CaptureRequest.CONTROL_AWB_MODE_WARM_FLUORESCENT;
            case "5600K" -> CaptureRequest.CONTROL_AWB_MODE_DAYLIGHT;
            case "6500K" -> CaptureRequest.CONTROL_AWB_MODE_CLOUDY_DAYLIGHT;
            default -> CaptureRequest.CONTROL_AWB_MODE_AUTO;
        };
    }

    private static String detailedMessage(String phase, Throwable error) {
        if (error == null) return phase;
        String detail = error.getMessage();
        if (detail == null || detail.isBlank()) detail = error.toString();
        return phase + ": " + error.getClass().getSimpleName() + ": " + detail;
    }

    private static String cameraErrorName(int error) {
        return switch (error) {
            case CameraDevice.StateCallback.ERROR_CAMERA_IN_USE -> "CAMERA_IN_USE";
            case CameraDevice.StateCallback.ERROR_MAX_CAMERAS_IN_USE -> "MAX_CAMERAS_IN_USE";
            case CameraDevice.StateCallback.ERROR_CAMERA_DISABLED -> "CAMERA_DISABLED";
            case CameraDevice.StateCallback.ERROR_CAMERA_DEVICE -> "CAMERA_DEVICE";
            case CameraDevice.StateCallback.ERROR_CAMERA_SERVICE -> "CAMERA_SERVICE";
            default -> "UNKNOWN_CAMERA_ERROR";
        };
    }

    private static boolean isTargetDevice() {
        return "23090RA98I".equalsIgnoreCase(Build.MODEL) ||
                "zircon".equalsIgnoreCase(Build.DEVICE);
    }

    private static boolean booleanValue(Object value, boolean fallback) {
        return value instanceof Boolean ? (Boolean) value : fallback;
    }

    private static int intValue(Object value, int fallback) {
        return value instanceof Number ? ((Number) value).intValue() : fallback;
    }

    private static long longValue(Object value, long fallback) {
        return value instanceof Number ? ((Number) value).longValue() : fallback;
    }

    private static float floatValue(Object value, float fallback) {
        return value instanceof Number ? ((Number) value).floatValue() : fallback;
    }

    private static float clamp01(float value) {
        return Math.max(0.0f, Math.min(1.0f, value));
    }

    private static float clamp(float value, float minimum, float maximum) {
        return Math.max(minimum, Math.min(maximum, value));
    }

    private static double log2(double value) {
        return Math.log(Math.max(value, 0.000001)) / LOG_2;
    }

    private static float zoomRatioFromLog(double logValue) {
        return (float) Math.pow(2.0, logValue);
    }

    private static double moveToward(double value, double target, double maximumDelta) {
        if (value < target) return Math.min(value + maximumDelta, target);
        return Math.max(value - maximumDelta, target);
    }

    private static int clamp(int value, int minimum, int maximum) {
        return Math.max(minimum, Math.min(maximum, value));
    }

    private static long clamp(long value, long minimum, long maximum) {
        return Math.max(minimum, Math.min(maximum, value));
    }

    private static <T> void setSafely(CaptureRequest.Builder builder,
                                      CaptureRequest.Key<T> key, T value) {
        try {
            builder.set(key, value);
        } catch (IllegalArgumentException ignored) {
        }
    }

    private static void putNumber(Map<String, Object> map, String key, Number value) {
        if (value != null) map.put(key, value);
    }

    private void replySuccess(MethodChannel.Result result, Object value) {
        if (result == null) return;
        activity.runOnUiThread(() -> result.success(value));
    }

    private void replyError(MethodChannel.Result result, String code,
                            String message, Throwable error) {
        if (result == null) return;
        String detail = error == null ? null : error.toString();
        activity.runOnUiThread(() -> result.error(code, message, detail));
    }

    private TonemapCurve createSafeRec709Curve() {
        // Reverted the "washed out" look. This is a punchy, true-to-life standard Rec.709 
        // with deep blacks that don't crush artificially, but aren't gray/faded.
        float[] curve = new float[] {
            0.0000f, 0.0000f,
            0.0500f, 0.0300f, 
            0.1000f, 0.0900f,
            0.2000f, 0.2200f,
            0.3000f, 0.3500f, 
            0.5000f, 0.5800f,
            0.7000f, 0.7800f,
            0.8500f, 0.9000f,
            1.0000f, 1.0000f
        };
        return new TonemapCurve(curve, curve, curve);
    }

    private TonemapCurve createCinematicCurve() {
        // Teal & Orange: Blue shadows, warm highlights
        float[] r = new float[] { 0.0f,0.0f, 0.05f,0.04f, 0.1f,0.09f, 0.2f,0.19f, 0.3f,0.30f, 0.5f,0.52f, 0.7f,0.74f, 0.85f,0.88f, 1.0f,1.0f };
        float[] g = new float[] { 0.0f,0.0f, 0.05f,0.05f, 0.1f,0.11f, 0.2f,0.21f, 0.3f,0.32f, 0.5f,0.51f, 0.7f,0.72f, 0.85f,0.86f, 1.0f,1.0f };
        float[] b = new float[] { 0.0f,0.02f, 0.05f,0.08f, 0.1f,0.14f, 0.2f,0.24f, 0.3f,0.34f, 0.5f,0.50f, 0.7f,0.68f, 0.85f,0.82f, 1.0f,0.95f };
        return new TonemapCurve(r, g, b);
    }

    private TonemapCurve createFujiCurve() {
        // True Fujifilm Classic Warm emulation using 1D curves:
        // 1. Red channel is pushed up in midtones/highlights for warm, glowing skin tones.
        // 2. Blue channel is pulled down in the mids (adding yellow/warmth) but lifted at 0.0 for faded vintage shadows.
        // 3. Overall contrast is "hard" in the middle, soft at the edges.
        float[] r = new float[] { 0.0f,0.00f, 0.05f,0.04f, 0.1f,0.12f, 0.2f,0.24f, 0.3f,0.36f, 0.5f,0.58f, 0.7f,0.78f, 0.85f,0.88f, 0.95f,0.96f, 1.0f,1.00f };
        float[] g = new float[] { 0.0f,0.00f, 0.05f,0.03f, 0.1f,0.09f, 0.2f,0.21f, 0.3f,0.32f, 0.5f,0.52f, 0.7f,0.73f, 0.85f,0.86f, 0.95f,0.94f, 1.0f,1.00f };
        float[] b = new float[] { 0.0f,0.03f, 0.05f,0.05f, 0.1f,0.08f, 0.2f,0.17f, 0.3f,0.26f, 0.5f,0.45f, 0.7f,0.66f, 0.85f,0.81f, 0.95f,0.92f, 1.0f,0.98f };
        return new TonemapCurve(r, g, b);
    }

    private TonemapCurve createVividCurve() {
        // iPhone Vivid: Deep, rich contrast.
        // Shadows are slightly crushed for impact, mids are pushed hard.
        // Blue channel is boosted in highlights for crisp skies.
        float[] r = new float[] { 0.0f,0.00f, 0.05f,0.02f, 0.1f,0.06f, 0.2f,0.16f, 0.3f,0.28f, 0.5f,0.55f, 0.7f,0.78f, 0.85f,0.89f, 0.95f,0.96f, 1.0f,1.0f };
        float[] g = new float[] { 0.0f,0.00f, 0.05f,0.02f, 0.1f,0.06f, 0.2f,0.16f, 0.3f,0.28f, 0.5f,0.55f, 0.7f,0.78f, 0.85f,0.89f, 0.95f,0.96f, 1.0f,1.0f };
        float[] b = new float[] { 0.0f,0.00f, 0.05f,0.02f, 0.1f,0.07f, 0.2f,0.18f, 0.3f,0.30f, 0.5f,0.58f, 0.7f,0.82f, 0.85f,0.92f, 0.95f,0.97f, 1.0f,1.0f };
        return new TonemapCurve(r, g, b);
    }

    private TonemapCurve createFujiCurve() {
        float[] r = new float[] { 0.0f,0.03f, 0.05f,0.05f, 0.1f,0.10f, 0.2f,0.20f, 0.3f,0.31f, 0.5f,0.53f, 0.7f,0.73f, 0.85f,0.86f, 0.95f,0.93f, 1.0f,0.96f };
        float[] g = new float[] { 0.0f,0.03f, 0.05f,0.07f, 0.1f,0.13f, 0.2f,0.25f, 0.3f,0.36f, 0.5f,0.56f, 0.7f,0.75f, 0.85f,0.88f, 0.95f,0.94f, 1.0f,0.97f };
        float[] b = new float[] { 0.0f,0.06f, 0.05f,0.09f, 0.1f,0.12f, 0.2f,0.19f, 0.3f,0.29f, 0.5f,0.50f, 0.7f,0.70f, 0.85f,0.84f, 0.95f,0.91f, 1.0f,0.95f };
        return new TonemapCurve(r, g, b);
    }

    private TonemapCurve createVividCurve() {
        float[] r = new float[] { 0.0f,0.00f, 0.05f,0.02f, 0.1f,0.08f, 0.2f,0.18f, 0.3f,0.32f, 0.5f,0.58f, 0.7f,0.80f, 0.85f,0.91f, 0.95f,0.96f, 1.0f,1.0f };
        float[] g = new float[] { 0.0f,0.00f, 0.05f,0.02f, 0.1f,0.07f, 0.2f,0.17f, 0.3f,0.30f, 0.5f,0.55f, 0.7f,0.78f, 0.85f,0.90f, 0.95f,0.95f, 1.0f,1.0f };
        float[] b = new float[] { 0.0f,0.00f, 0.05f,0.03f, 0.1f,0.07f, 0.2f,0.15f, 0.3f,0.27f, 0.5f,0.52f, 0.7f,0.76f, 0.85f,0.93f, 0.95f,0.97f, 1.0f,1.0f };
        return new TonemapCurve(r, g, b);
    }

}