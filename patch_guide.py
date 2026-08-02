import re

# 1. Update camera_ui_controller.dart
with open('lib/src/model/camera_ui_controller.dart', 'r') as f:
    content = f.read()

old_enum = '''enum GuideRatio {
  ratio239('2.39:1', 2.39),
  ratio185('1.85:1', 1.85),
  ratio169('16:9', 16 / 9),
  ratio43('4:3', 4 / 3);'''

new_enum = '''enum GuideRatio {
  ratio169('16:9', 16 / 9),
  ratio239('2.39:1', 2.39),
  ratio43('4:3', 4 / 3),
  ratio11('1:1', 1.0),
  ratio45('4:5', 4 / 5),
  ratio916('9:16', 9 / 16);'''

content = content.replace(old_enum, new_enum)

# Default it to 16:9 instead of 2.39:1
content = content.replace('GuideRatio _guideRatio = GuideRatio.ratio239;', 'GuideRatio _guideRatio = GuideRatio.ratio169;')

with open('lib/src/model/camera_ui_controller.dart', 'w') as f:
    f.write(content)


# 2. Update preview_overlays.dart
with open('lib/src/widgets/preview_overlays.dart', 'r') as f:
    content2 = f.read()

old_draw = '''  void _drawFrameGuides(Canvas canvas, Size size) {
    final double guideHeight = size.width / guideRatio;
    if (guideHeight >= size.height) return;
    final double top = (size.height - guideHeight) / 2;
    final Paint shade = Paint()..color = Colors.black.withValues(alpha: .22);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, top), shade);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - top, size.width, top),
      shade,
    );
    final Paint line = Paint()
      ..color = ZirconColors.text.withValues(alpha: .6)
      ..strokeWidth = .8
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromLTWH(0, top, size.width, guideHeight), line);
  }'''

new_draw = '''  void _drawFrameGuides(Canvas canvas, Size size) {
    // We adjust guide ratio dynamically if the screen is in portrait
    // so that "16:9" acts as the natural screen shape. 
    // Wait, the user specifically wants 9:16, 4:5 etc. 
    // We will just strictly apply the requested aspect ratio.
    
    final double screenRatio = size.width / size.height;
    double guideW = size.width;
    double guideH = size.height;
    
    // Allow a small epsilon for floating point inaccuracies
    if (guideRatio > screenRatio + 0.01) {
      // Guide is wider than screen -> Letterbox (top & bottom bars)
      guideH = size.width / guideRatio;
    } else if (guideRatio < screenRatio - 0.01) {
      // Guide is taller than screen -> Pillarbox (left & right bars)
      guideW = size.height * guideRatio;
    } else {
      return; // Exact match, no bars needed
    }
    
    final Paint shade = Paint()..color = Colors.black.withValues(alpha: .65);
    
    if (guideRatio > screenRatio + 0.01) {
      final double top = (size.height - guideH) / 2;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, top), shade);
      canvas.drawRect(Rect.fromLTWH(0, size.height - top, size.width, top), shade);
    } else {
      final double left = (size.width - guideW) / 2;
      canvas.drawRect(Rect.fromLTWH(0, 0, left, size.height), shade);
      canvas.drawRect(Rect.fromLTWH(size.width - left, 0, left, size.height), shade);
    }
    
    final Paint line = Paint()
      ..color = ZirconColors.text.withValues(alpha: .6)
      ..strokeWidth = .8
      ..style = PaintingStyle.stroke;
      
    final double left = (size.width - guideW) / 2;
    final double top = (size.height - guideH) / 2;
    canvas.drawRect(Rect.fromLTWH(left, top, guideW, guideH), line);
  }'''

content2 = content2.replace(old_draw, new_draw)

with open('lib/src/widgets/preview_overlays.dart', 'w') as f:
    f.write(content2)


# 3. Add to settings_screen.dart
with open('lib/src/screens/settings_screen.dart', 'r') as f:
    content3 = f.read()

guide_row = '''  _ChoiceRow<GuideRatio>(
    title: 'Frame Guides',
    value: c.guideRatio,
    values: GuideRatio.values,
    label: (GuideRatio value) => value.label,
    onChanged: c.setGuideRatio,
  ),'''

if 'Frame Guides' not in content3:
    content3 = content3.replace("  const _ValueRow(title: 'Advanced', value: ''),", guide_row + "\n  const _ValueRow(title: 'Advanced', value: ''),")

with open('lib/src/screens/settings_screen.dart', 'w') as f:
    f.write(content3)

