import re

# Expose to MainActivity
with open('android/app/src/main/java/ai/arena/zirconcinema/ui/MainActivity.java', 'r') as f:
    main_content = f.read()

if 'dumpP010Frame' not in main_content:
    main_content = main_content.replace('case "startRecording" -> cameraEngine.startRecording(result);', 'case "dumpP010Frame" -> cameraEngine.dumpP010Frame(result);\n            case "startRecording" -> cameraEngine.startRecording(result);')

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/MainActivity.java', 'w') as f:
    f.write(main_content)

# Expose to Dart Native Engine
with open('lib/src/camera/native_camera_engine.dart', 'r') as f:
    engine_content = f.read()

if 'dumpP010Frame' not in engine_content:
    dart_method = '''  Future<Map<Object?, Object?>> dumpP010Frame() {
    return _invokeMap('dumpP010Frame', null);
  }
'''
    engine_content = engine_content.replace('Future<Map<Object?, Object?>> startRecording() {', dart_method + '\n  Future<Map<Object?, Object?>> startRecording() {')

with open('lib/src/camera/native_camera_engine.dart', 'w') as f:
    f.write(engine_content)
