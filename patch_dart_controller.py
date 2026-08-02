import re

with open('lib/src/model/camera_ui_controller.dart', 'r') as f:
    content = f.read()

# Add Enum
enum_str = '''
enum RecordBitDepth {
  eightBit('8-bit SDR', 8),
  tenBit('10-bit SDR', 10);

  const RecordBitDepth(this.label, this.depth);
  final String label;
  final int depth;
}
'''
if 'enum RecordBitDepth' not in content:
    content = content.replace('enum BitratePreset {', enum_str + '\nenum BitratePreset {')

# Add Property
if 'RecordBitDepth _recordBitDepth' not in content:
    content = content.replace('RecordingMode _recordingMode = RecordingMode.uhd30;', 'RecordingMode _recordingMode = RecordingMode.uhd30;\n  RecordBitDepth _recordBitDepth = RecordBitDepth.tenBit;')

# Add Getter
if 'RecordBitDepth get recordBitDepth' not in content:
    content = content.replace('RecordingMode get recordingMode => _recordingMode;', 'RecordingMode get recordingMode => _recordingMode;\n  RecordBitDepth get recordBitDepth => _recordBitDepth;')

# Add Setter
setter_str = '''
  void setRecordBitDepth(RecordBitDepth value) {
    if (_recording || _recordBitDepth == value) return;
    _recordBitDepth = value;
    notifyListeners();
    _applyControls();
  }
'''
if 'void setRecordBitDepth' not in content:
    content = content.replace('void setBitratePreset(BitratePreset value) {', setter_str + '\n  void setBitratePreset(BitratePreset value) {')

# Apply it in JSON map
if "'recordBitDepth': _recordBitDepth.depth," not in content:
    content = content.replace("'recordFps': _recordingMode.fps,", "'recordFps': _recordingMode.fps,\n        'recordBitDepth': _recordBitDepth.depth,")

# Save config string (persistence map)
if "'recordBitDepth': _recordBitDepth.index," not in content:
    content = content.replace("'recordingMode': _recordingMode.index,", "'recordingMode': _recordingMode.index,\n        'recordBitDepth': _recordBitDepth.index,")

# Load config string (persistence map)
if "_recordBitDepth = RecordBitDepth.values[" not in content:
    content = content.replace("_recordingMode = RecordingMode.values[values['recordingMode'] as int? ?? _recordingMode.index];", "_recordingMode = RecordingMode.values[values['recordingMode'] as int? ?? _recordingMode.index];\n      _recordBitDepth = RecordBitDepth.values[values['recordBitDepth'] as int? ?? _recordBitDepth.index];")


with open('lib/src/model/camera_ui_controller.dart', 'w') as f:
    f.write(content)
