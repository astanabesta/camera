import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

old_listener = '''                p010Reader.setOnImageAvailableListener(reader -> {
                    try {
                        Image image = reader.acquireNextImage();
                        if (image != null) {
                            if (p010Writer != null) {
                                p010Writer.queueInputImage(image);
                            } else {
                                image.close();
                            }
                        }
                    } catch (Throwable ignored) {}
                }, cameraHandler);'''

new_listener = '''                p010Reader.setOnImageAvailableListener(reader -> {
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
                }, cameraHandler);'''

content = content.replace(old_listener, new_listener)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
