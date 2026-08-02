import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# 1. Add requestedBitDepth
if 'private int requestedBitDepth = 10;' not in content and 'private int requestedBitDepth' not in content:
    content = content.replace('private int requestedVideoBitRate = DEFAULT_VIDEO_BIT_RATE;', 'private int requestedVideoBitRate = DEFAULT_VIDEO_BIT_RATE;\n    private int requestedBitDepth = 10;')

# 2. updateRecordingConfiguration parse requestedBitDepth
old_update_rec = '''    private void updateRecordingConfiguration(Map<String, Object> values) {
        int width = intValue(values.get("recordWidth"), requestedRecordWidth);'''
new_update_rec = '''    private void updateRecordingConfiguration(Map<String, Object> values) {
        requestedBitDepth = intValue(values.get("recordBitDepth"), requestedBitDepth);
        int width = intValue(values.get("recordWidth"), requestedRecordWidth);'''
content = content.replace(old_update_rec, new_update_rec)

# 3. prepareRecorder conditionally set 10-bit
old_prepare = '''if (Build.VERSION.SDK_INT >= 26) {
            mediaRecorder.setVideoEncodingProfileLevel(
                    MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10,
                    MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel51);
        }'''
new_prepare = '''if (requestedBitDepth == 10 && Build.VERSION.SDK_INT >= 26) {
            mediaRecorder.setVideoEncodingProfileLevel(
                    MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10,
                    MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel51);
        }'''
content = content.replace(old_prepare, new_prepare)

# 4. createRecordingSession conditional imageWriter
old_create = '''try {
            if (Build.VERSION.SDK_INT >= 33) {
                p010Writer = ImageWriter.newInstance(recorderSurface, 4, ImageFormat.YCBCR_P010);'''
new_create = '''try {
            if (requestedBitDepth == 10 && Build.VERSION.SDK_INT >= 33) {
                p010Writer = ImageWriter.newInstance(recorderSurface, 4, ImageFormat.YCBCR_P010);'''
content = content.replace(old_create, new_create)

# 5. response.put codec text
old_codec = '''response.put("codec", "HEVC Main10 10-bit (Zero-Copy)");'''
new_codec = '''response.put("codec", requestedBitDepth == 10 ? "HEVC Main10 10-bit (Zero-Copy)" : "HEVC Main 8-bit");'''
content = content.replace(old_codec, new_codec)

# 6. response in updateControls
old_controls_resp = '''response.put("recordWidth", requestedRecordWidth);'''
new_controls_resp = '''response.put("recordWidth", requestedRecordWidth);
                response.put("recordBitDepth", requestedBitDepth);'''
content = content.replace(old_controls_resp, new_controls_resp)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
