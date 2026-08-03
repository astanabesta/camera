import re

with open('android/app/src/main/AndroidManifest.xml', 'r') as f:
    content = f.read()

# To write directly to Environment.DIRECTORY_DOWNLOADS via standard java.io.FileOutputStream 
# on modern Android versions (without MediaStore), we need specific permissions in the manifest,
# or we just write it to MediaStore directly or the app's external files dir.
# A much safer and guaranteed way on Android 13+ is writing to Context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
# OR we update dumpRawP010ToDisk to use the app's private external directory which requires no permissions.

