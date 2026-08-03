import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# On modern Android versions (11+), writing to getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
# puts the file in `Android/data/ai.arena.zirconcinema/files/Download` which is hidden from normal file managers.
# The user expects it to be in the actual public "Downloads" folder.
# Let's rewrite it to use MediaStore to save the binary file directly to the public Downloads folder.

old_dump = '''    private void dumpRawP010ToDisk(Image image) {
        try {
            java.io.File dir = activity.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS);
            java.io.File file = new java.io.File(dir, "ZIRCON_RAW_" + image.getWidth() + "x" + image.getHeight() + "_" + System.currentTimeMillis() + ".yuv");
            try (java.io.FileOutputStream fos = new java.io.FileOutputStream(file)) {
                ByteBuffer y = image.getPlanes()[0].getBuffer();
                ByteBuffer uv = image.getPlanes()[1].getBuffer();
                y.position(0); uv.position(0);
                byte[] yBytes = new byte[y.remaining()];
                y.get(yBytes);
                fos.write(yBytes);
                byte[] uvBytes = new byte[uv.remaining()];
                uv.get(uvBytes);
                fos.write(uvBytes);
            }
            emitState("p010_dump_complete", file.getAbsolutePath());
        } catch (Exception e) {
            emitError("DUMP_FAILED", "Failed to dump raw P010 frame", e);
        }
    }'''

new_dump = '''    private void dumpRawP010ToDisk(Image image) {
        try {
            String filename = "ZIRCON_RAW_" + image.getWidth() + "x" + image.getHeight() + "_" + System.currentTimeMillis() + ".yuv";
            
            ContentValues values = new ContentValues();
            values.put(MediaStore.MediaColumns.DISPLAY_NAME, filename);
            values.put(MediaStore.MediaColumns.MIME_TYPE, "application/octet-stream");
            values.put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS);
            
            Uri uri = activity.getContentResolver().insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values);
            if (uri == null) throw new IOException("Failed to create MediaStore entry for raw dump.");
            
            try (java.io.OutputStream out = activity.getContentResolver().openOutputStream(uri)) {
                ByteBuffer y = image.getPlanes()[0].getBuffer();
                ByteBuffer uv = image.getPlanes()[1].getBuffer();
                y.position(0); uv.position(0);
                
                byte[] yBytes = new byte[y.remaining()];
                y.get(yBytes);
                out.write(yBytes);
                
                byte[] uvBytes = new byte[uv.remaining()];
                uv.get(uvBytes);
                out.write(uvBytes);
            }
            
            emitState("p010_dump_complete", "Dumped successfully to Downloads: " + filename);
        } catch (Exception e) {
            emitError("DUMP_FAILED", "Failed to dump raw P010 frame", e);
        }
    }'''

content = content.replace(old_dump, new_dump)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
