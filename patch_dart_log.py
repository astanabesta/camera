import re

with open('lib/src/model/camera_ui_controller.dart', 'r') as f:
    content = f.read()

# Add Property
if 'bool _logProfile = false;' not in content:
    content = content.replace('RecordBitDepth _recordBitDepth = RecordBitDepth.tenBit;', 'RecordBitDepth _recordBitDepth = RecordBitDepth.tenBit;\n  bool _logProfile = false;')

# Add Getter
if 'bool get logProfile' not in content:
    content = content.replace('RecordBitDepth get recordBitDepth => _recordBitDepth;', 'RecordBitDepth get recordBitDepth => _recordBitDepth;\n  bool get logProfile => _logProfile;')

# Add Setter
setter_str = '''
  void setLogProfile(bool value) {
    if (_recording || _logProfile == value) return;
    _logProfile = value;
    notifyListeners();
    _applyControls();
  }
'''
if 'void setLogProfile' not in content:
    content = content.replace('void setRecordBitDepth', setter_str + '\n  void setRecordBitDepth')

# Apply it in JSON map
if "'logProfile': _logProfile," not in content:
    content = content.replace("'recordBitDepth': _recordBitDepth.depth,", "'recordBitDepth': _recordBitDepth.depth,\n        'logProfile': _logProfile,")

# Save config string (persistence map)
if "'logProfile': _logProfile," not in content.replace("'recordBitDepth': _recordBitDepth.depth,", ""):
    content = content.replace("'recordBitDepth': _recordBitDepth.index,", "'recordBitDepth': _recordBitDepth.index,\n        'logProfile': _logProfile,")

# Load config string (persistence map)
if "_logProfile = values['logProfile']" not in content:
    content = content.replace("_recordBitDepth = RecordBitDepth.values[values['recordBitDepth'] as int? ?? _recordBitDepth.index];", "_recordBitDepth = RecordBitDepth.values[values['recordBitDepth'] as int? ?? _recordBitDepth.index];\n      _logProfile = values['logProfile'] as bool? ?? false;")

with open('lib/src/model/camera_ui_controller.dart', 'w') as f:
    f.write(content)
