import re

# Dart Controller
dart_file = 'lib/src/model/camera_ui_controller.dart'
with open(dart_file, 'r') as f:
    content = f.read()

old_enum = '''enum LogCurve {
  rec709('Rec.709'),
  xiaomi('Xiaomi'),
  slog3('S-Log3');

  const LogCurve(this.label);
  final String label;

  String get camera2Value {
    switch (this) {
      case LogCurve.rec709: return 'Rec709';
      case LogCurve.xiaomi: return 'Xiaomi';
      case LogCurve.slog3: return 'S-Log3';
    }
  }
}'''

new_enum = '''enum LogCurve {
  rec709('Rec.709'),
  zircon('Zircon Log');

  const LogCurve(this.label);
  final String label;

  String get camera2Value {
    switch (this) {
      case LogCurve.rec709: return 'Rec709';
      case LogCurve.zircon: return 'Zircon';
    }
  }
}'''

content = content.replace(old_enum, new_enum)

with open(dart_file, 'w') as f:
    f.write(content)


# Settings UI
ui_file = 'lib/src/screens/settings_screen.dart'
with open(ui_file, 'r') as f:
    ui = f.read()
    
# Not needed if ChoiceRow uses LogCurve.values directly, which it does!

