import re

with open('lib/src/model/camera_ui_controller.dart', 'r') as f:
    content = f.read()

# Add Properties
if 'double _shadowLift = 0.0;' not in content:
    content = content.replace('FilmStyle _filmStyle = FilmStyle.standard;', 'FilmStyle _filmStyle = FilmStyle.standard;\n  double _shadowLift = 0.0;\n  double _highlightRollOff = 0.0;')

# Add Getters
if 'double get shadowLift' not in content:
    content = content.replace('FilmStyle get filmStyle => _filmStyle;', 'FilmStyle get filmStyle => _filmStyle;\n  double get shadowLift => _shadowLift;\n  double get highlightRollOff => _highlightRollOff;')

# Add Setters
setters = '''
  void setShadowLift(double value) {
    if (_recording || _shadowLift == value) return;
    _shadowLift = value;
    notifyListeners();
    _scheduleNativeControlApply();
  }

  void setHighlightRollOff(double value) {
    if (_recording || _highlightRollOff == value) return;
    _highlightRollOff = value;
    notifyListeners();
    _scheduleNativeControlApply();
  }
'''
if 'void setShadowLift' not in content:
    content = content.replace('void setFilmStyle', setters + '\n  void setFilmStyle')

# JSON Map
if "'shadowLift': _shadowLift," not in content:
    content = content.replace("'filmStyle': _filmStyle.camera2Value,", "'filmStyle': _filmStyle.camera2Value,\n        'shadowLift': _shadowLift,\n        'highlightRollOff': _highlightRollOff,")

with open('lib/src/model/camera_ui_controller.dart', 'w') as f:
    f.write(content)
