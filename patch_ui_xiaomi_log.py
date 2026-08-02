import re

with open('lib/src/screens/settings_screen.dart', 'r') as f:
    content = f.read()

content = content.replace("ButtonSegment<bool>(value: true, label: Text('Zircon Log')),", "ButtonSegment<bool>(value: true, label: Text('Xiaomi Log')),")

with open('lib/src/screens/settings_screen.dart', 'w') as f:
    f.write(content)
