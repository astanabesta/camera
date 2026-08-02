import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# 1. Imports
if 'import android.hardware.camera2.params.DynamicRangeProfiles;' not in content:
    content = content.replace('import android.hardware.camera2.params.TonemapCurve;', 'import android.hardware.camera2.params.TonemapCurve;\nimport android.hardware.camera2.params.DynamicRangeProfiles;\nimport android.hardware.camera2.params.SessionConfiguration;\nimport android.hardware.camera2.params.OutputConfiguration;\nimport java.util.concurrent.Executor;')

# 2. Add HLG boolean
if 'private boolean requestedHlgProfile = false;' not in content:
    content = content.replace('private boolean requestedLogProfile = false;', 'private boolean requestedLogProfile = false;\n    private boolean requestedHlgProfile = false;')

# 3. Add to updateControls
old_controls = 'requestedLogProfile = booleanValue(values.get("logProfile"), requestedLogProfile);'
new_controls = 'requestedLogProfile = booleanValue(values.get("logProfile"), requestedLogProfile);\n                requestedHlgProfile = booleanValue(values.get("hlgProfile"), requestedHlgProfile);'
content = content.replace(old_controls, new_controls)

# 4. createRecordingSession logic
old_session = '''cameraDevice.createCaptureSession(
                Arrays.asList(sessionPreviewSurface, finalTargetSurface),
                new CameraCaptureSession.StateCallback() {
                    @Override
                    public void onConfigured(CameraCaptureSession session) {'''

new_session = '''if (Build.VERSION.SDK_INT >= 33 && requestedHlgProfile) {
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
                    new CameraCaptureSession.StateCallback() {
                        @Override
                        public void onConfigured(CameraCaptureSession session) {
                            configureRecordingSessionInternal(session, sessionPreviewSurface, finalTargetSurface);
                        }
                        @Override
                        public void onConfigureFailed(CameraCaptureSession session) {
                            failRecordStart("Camera2 UHD recording session configuration failed", null);
                        }
                    });
            cameraDevice.createCaptureSession(sessionConfig);
        } else {
            cameraDevice.createCaptureSession(
                    Arrays.asList(sessionPreviewSurface, finalTargetSurface),
                    new CameraCaptureSession.StateCallback() {
                        @Override
                        public void onConfigured(CameraCaptureSession session) {
                            configureRecordingSessionInternal(session, sessionPreviewSurface, finalTargetSurface);
                        }
                        @Override
                        public void onConfigureFailed(CameraCaptureSession session) {
                            failRecordStart("Camera2 UHD recording session configuration failed", null);
                        }
                    }, cameraHandler);
        }
    }
    
    private void configureRecordingSessionInternal(CameraCaptureSession session, Surface sessionPreviewSurface, Surface finalTargetSurface) {'''

# replace capturing everything till mediaRecorder.start()
replace_pattern = r'''cameraDevice\.createCaptureSession\(\s*Arrays\.asList\(sessionPreviewSurface,\s*finalTargetSurface\),\s*new CameraCaptureSession\.StateCallback\(\)\s*\{\s*@Override\s*public void onConfigured\(CameraCaptureSession session\)\s*\{'''

content = re.sub(replace_pattern, new_session, content)

# 5. Fix closing brace for configureRecordingSessionInternal
# Look for:
old_fail = '''failRecordStart("Camera2 UHD recording session configuration failed", null);
                    }
                },
                cameraHandler);
    }'''
new_fail = '''failRecordStart("Camera2 UHD recording session configuration failed", null);
                    }
                },
                cameraHandler);
    }*/'''
# we actually just replaced the start, let's do a more surgical replacement for the end
content = content.replace('failRecordStart("Camera2 UHD recording session configuration failed", null);\n                    }\n                },\n                cameraHandler);\n    }', '/* REMOVED */\n    }')


# 6. Let's do this cleaner using string splits.
