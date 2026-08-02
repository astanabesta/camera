import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# Fix the deprecated onSurfaceDestroyed removal warning
if 'public void onSurfaceDestroyed() {' in content:
    content = content.replace('public void onSurfaceDestroyed() {', 'public void onSurfaceDestroyed() {')
    # Actually, if it's just a deprecation warning, it shouldn't cause a failure on its own.
    # The failure was purely the missing methods. Let's fix it anyway.
    
    old_surface = '''        textureProducer.setCallback(new TextureRegistry.SurfaceProducer.Callback() {
            @Override
            public void onSurfaceAvailable() {
                previewSurface = null;
                if (initialized && !disposed.get()) resume();
            }

            @Override
            public void onSurfaceDestroyed() {
                Handler handler = cameraHandler;
                if (handler != null) {
                    handler.post(() -> {
                        closeCameraOnly();
                        previewSurface = null;
                    });
                } else {
                    previewSurface = null;
                }
            }
        });'''
        
    new_surface = '''        textureProducer.setCallback(new TextureRegistry.SurfaceProducer.Callback() {
            @Override
            public void onSurfaceAvailable() {
                previewSurface = null;
                if (initialized && !disposed.get()) resume();
            }

            @Override
            public void onSurfaceCleanup() {
                Handler handler = cameraHandler;
                if (handler != null) {
                    handler.post(() -> {
                        closeCameraOnly();
                        previewSurface = null;
                    });
                } else {
                    previewSurface = null;
                }
            }
        });'''
    content = content.replace(old_surface, new_surface)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
