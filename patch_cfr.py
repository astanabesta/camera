import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

old_listener = '''                final long[] timeOffset = {0L};
                final boolean[] isFirstFrame = {true};

                p010Reader.setOnImageAvailableListener(reader -> {
                    try {
                        Image image = reader.acquireNextImage();
                        if (image != null) {
                            if (p010Writer != null && recording) {
                                if (isFirstFrame[0]) {
                                    // Calculate offset between Camera hardware clock and MediaRecorder clock
                                    timeOffset[0] = System.nanoTime() - image.getTimestamp();
                                    isFirstFrame[0] = false;
                                }
                                // Preserve flawless hardware cadence, just shifted to the correct timebase
                                image.setTimestamp(image.getTimestamp() + timeOffset[0]);
                                p010Writer.queueInputImage(image);
                            } else {
                                image.close();
                            }
                        }
                    } catch (Throwable ignored) {}
                }, cameraHandler);'''

new_listener = '''                final long[] baseTimeNs = {0L};
                final long[] frameCount = {0L};

                p010Reader.setOnImageAvailableListener(reader -> {
                    try {
                        Image image = reader.acquireNextImage();
                        if (image != null) {
                            if (p010Writer != null && recording) {
                                if (frameCount[0] == 0) {
                                    baseTimeNs[0] = System.nanoTime();
                                }
                                // Force absolutely perfect Constant Frame Rate (CFR)
                                // This completely eliminates any Variable Frame Rate (VFR) jitter from the camera sensor
                                long syntheticTimestampNs = baseTimeNs[0] + (frameCount[0] * 1_000_000_000L / requestedRecordFps);
                                image.setTimestamp(syntheticTimestampNs);
                                p010Writer.queueInputImage(image);
                                frameCount[0]++;
                            } else {
                                image.close();
                            }
                        }
                    } catch (Throwable ignored) {}
                }, cameraHandler);'''

content = content.replace(old_listener, new_listener)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)

