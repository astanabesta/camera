import re

with open('lib/src/screens/settings_screen.dart', 'r') as f:
    content = f.read()

log_row = '''  _CustomRow(
    title: 'Tone Curve',
    trailing: SegmentedButton<bool>(
      showSelectedIcon: false,
      segments: const <ButtonSegment<bool>>[
        ButtonSegment<bool>(value: false, label: Text('Rec.709')),
        ButtonSegment<bool>(value: true, label: Text('Zircon Log')),
      ],
      selected: <bool>{c.logProfile},
      onSelectionChanged: (Set<bool> newSelection) {
        c.setLogProfile(newSelection.first);
      },
    ),
  ),'''

if 'Tone Curve' not in content:
    content = content.replace("  const _ValueRow(title: 'Color Space', value: 'Rec.709'),", log_row + "\n  const _ValueRow(title: 'Color Space', value: 'Rec.709'),")

with open('lib/src/screens/settings_screen.dart', 'w') as f:
    f.write(content)
