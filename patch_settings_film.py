import re

with open('lib/src/screens/settings_screen.dart', 'r') as f:
    content = f.read()

film_row = '''  _ChoiceRow<FilmStyle>(
    title: 'Color Profile',
    value: c.filmStyle,
    values: FilmStyle.values,
    label: (FilmStyle value) => value.label,
    onChanged: c.setFilmStyle,
  ),'''

if 'Color Profile' not in content:
    content = content.replace("  _CustomRow(\n    title: 'Tone Curve',", film_row + "\n  _CustomRow(\n    title: 'Tone Curve',")

with open('lib/src/screens/settings_screen.dart', 'w') as f:
    f.write(content)

