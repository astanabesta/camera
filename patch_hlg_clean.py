import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# 1. Imports
if 'import android.hardware.camera2.params.DynamicRangeProfiles;' not in content:
    content = content.replace('import android.hardware.camera2.params.TonemapCurve;', 'import android.hardware.camera2.params.TonemapCurve;\nimport android.hardware.camera2.params.DynamicRangeProfiles;\nimport android.hardware.camera2.params.SessionConfiguration;\nimport android.hardware.camera2.params.OutputConfiguration;\nimport java.util.concurrent.Executor;')

# 2. Add Field
if 'private boolean requestedHlgProfile = false;' not in content:
    content = content.replace('private boolean requestedLogProfile = false;', 'private boolean requestedLogProfile = false;\n    private boolean requestedHlgProfile = false;')

# 3. Add to updateControls
old_controls = 'requestedLogProfile = booleanValue(values.get("logProfile"), requestedLogProfile);'
new_controls = 'requestedLogProfile = booleanValue(values.get("logProfile"), requestedLogProfile);\n                requestedHlgProfile = booleanValue(values.get("hlgProfile"), requestedHlgProfile);'
content = content.replace(old_controls, new_controls)

# 4. createRecordingSession logic
pattern = r'cameraDevice\.createCaptureSession\(\s*Arrays\.asList\(sessionPreviewSurface,\s*finalTargetSurface\),\s*new CameraCaptureSession\.StateCallback\(\)\s*\{.*?\},\s*cameraHandler\);\s*\}'

new_session_logic = '''
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
        } else {
            cameraDevice.createCaptureSession(
                    Arrays.asList(sessionPreviewSurface, finalTargetSurface),
                    stateCallback, cameraHandler);
        }
    }'''

content = re.sub(pattern, new_session_logic, content, flags=re.DOTALL)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
