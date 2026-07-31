package ai.arena.zirconcinema.ui;

import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public final class MainActivity extends FlutterActivity {
    private static final String METHOD_CHANNEL = "ai.arena.zirconcinema/camera";
    private static final String EVENT_CHANNEL = "ai.arena.zirconcinema/camera_events";
    private static final int CAMERA_PERMISSION_REQUEST = 2309;

    private CameraEngine cameraEngine;
    private EventChannel.EventSink eventSink;
    private MethodChannel.Result pendingPermissionResult;

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        cameraEngine = new CameraEngine(
                this,
                flutterEngine.getRenderer(),
                this::emitCameraEvent);

        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                METHOD_CHANNEL).setMethodCallHandler(this::handleMethodCall);

        new EventChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                EVENT_CHANNEL).setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                eventSink = events;
            }

            @Override
            public void onCancel(Object arguments) {
                eventSink = null;
            }
        });
    }

    private void handleMethodCall(MethodCall call, MethodChannel.Result result) {
        if (cameraEngine == null) {
            result.error("ENGINE_UNAVAILABLE", "Camera2 engine is unavailable", null);
            return;
        }
        switch (call.method) {
            case "initialize" -> ensurePermissionsAndInitialize(result);
            case "setControls" -> cameraEngine.updateControls(argumentsMap(call), result);
            case "setZoomTarget" -> cameraEngine.setZoomTarget(argumentsMap(call), result);
            case "tapToFocus" -> cameraEngine.tapToFocus(argumentsMap(call), result);
            case "setAeAfLock" -> cameraEngine.setAeAfLock(
                    call.argument("locked") == Boolean.TRUE, result);
            case "startRecording" -> cameraEngine.startRecording(result);
            case "stopRecording" -> cameraEngine.stopRecording(result);
            case "pause" -> {
                cameraEngine.pause();
                result.success(null);
            }
            case "resume" -> {
                cameraEngine.resume();
                result.success(null);
            }
            case "openLastClip" -> openLastClip(result);
            case "dispose" -> {
                cameraEngine.dispose();
                result.success(null);
            }
            default -> result.notImplemented();
        }
    }

    private void ensurePermissionsAndInitialize(MethodChannel.Result result) {
        if (hasPermission(Manifest.permission.CAMERA) &&
                hasPermission(Manifest.permission.RECORD_AUDIO)) {
            cameraEngine.initialize(result);
            return;
        }
        if (pendingPermissionResult != null) {
            result.error("PERMISSION_IN_PROGRESS",
                    "Camera and microphone permission request is already active", null);
            return;
        }
        pendingPermissionResult = result;
        requestPermissions(
                new String[]{Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO},
                CAMERA_PERMISSION_REQUEST);
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions,
                                           int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode != CAMERA_PERMISSION_REQUEST) return;
        MethodChannel.Result result = pendingPermissionResult;
        pendingPermissionResult = null;
        if (result == null) return;
        if (hasPermission(Manifest.permission.CAMERA) &&
                hasPermission(Manifest.permission.RECORD_AUDIO)) {
            cameraEngine.initialize(result);
        } else {
            result.error("PERMISSION_DENIED",
                    "Camera and microphone permissions are required for real UHD video with AAC audio.",
                    null);
        }
    }

    private void openLastClip(MethodChannel.Result result) {
        Uri uri = cameraEngine.getLastClipUri();
        if (uri == null) {
            result.error("NO_CLIP", "No completed Zircon Cinema clip is available", null);
            return;
        }
        try {
            Intent intent = new Intent(Intent.ACTION_VIEW)
                    .setDataAndType(uri, "video/mp4")
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            startActivity(intent);
            result.success(uri.toString());
        } catch (Throwable error) {
            result.error("OPEN_CLIP_FAILED",
                    "No compatible video player could open the clip", error.toString());
        }
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> argumentsMap(MethodCall call) {
        if (call.arguments instanceof Map) {
            return (Map<String, Object>) call.arguments;
        }
        return new HashMap<>();
    }

    private boolean hasPermission(String permission) {
        return checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED;
    }

    private void emitCameraEvent(Map<String, Object> event) {
        EventChannel.EventSink sink = eventSink;
        if (sink != null) sink.success(event);
    }

    @Override
    protected void onPause() {
        if (cameraEngine != null) cameraEngine.pause();
        super.onPause();
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (cameraEngine != null) cameraEngine.resume();
    }

    @Override
    protected void onDestroy() {
        if (cameraEngine != null) cameraEngine.dispose();
        super.onDestroy();
    }
}
