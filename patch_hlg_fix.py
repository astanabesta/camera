import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# We need to make sure the app doesn't crash if HLG is not supported by the device capability
# Let's add a try-catch and fallback
old_block = '''        if (Build.VERSION.SDK_INT >= 33 && requestedHlgProfile) {
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
        } else {'''

new_block = '''        if (Build.VERSION.SDK_INT >= 33 && requestedHlgProfile) {
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
        } else {'''

content = content.replace(old_block, new_block)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
