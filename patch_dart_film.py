import re

with open('lib/src/model/camera_ui_controller.dart', 'r') as f:
    content = f.read()

enum_code = '''
enum FilmStyle {
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
}
'''
if 'enum FilmStyle' not in content:
    content = content.replace('enum RecordBitDepth {', enum_code + '\n\nenum RecordBitDepth {')

if 'FilmStyle _filmStyle =' not in content:
    content = content.replace('bool _logProfile = false;', 'bool _logProfile = false;\n  FilmStyle _filmStyle = FilmStyle.standard;')

if 'FilmStyle get filmStyle' not in content:
    content = content.replace('bool get logProfile => _logProfile;', 'bool get logProfile => _logProfile;\n  FilmStyle get filmStyle => _filmStyle;')

setter = '''
  void setFilmStyle(FilmStyle value) {
    if (_recording || _filmStyle == value) return;
    _filmStyle = value;
    notifyListeners();
    _scheduleNativeControlApply();
  }
'''
if 'void setFilmStyle' not in content:
    content = content.replace('void setLogProfile', setter + '\n  void setLogProfile')

if "'filmStyle': _filmStyle.camera2Value," not in content:
    content = content.replace("'logProfile': _logProfile,", "'logProfile': _logProfile,\n        'filmStyle': _filmStyle.camera2Value,")

if "'filmStyle': _filmStyle.index," not in content:
    content = content.replace("'logProfile': _logProfile,", "'logProfile': _logProfile,\n        'filmStyle': _filmStyle.index,", 1)

if "_filmStyle = FilmStyle.values" not in content:
    content = content.replace("_logProfile = values['logProfile'] as bool? ?? false;", "_logProfile = values['logProfile'] as bool? ?? false;\n      _filmStyle = FilmStyle.values[values['filmStyle'] as int? ?? _filmStyle.index];")


with open('lib/src/model/camera_ui_controller.dart', 'w') as f:
    f.write(content)

