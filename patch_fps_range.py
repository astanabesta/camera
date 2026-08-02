import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# We need to strictly enforce the FPS range on the camera request
old_fps = '''        if (autoExposure) {
            builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON);
            setSafely(builder, CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE,
                    new Range<>(requestedRecordFps, requestedRecordFps));'''

new_fps = '''        if (autoExposure) {
            builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON);
            
            // STRICTLY enforce constant framerate by locking AE target to [30, 30]
            // If we don't do this, Xiaomi's ISP will dynamically drop the framerate in low light to gather more exposure
            setSafely(builder, CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE,
                    new Range<>(requestedRecordFps, requestedRecordFps));'''

content = content.replace(old_fps, new_fps)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
