import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# 1. Import TonemapCurve
if 'import android.hardware.camera2.params.TonemapCurve;' not in content:
    content = content.replace('import android.hardware.camera2.params.StreamConfigurationMap;', 'import android.hardware.camera2.params.StreamConfigurationMap;\nimport android.hardware.camera2.params.TonemapCurve;')

# 2. Add Field
if 'private boolean requestedLogProfile = false;' not in content:
    content = content.replace('private int requestedBitDepth = 10;', 'private int requestedBitDepth = 10;\n    private boolean requestedLogProfile = false;')

# 3. Add to updateControls
old_controls = 'requestedNoiseReductionMode = intValue(\n                        values.get("noiseReductionMode"), requestedNoiseReductionMode);'
new_controls = 'requestedNoiseReductionMode = intValue(\n                        values.get("noiseReductionMode"), requestedNoiseReductionMode);\n                requestedLogProfile = booleanValue(values.get("logProfile"), requestedLogProfile);'
content = content.replace(old_controls, new_controls)

# 4. Add tonemap generation method
tonemap_method = '''
    private TonemapCurve createLogTonemapCurve() {
        // Create a custom flattened S-curve to preserve highlights and lift shadows.
        // Format: [in_0, out_0, in_1, out_1, ..., in_N, out_N] on a 0.0 to 1.0 scale.
        float[] curve = new float[] {
            0.0000f, 0.0500f, // Lift blacks slightly to preserve noise floor
            0.0500f, 0.1500f, // Boost deep shadows
            0.1000f, 0.2500f, // Boost shadows
            0.2000f, 0.3500f,
            0.3000f, 0.4500f, // Midtones raised
            0.5000f, 0.6000f,
            0.7000f, 0.7000f, // Highlight compression starts
            0.8500f, 0.7800f, // Knee rolls off smoothly
            0.9500f, 0.8500f,
            1.0000f, 0.9000f  // Drop peak white to prevent hard clipping
        };
        return new TonemapCurve(curve, curve, curve);
    }
'''
if 'private TonemapCurve createLogTonemapCurve()' not in content:
    content = content.replace('private void prepareRecorder() throws IOException {', tonemap_method + '\n    private void prepareRecorder() throws IOException {')

# 5. Apply tonemap in applyControls
old_apply = 'builder.set(CaptureRequest.CONTROL_AWB_MODE,\n                whiteBalanceMode(requestedWhiteBalance));'
new_apply = '''builder.set(CaptureRequest.CONTROL_AWB_MODE,
                whiteBalanceMode(requestedWhiteBalance));
                
        if (requestedLogProfile) {
            builder.set(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_CONTRAST_CURVE);
            builder.set(CaptureRequest.TONEMAP_CURVE, createLogTonemapCurve());
        } else {
            builder.set(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_HIGH_QUALITY);
        }'''
content = content.replace(old_apply, new_apply)

# 6. Add to initialization payload
old_init = 'response.put("minimumZoomRatio", minimumZoomRatio);'
new_init = 'response.put("minimumZoomRatio", minimumZoomRatio);\n        response.put("logProfileSupported", true);'
content = content.replace(old_init, new_init)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
