import re

with open('lib/src/model/camera_ui_controller.dart', 'r') as f:
    content = f.read()

# 1. New LogCurve Enum
log_enum = '''enum LogCurve {
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
}
'''
content = content.replace('enum FilmStyle {', log_enum + '\nenum FilmStyle {')

# 2. Fix FilmStyle (remove slog3)
old_film_enum = '''enum FilmStyle {
  standard('Standard'),
  cinematic('Cinematic'),
  fuji('Fuji'),
  vivid('Vivid'),
  slog3('S-Log3');

  const FilmStyle(this.label);
  final String label;
  
  String get camera2Value {
    switch (this) {
      case FilmStyle.standard: return 'Standard';
      case FilmStyle.cinematic: return 'Cinematic';
      case FilmStyle.fuji: return 'Fuji';
      case FilmStyle.vivid: return 'Vivid';
      case FilmStyle.slog3: return 'S-Log3';
    }
  }
}'''

new_film_enum = '''enum FilmStyle {
  standard('Standard'),
  cinematic('Cinematic'),
  fuji('Fuji'),
  vivid('Vivid');

  const FilmStyle(this.label);
  final String label;
  
  String get camera2Value {
    switch (this) {
      case FilmStyle.standard: return 'Standard';
      case FilmStyle.cinematic: return 'Cinematic';
      case FilmStyle.fuji: return 'Fuji';
      case FilmStyle.vivid: return 'Vivid';
    }
  }
}'''
content = content.replace(old_film_enum, new_film_enum)

# 3. Remove openGate from RecordingMode
old_rec_enum = '''enum RecordingMode {
  openGate('Open Gate (Full Sensor)', 4080, 3060, 30, 'OPEN GATE'),
  uhd30('4K', 3840, 2160, 30, 'UHD'),
  fhd30('1080p', 1920, 1080, 30, 'FHD'),
  fourThree30('4:3 1440p', 1920, 1440, 30, '4:3 1440p');'''
  
new_rec_enum = '''enum RecordingMode {
  uhd30('4K', 3840, 2160, 30, 'UHD'),
  fhd30('1080p', 1920, 1080, 30, 'FHD'),
  fourThree30('4:3 1440p', 1920, 1440, 30, '4:3 1440p');'''
content = content.replace(old_rec_enum, new_rec_enum)

# 4. Swap bool logProfile to LogCurve logCurve
content = content.replace('bool _logProfile = false;', 'LogCurve _logCurve = LogCurve.rec709;')
content = content.replace('bool get logProfile => _logProfile;', 'LogCurve get logCurve => _logCurve;')

# 5. Setter
old_setter = '''  void setLogProfile(bool value) {
    if (_recording || _logProfile == value) return;
    _logProfile = value;
    notifyListeners();
    _scheduleNativeControlApply();
  }'''
new_setter = '''  void setLogCurve(LogCurve value) {
    if (_recording || _logCurve == value) return;
    _logCurve = value;
    notifyListeners();
    _scheduleNativeControlApply();
  }'''
content = content.replace(old_setter, new_setter)

# 6. JSON Maps
content = content.replace("'logProfile': _logProfile,", "'logCurve': _logCurve.camera2Value,")
content = content.replace("'logProfile': _logProfile,", "'logCurve': _logCurve.index,", 1) # Sometimes multiple matches exist

# Let's just do a regex replace for the config load
content = re.sub(r"_logProfile = values\['logProfile'\].*?;", "_logCurve = LogCurve.values[values['logCurve'] as int? ?? _logCurve.index];", content)
content = re.sub(r"'logProfile': _logProfile,", "'logCurve': _logCurve.index,", content)

with open('lib/src/model/camera_ui_controller.dart', 'w') as f:
    f.write(content)
