import re

def main():
    with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
        content = f.read()

    new_method = """    /** Step 3: encode a known 10-bit P010 ramp and preserve the MP4 for inspection. */
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
"""

    pattern = r'/\*\* Step 3: encode a known 10-bit P010 ramp and preserve the MP4 for inspection\. \*/\s*public void runHevcMain10RampTest\(MethodChannel\.Result result\) \{.*?^\s*\}\s*private static void fillP010Ramp.*?\}\s*\}'
    
    new_content = re.sub(pattern, new_method, content, flags=re.DOTALL | re.MULTILINE)
    
    if new_content == content:
        print("Replacement failed")
    else:
        with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
            f.write(new_content)
        print("Replacement success")

main()
