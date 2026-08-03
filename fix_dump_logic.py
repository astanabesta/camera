import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# The issue is that the dump logic is inside the `if (p010Writer != null && recording)` block!
# This means the button ONLY works if you press it WHILE you are actively recording a video!
# If the user presses it while just looking at the preview (not recording), `recording` is false,
# so the `else { image.close(); }` branch triggers and it ignores the dump request.

old_logic = '''                p010Reader.setOnImageAvailableListener(reader -> {
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
                                if (requestP010Dump) {
                                    requestP010Dump = false;
                                    dumpRawP010ToDisk(image);
                                }

                                p010Writer.queueInputImage(image);
                                frameCount[0]++;
                            } else {
                                image.close();
                            }
                        }
                    } catch (Throwable ignored) {}
                }, cameraHandler);'''

new_logic = '''                p010Reader.setOnImageAvailableListener(reader -> {
                    try {
                        Image image = reader.acquireNextImage();
                        if (image != null) {
                            // 1. Process diagnostic dump FIRST, regardless of whether we are actively recording.
                            if (requestP010Dump) {
                                requestP010Dump = false;
                                dumpRawP010ToDisk(image);
                            }
                            
                            // 2. Process video encoding if recording is active
                            if (p010Writer != null && recording) {
                                if (frameCount[0] == 0) {
                                    baseTimeNs[0] = System.nanoTime();
                                }
                                // Force absolutely perfect Constant Frame Rate (CFR)
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

content = content.replace(old_logic, new_logic)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
