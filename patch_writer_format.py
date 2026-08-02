import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# Make sure ImageWriter max images is set higher to prevent frame drops in the buffer queue
old_writer = 'p010Writer = ImageWriter.newInstance(recorderSurface, 4, ImageFormat.YCBCR_P010);'
new_writer = 'p010Writer = ImageWriter.newInstance(recorderSurface, 8, ImageFormat.YCBCR_P010);'
content = content.replace(old_writer, new_writer)

old_reader = 'p010Reader = ImageReader.newInstance(requestedRecordWidth, requestedRecordHeight, ImageFormat.YCBCR_P010, 4);'
new_reader = 'p010Reader = ImageReader.newInstance(requestedRecordWidth, requestedRecordHeight, ImageFormat.YCBCR_P010, 8);'
content = content.replace(old_reader, new_reader)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
