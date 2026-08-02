import re

with open('lib/src/screens/settings_screen.dart', 'r') as f:
    content = f.read()

# Update the Tone Curve segmented button
old_button = '''  _CustomRow(
    title: 'Tone Curve',
    trailing: SegmentedButton<bool>(
      showSelectedIcon: false,
      segments: const <ButtonSegment<bool>>[
        ButtonSegment<bool>(value: false, label: Text('Rec.709')),
        ButtonSegment<bool>(value: true, label: Text('Xiaomi Log')),
      ],
      selected: <bool>{c.logProfile},
      onSelectionChanged: (Set<bool> newSelection) {
        c.setLogProfile(newSelection.first);
      },
    ),
  ),'''

new_button = '''  _ChoiceRow<LogCurve>(
    title: 'Tone Curve',
    value: c.logCurve,
    values: LogCurve.values,
    label: (LogCurve value) => value.label,
    onChanged: c.setLogCurve,
  ),'''

content = content.replace(old_button, new_button)

with open('lib/src/screens/settings_screen.dart', 'w') as f:
    f.write(content)

