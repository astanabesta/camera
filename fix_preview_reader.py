import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

old_preview = '''    private void createPreviewSession() {
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
    }'''

new_preview = '''    private void createPreviewSession() {
        if (cameraDevice == null) return;
        closeSession();
        
        final Surface sessionPreviewSurface;
        try {
            sessionPreviewSurface = obtainPreviewSurface();
            
            // To allow the Diagnostic Dumper to work BEFORE recording starts, we must initialize the P010 reader here as well.
            if (p010Reader != null) {
                try { p010Reader.close(); } catch (Throwable ignored) {}
            }
            p010Reader = ImageReader.newInstance(requestedRecordWidth, requestedRecordHeight, ImageFormat.YCBCR_P010, 2);
            p010Reader.setOnImageAvailableListener(reader -> {
                try {
                    Image image = reader.acquireNextImage();
                    if (image != null) {
                        if (requestP010Dump) {
                            requestP010Dump = false;
                            dumpRawP010ToDisk(image);
                        }
                        image.close();
                    }
                } catch (Throwable ignored) {}
            }, cameraHandler);
            
            cameraDevice.createCaptureSession(
                    Arrays.asList(sessionPreviewSurface, p010Reader.getSurface()),
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
                                repeatingBuilder.addTarget(p010Reader.getSurface()); // Feed the diagnostic reader constantly
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
    }'''

content = content.replace(old_preview, new_preview)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
