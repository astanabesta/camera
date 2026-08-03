import re

with open('lib/src/model/camera_ui_controller.dart', 'r') as f:
    content = f.read()

# Add logic to handle the dump result
diag_logic = '''
  bool _diagBusy = false;
  bool get diagBusy => _diagBusy;

  Future<void> dumpP010Frame() async {
    if (_diagBusy || !cameraReady) return;
    _diagBusy = true;
    notifyListeners();
    try {
      await _nativeCamera.dumpP010Frame();
    } catch (e) {
      _cameraError = _friendlyPlatformError(e);
    } finally {
      _diagBusy = false;
      notifyListeners();
    }
  }
'''
if 'dumpP010Frame' not in content:
    content = content.replace('Future<void> runTenBitRec709Preflight() async {', diag_logic + '\n  Future<void> runTenBitRec709Preflight() async {')

with open('lib/src/model/camera_ui_controller.dart', 'w') as f:
    f.write(content)

with open('lib/src/screens/settings_screen.dart', 'r') as f:
    ui = f.read()

diag_row = '''  _CustomRow(
    title: 'Developer Diagnostics',
    trailing: FilledButton(
      onPressed: c.diagBusy ? null : c.dumpP010Frame,
      child: Text(c.diagBusy ? 'DUMPING' : 'DUMP RAW P010'),
    ),
  ),'''

if 'Developer Diagnostics' not in ui:
    ui = ui.replace("  const _ValueRow(title: 'Advanced', value: ''),", "  const _ValueRow(title: 'Advanced', value: ''),\n" + diag_row)

with open('lib/src/screens/settings_screen.dart', 'w') as f:
    f.write(ui)
