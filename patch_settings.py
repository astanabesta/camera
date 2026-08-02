import re

with open('lib/src/screens/settings_screen.dart', 'r') as f:
    content = f.read()

bitdepth_row = '''  _ChoiceRow<RecordBitDepth>(
    title: 'Color Depth',
    value: c.recordBitDepth,
    values: RecordBitDepth.values,
    label: (RecordBitDepth value) => value.label,
    onChanged: c.setRecordBitDepth,
  ),'''

if 'Color Depth' not in content:
    content = content.replace("  const _ValueRow(title: 'Color Space', value: 'Rec.709'),", bitdepth_row + "\n  const _ValueRow(title: 'Color Space', value: 'Rec.709'),")

with open('lib/src/screens/settings_screen.dart', 'w') as f:
    f.write(content)
