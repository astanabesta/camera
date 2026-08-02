import re

with open('lib/src/model/camera_ui_controller.dart', 'r') as f:
    content = f.read()

old_enum = '''enum FilmStyle {
  standard('Standard'),
  cinematic('Cinematic'),
  fuji('Fuji'),
  vivid('Vivid');'''

new_enum = '''enum FilmStyle {
  standard('Standard'),
  cinematic('Cinematic'),
  fuji('Fuji'),
  vivid('Vivid'),
  slog3('S-Log3');'''
  
content = content.replace(old_enum, new_enum)

old_switch = '''  String get camera2Value {
    switch (this) {
      case FilmStyle.standard: return 'Standard';
      case FilmStyle.cinematic: return 'Cinematic';
      case FilmStyle.fuji: return 'Fuji';
      case FilmStyle.vivid: return 'Vivid';
    }
  }'''

new_switch = '''  String get camera2Value {
    switch (this) {
      case FilmStyle.standard: return 'Standard';
      case FilmStyle.cinematic: return 'Cinematic';
      case FilmStyle.fuji: return 'Fuji';
      case FilmStyle.vivid: return 'Vivid';
      case FilmStyle.slog3: return 'S-Log3';
    }
  }'''

content = content.replace(old_switch, new_switch)

with open('lib/src/model/camera_ui_controller.dart', 'w') as f:
    f.write(content)
