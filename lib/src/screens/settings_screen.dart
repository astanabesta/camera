import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../model/camera_ui_controller.dart';
import '../widgets/side_rail.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.controller, super.key});
  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Row(
        children: <Widget>[
          Expanded(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return constraints.maxHeight > constraints.maxWidth
                      ? _PortraitSettings(controller: controller)
                      : _LandscapeSettings(controller: controller);
                },
              ),
            ),
          ),
          SideRail(controller: controller),
        ],
      ),
    );
  }
}

const List<(SettingsPage, String)> _pages = <(SettingsPage, String)>[
  (SettingsPage.record, 'Record'),
  (SettingsPage.camera, 'Camera'),
  (SettingsPage.processing, 'Processing'),
  (SettingsPage.audio, 'Audio'),
  (SettingsPage.monitor, 'Monitor'),
  (SettingsPage.liveStream, 'Live Stream'),
  (SettingsPage.media, 'Media'),
  (SettingsPage.functionButtons, 'Function Buttons'),
  (SettingsPage.luts, 'LUTs'),
];

String _title(SettingsPage page) =>
    _pages.firstWhere(((SettingsPage, String) item) => item.$1 == page).$2;

class _LandscapeSettings extends StatelessWidget {
  const _LandscapeSettings({required this.controller});
  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(width: 300, child: _Categories(controller: controller)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 14),
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 48,
                  child: Center(
                    child: Text(
                      _title(controller.settingsPage),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Expanded(child: _PageBody(controller: controller)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PortraitSettings extends StatelessWidget {
  const _PortraitSettings({required this.controller});
  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          height: 58,
          color: const Color(0xFF1C1D1F),
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            scrollDirection: Axis.horizontal,
            itemCount: _pages.length,
            separatorBuilder: (_, __) => const SizedBox(width: 5),
            itemBuilder: (BuildContext context, int index) {
              final (SettingsPage page, String label) = _pages[index];
              final bool selected = controller.settingsPage == page;
              return Material(
                color: selected
                    ? ZirconColors.settingsBlue
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                child: InkWell(
                  onTap: () => controller.setSettingsPage(page),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: Text(label, style: const TextStyle(fontSize: 11)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(
          height: 48,
          child: Center(
            child: Text(
              _title(controller.settingsPage),
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: _PageBody(controller: controller),
          ),
        ),
      ],
    );
  }
}

class _Categories extends StatelessWidget {
  const _Categories({required this.controller});
  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1C1D1F),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: Text(
              'Settings',
              style: TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w600,
                letterSpacing: -.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _pages.length,
              itemBuilder: (BuildContext context, int index) {
                final (SettingsPage page, String label) = _pages[index];
                final bool selected = controller.settingsPage == page;
                return Material(
                  color: selected
                      ? ZirconColors.settingsBlue
                      : Colors.transparent,
                  child: InkWell(
                    onTap: () => controller.setSettingsPage(page),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      alignment: Alignment.centerLeft,
                      decoration: selected
                          ? null
                          : const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Color(0xFF37383B)),
                              ),
                            ),
                      child: Text(label, style: const TextStyle(fontSize: 17)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PageBody extends StatelessWidget {
  const _PageBody({required this.controller});
  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = switch (controller.settingsPage) {
      SettingsPage.record => _recordRows(controller),
      SettingsPage.camera => _cameraRows(controller),
      SettingsPage.processing => _processingRows(controller),
      SettingsPage.audio => _audioRows(controller),
      SettingsPage.monitor => _monitorRows(controller),
      SettingsPage.liveStream => _liveRows,
      SettingsPage.media => _mediaRows(controller),
      SettingsPage.functionButtons => _functionRows,
      SettingsPage.luts => _lutRows,
    };
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF202123),
        borderRadius: BorderRadius.circular(13),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: rows.length,
        separatorBuilder: (_, __) => const Divider(
          height: 1,
          indent: 18,
          endIndent: 18,
          color: Color(0xFF3A3B3E),
        ),
        itemBuilder: (_, int index) => rows[index],
      ),
    );
  }
}

List<Widget> _recordRows(CameraUiController c) => <Widget>[
  const _ValueRow(title: 'Codec', value: 'HEVC (H.265)'),
  _ChoiceRow<RecordingMode>(
    title: 'Resolution',
    value: c.recordingMode,
    values: RecordingMode.values,
    label: (RecordingMode value) => value.label,
    onChanged: c.setRecordingMode,
  ),
  _ValueRow(
    title: 'Frame Rate',
    value: '${c.recordingMode.fps} fps',
    chevron: false,
  ),
  _ChoiceRow<BitratePreset>(
    title: 'Bitrate Request',
    value: c.bitratePreset,
    values: BitratePreset.values,
    label: (BitratePreset value) => '${value.label} ${value.display}',
    onChanged: c.setBitratePreset,
  ),
  const _ValueRow(title: 'Color Space', value: 'Rec.709'),
  const _ValueRow(title: 'Timecode Display', value: 'Record Run'),
  const _NoticeRow(
    text:
        'Public direct modes: UHD30, FHD30 and 4:3 1440p30. 1080p60 and 4080×3060 encoded open-gate are not advertised by the public direct Camera2/encoder path.',
  ),
];

List<Widget> _cameraRows(CameraUiController c) => <Widget>[
  _CustomRow(
    title: 'Screen Orientation',
    trailing: _OrientationChoice(controller: c),
  ),
  _ValueRow(
    title: 'Exposure Mode',
    value: switch (c.operationMode) {
      CameraOperationMode.auto => 'Auto',
      CameraOperationMode.manual => 'Manual',
      CameraOperationMode.mixed => 'Mixed',
    },
  ),
  const _SwitchRow(title: 'Tap to Focus', value: true),
  const _SwitchRow(title: 'Tap Exposure Metering', value: true),
  _ChoiceRow<StabilizationMode>(
    title: 'Stabilization',
    value: c.stabilizationMode,
    values: StabilizationMode.values,
    label: (StabilizationMode value) => value.label,
    onChanged: c.setStabilizationMode,
  ),
  _ValueRow(
    title: 'Stabilization Result',
    value: c.actualStabilizationLabel,
    chevron: false,
  ),
  _ChoiceRow<ZoomSpeed>(
    title: 'Zoom Speed',
    value: c.zoomSpeed,
    values: ZoomSpeed.values,
    label: (ZoomSpeed value) => value.settingsLabel,
    onChanged: c.setZoomSpeed,
  ),
  _ValueRow(
    title: 'Zoom Speed Use',
    value: switch (c.zoomSpeed) {
      ZoomSpeed.slow => 'Cinematic push-ins',
      ZoomSpeed.medium => 'General shooting',
      ZoomSpeed.fast => 'Quick smooth framing',
    },
    chevron: false,
  ),
  const _ValueRow(title: 'Main Camera', value: '6.14 mm  f/1.65'),
];

List<Widget> _processingRows(CameraUiController c) => <Widget>[
  _ChoiceRow<SharpnessMode>(
    title: 'Sharpness',
    value: c.sharpnessMode,
    values: SharpnessMode.values,
    label: (SharpnessMode value) => value.label,
    onChanged: c.setSharpnessMode,
  ),
  _ValueRow(
    title: 'Sharpness Result',
    value: c.actualSharpnessLabel,
    chevron: false,
  ),
  _ChoiceRow<NoiseReductionMode>(
    title: 'Noise Reduction',
    value: c.noiseReductionMode,
    values: NoiseReductionMode.values,
    label: (NoiseReductionMode value) => value.label,
    onChanged: c.setNoiseReductionMode,
  ),
  _ValueRow(
    title: 'Noise Reduction Result',
    value: c.actualNoiseReductionLabel,
    chevron: false,
  ),
  const _NoticeRow(
    text:
        'Requested values are only confirmed when the Camera2 capture result matches.',
  ),
];

List<Widget> _audioRows(CameraUiController c) => <Widget>[
  const _ValueRow(title: 'Audio Source', value: 'Default'),
  const _ValueRow(title: 'Phone Microphone', value: 'Auto'),
  const _ValueRow(title: 'Audio Format', value: 'AAC'),
  const _ValueRow(title: 'Record Audio as', value: 'Stereo'),
  const _ValueRow(title: 'Sample Rate', value: '48 kHz'),
  _ValueRow(
    title: 'Audio Metering',
    value: c.audioLevelDbfs == null
        ? 'VU (-18 dBFS)'
        : '${c.audioLevelDbfs!.toStringAsFixed(1)} dBFS',
    chevron: false,
  ),
  const _SwitchRow(title: 'Audio Monitor', value: false, enabled: false),
  const _ValueRow(title: 'Audio Output', value: 'Default', enabled: false),
];

List<Widget> _monitorRows(CameraUiController c) => <Widget>[
  _SwitchRow(
    title: 'Frame Guides',
    value: c.isToolEnabled(MonitorTool.frameGuides),
    onChanged: (_) => c.toggleMonitorTool(MonitorTool.frameGuides),
  ),
  _SwitchRow(
    title: 'Grid',
    value: c.isToolEnabled(MonitorTool.grid),
    onChanged: (_) => c.toggleMonitorTool(MonitorTool.grid),
  ),
  _SwitchRow(
    title: 'Zebra',
    value: c.isToolEnabled(MonitorTool.zebra),
    onChanged: (_) => c.toggleMonitorTool(MonitorTool.zebra),
  ),
  _SwitchRow(
    title: 'False Color',
    value: c.isToolEnabled(MonitorTool.falseColor),
    onChanged: (_) => c.toggleMonitorTool(MonitorTool.falseColor),
  ),
  _SwitchRow(
    title: 'Focus Peaking',
    value: c.isToolEnabled(MonitorTool.peaking),
    onChanged: (_) => c.toggleMonitorTool(MonitorTool.peaking),
  ),
  const _SwitchRow(title: 'Horizon Level', value: true),
  _ValueRow(
    title: 'Measured Roll',
    value: c.levelRollDegrees == null
        ? 'Waiting for sensor'
        : '${c.levelRollDegrees!.toStringAsFixed(1)}°',
    chevron: false,
  ),
];

const List<Widget> _liveRows = <Widget>[
  _ValueRow(
    title: 'Streaming Service',
    value: 'Not Configured',
    enabled: false,
  ),
  _SwitchRow(title: 'Start Live Stream', value: false, enabled: false),
  _ValueRow(title: 'Server URL', value: 'Required', enabled: false),
  _ValueRow(title: 'Stream Key', value: 'Required', enabled: false),
];

List<Widget> _mediaRows(CameraUiController c) => <Widget>[
  const _SwitchRow(title: 'Record Proxy', value: false, enabled: false),
  const _ValueRow(title: 'Upload Clips', value: 'No Server', enabled: false),
  const _ValueRow(
    title: 'Proxy Clip Manager',
    value: 'Unavailable',
    enabled: false,
  ),
  const _SwitchRow(title: 'Live Sync', value: false, enabled: false),
  const _SwitchRow(
    title: 'Auto Upload to Selected Project',
    value: false,
    enabled: false,
  ),
  const _SwitchRow(
    title: 'Enable Upload Only Over Wi-Fi',
    value: true,
    enabled: false,
  ),
  const _ValueRow(title: 'Save Clips to', value: 'Gallery'),
  _ValueRow(
    title: 'Storage Available',
    value: c.storageAvailableLabel,
    chevron: false,
  ),
  const _SwitchRow(
    title: 'Save Location Data to Clip',
    value: false,
    enabled: false,
  ),
  const _ValueRow(title: 'Filename Convention', value: 'ZC_A001_C###'),
];

const List<Widget> _functionRows = <Widget>[
  _ValueRow(title: 'Top Tool 1', value: 'Focus'),
  _ValueRow(title: 'Top Tool 2', value: 'Exposure'),
  _ValueRow(title: 'Side Tool 1', value: 'Orientation'),
  _ValueRow(title: 'Side Tool 2', value: 'Monitor Tools'),
  _ValueRow(title: 'Long Press Preview', value: 'AE/AF Lock'),
  _ValueRow(title: 'Volume Up', value: 'Tap step / Hold zoom in'),
  _ValueRow(title: 'Volume Down', value: 'Tap step / Hold zoom out'),
];

const List<Widget> _lutRows = <Widget>[
  _ValueRow(title: 'Display LUT', value: 'Rec.709 Pass-through'),
  _SwitchRow(title: 'Apply LUT to Display', value: false, enabled: false),
  _SwitchRow(title: 'Record LUT to Clip', value: false, enabled: false),
  _ValueRow(
    title: 'Import 3D LUT',
    value: 'GPU Pipeline Required',
    enabled: false,
  ),
  _ValueRow(
    title: 'Internal LOG Preview',
    value: 'Not Validated',
    enabled: false,
  ),
];

class _RowShell extends StatelessWidget {
  const _RowShell({required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: enabled ? 1 : .36,
    child: SizedBox(
      height: 54,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: child,
      ),
    ),
  );
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.title,
    required this.value,
    this.enabled = true,
    this.chevron = true,
  });
  final String title;
  final String value;
  final bool enabled;
  final bool chevron;
  @override
  Widget build(BuildContext context) => _RowShell(
    enabled: enabled,
    child: Row(
      children: <Widget>[
        Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Color(0xFF99999E), fontSize: 15),
          ),
        ),
        if (chevron)
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF707176)),
      ],
    ),
  );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    this.enabled = true,
    this.onChanged,
  });
  final String title;
  final bool value;
  final bool enabled;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => _RowShell(
    enabled: enabled,
    child: Row(
      children: <Widget>[
        Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
        Transform.scale(
          scale: .86,
          child: Switch.adaptive(
            value: value,
            onChanged: enabled ? (onChanged ?? (_) {}) : null,
            activeThumbColor: Colors.white,
            activeTrackColor: ZirconColors.settingsBlue,
          ),
        ),
      ],
    ),
  );
}

class _CustomRow extends StatelessWidget {
  const _CustomRow({required this.title, required this.trailing});
  final String title;
  final Widget trailing;
  @override
  Widget build(BuildContext context) => _RowShell(
    child: Row(
      children: <Widget>[
        Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
        trailing,
      ],
    ),
  );
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.title,
    required this.value,
    required this.values,
    required this.label,
    required this.onChanged,
  });
  final String title;
  final T value;
  final List<T> values;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 9),
        SegmentedButton<T>(
          showSelectedIcon: false,
          segments: values
              .map(
                (T item) =>
                    ButtonSegment<T>(value: item, label: Text(label(item))),
              )
              .toList(growable: false),
          selected: <T>{value},
          onSelectionChanged: (Set<T> selected) => onChanged(selected.first),
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStatePropertyAll<TextStyle>(
              TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    ),
  );
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(18),
    child: Text(
      text,
      style: const TextStyle(color: ZirconColors.warning, fontSize: 11),
    ),
  );
}

class _OrientationChoice extends StatelessWidget {
  const _OrientationChoice({required this.controller});
  final CameraUiController controller;
  @override
  Widget build(BuildContext context) {
    final bool portrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    Widget button(IconData icon, bool selected, CaptureOrientation value) =>
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => controller.setCaptureOrientation(value),
          icon: Icon(
            icon,
            color: selected
                ? ZirconColors.settingsBlue
                : const Color(0xFF8E8F94),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        button(
          Icons.stay_current_portrait_rounded,
          portrait,
          CaptureOrientation.portrait,
        ),
        button(
          Icons.stay_current_landscape_rounded,
          !portrait,
          CaptureOrientation.landscape,
        ),
      ],
    );
  }
}
