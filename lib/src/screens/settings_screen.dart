import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../model/camera_ui_controller.dart';
import '../widgets/glass_panel.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.controller, super.key});
  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZirconColors.settingsCanvas,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // The settings reference uses a soft, photographic black backdrop,
          // rather than a flat page colour. Keep it deliberately subtle so
          // the frosted cards remain the visual hierarchy.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-.25, -.9),
                radius: 1.15,
                colors: <Color>[Color(0xFF142331), Color(0xFF071019), ZirconColors.canvas],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // The expanded two-card layout needs enough horizontal room
                // for both cards and their safe glass margins.
                return constraints.maxHeight > constraints.maxWidth ||
                        constraints.maxWidth < 760
                    ? _PortraitSettings(controller: controller)
                    : _LandscapeSettings(controller: controller);
              },
            ),
          ),
        ],
      ),
    );
  }
}

const List<(SettingsPage, String, IconData)> _pages =
    <(SettingsPage, String, IconData)>[
  (SettingsPage.record, 'Record', Icons.circle_outlined),
  (SettingsPage.camera, 'Camera', Icons.camera_alt_outlined),
  (SettingsPage.processing, 'Processing', Icons.auto_awesome_outlined),
  (SettingsPage.audio, 'Audio', Icons.bar_chart_outlined),
  (SettingsPage.monitor, 'Monitor', Icons.monitor_outlined),
  (SettingsPage.liveStream, 'Live Stream • Planned', Icons.rss_feed_outlined),
  (SettingsPage.media, 'Media', Icons.play_circle_outline),
  (SettingsPage.functionButtons, 'Function Buttons', Icons.grid_view_outlined),
  (SettingsPage.luts, 'LUTs • GPU Planned', Icons.gradient_rounded),
];

String _title(SettingsPage page) => _pages
    .firstWhere(((SettingsPage, String, IconData) item) => item.$1 == page)
    .$2;

class _LandscapeSettings extends StatelessWidget {
  const _LandscapeSettings({required this.controller});
  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 48, 28),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 364,
            child: GlassPanel(
              padding: EdgeInsets.zero,
              borderRadius: 24,
              color: ZirconColors.panelSoft,
              child: _Categories(controller: controller),
            ),
          ),
          const SizedBox(width: 48),
          Expanded(
            child: GlassPanel(
              padding: EdgeInsets.zero,
              borderRadius: 24,
              color: ZirconColors.panelSoft,
              child: Column(
                children: <Widget>[
                  SizedBox(
                    height: 60,
                    child: Center(
                      child: Text(
                        _title(controller.settingsPage),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _PageBody(controller: controller),
                    ),
                  ),
                  _ResetFooter(controller: controller),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResetFooter extends StatelessWidget {
  const _ResetFooter({required this.controller});
  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Row(
        children: <Widget>[
          TextButton(
            onPressed: () {},
            child: const Text(
              'Reset to Default',
              style: TextStyle(color: ZirconColors.record, fontSize: 16),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.history, color: ZirconColors.record),
          ),
        ],
      ),
    );
  }
}

class _PortraitSettings extends StatelessWidget {
  const _PortraitSettings({required this.controller});
  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 28, 18),
            child: Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'Back to camera',
                  onPressed: () => controller.setSection(AppSection.camera),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 11,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: GlassPanel(
              padding: EdgeInsets.zero,
              borderRadius: 24,
              color: ZirconColors.panelSoft,
              child: Column(
            children: <Widget>[
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _pages.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    color: ZirconColors.glassBorder,
                    indent: 60,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    final (SettingsPage page, String label, IconData icon) =
                        _pages[index];
                    final bool selected = controller.settingsPage == page;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => controller.setSettingsPage(page),
                        child: Container(
                          height: 54,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: selected
                                ? ZirconColors.settingsBlue
                                    .withValues(alpha: .2)
                                : Colors.transparent,
                          ),
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? ZirconColors.settingsBlue
                                      : ZirconColors.panelStrong,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(icon, size: 20, color: Colors.white),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (selected)
                                const CircleAvatar(
                                  radius: 4,
                                  backgroundColor: ZirconColors.blue,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          flex: 10,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
            child: GlassPanel(
              padding: EdgeInsets.zero,
              borderRadius: 24,
              color: ZirconColors.panelSoft,
              child: Column(
              children: <Widget>[
                const SizedBox(height: 16),
                Text(
                  _title(controller.settingsPage),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _PageBody(controller: controller),
                  ),
                ),
                _ResetFooter(controller: controller),
              ],
            ),
          ),
        ),
      ),
      ],
    ),
    );
  }
}

class _Categories extends StatelessWidget {
  const _Categories({required this.controller});
  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: <Widget>[
              IconButton(
                tooltip: 'Back to camera',
                onPressed: () => controller.setSection(AppSection.camera),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 4),
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: _pages.length,
            itemBuilder: (BuildContext context, int index) {
              final (SettingsPage page, String label, IconData icon) =
                  _pages[index];
              final bool selected = controller.settingsPage == page;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => controller.setSettingsPage(page),
                  child: Container(
                    height: 52,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      color: selected
                          ? ZirconColors.settingsBlue.withValues(alpha: .4)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          icon,
                          size: 20,
                          color: selected ? Colors.white : ZirconColors.textDim,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w500,
                            color: selected ? Colors.white : ZirconColors.text,
                          ),
                        ),
                        const Spacer(),
                        if (selected)
                          const CircleAvatar(
                            radius: 3,
                            backgroundColor: ZirconColors.blue,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Center(
          child: IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_horiz, color: ZirconColors.textDim),
          ),
        ),
        const SizedBox(height: 16),
      ],
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
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        color: ZirconColors.glassBorder,
      ),
      itemBuilder: (_, int index) => rows[index],
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
  ),
  _ChoiceRow<BitratePreset>(
    title: 'Bitrate Request',
    value: c.bitratePreset,
    values: BitratePreset.values,
    label: (BitratePreset value) => '${value.label} ${value.display}',
    onChanged: c.setBitratePreset,
  ),
  _ChoiceRow<RecordBitDepth>(
    title: 'Color Depth',
    value: c.recordBitDepth,
    values: RecordBitDepth.values,
    label: (RecordBitDepth value) => value.label,
    onChanged: c.setRecordBitDepth,
  ),
  _ChoiceRow<FilmStyle>(
    title: 'Color Profile',
    value: c.filmStyle,
    values: FilmStyle.values,
    label: (FilmStyle value) => value.label,
    onChanged: c.setFilmStyle,
  ),
  _ChoiceRow<LogCurve>(
    title: 'Tone Curve',
    value: c.logCurve,
    values: LogCurve.values,
    label: (LogCurve value) => value.label,
    onChanged: c.setLogCurve,
  ),
  const _ValueRow(title: 'Color Space', value: 'Rec.709'),
  _ChoiceRow<GuideRatio>(
    title: 'Aspect Ratio',
    value: c.guideRatio,
    values: GuideRatio.values,
    label: (GuideRatio value) => value.label,
    onChanged: c.setGuideRatio,
  ),
  const _ValueRow(title: 'Advanced', value: ''),
  _CustomRow(
    title: 'Developer Diagnostics',
    trailing: FilledButton(
      onPressed: c.diagBusy ? null : c.dumpP010Frame,
      child: Text(c.diagBusy ? 'DUMPING' : 'DUMP RAW P010'),
    ),
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
  _CustomRow(
    title: '10-Bit Rec.709 Preflight',
    trailing: SizedBox(
      height: 34,
      child: FilledButton(
        onPressed: c.tenBitPreflightBusy ? null : c.runTenBitRec709Preflight,
        child: Text(c.tenBitPreflightBusy ? 'CHECKING' : 'RUN CHECK'),
      ),
    ),
  ),
  if (c.tenBitPreflightResult != null)
    _DiagnosticResultRow(
      title: '10-Bit Preflight',
      value: c.tenBitPreflightResult!,
    ),
  _CustomRow(
    title: 'P010 UHD Session Test',
    trailing: SizedBox(
      height: 34,
      child: FilledButton(
        onPressed: c.tenBitSessionBusy ? null : c.runTenBitRec709SessionTest,
        child: Text(c.tenBitSessionBusy ? 'TESTING' : 'RUN TEST'),
      ),
    ),
  ),
  if (c.tenBitSessionResult != null)
    _DiagnosticResultRow(
      title: 'P010 Session',
      value: c.tenBitSessionResult!,
    ),
  _CustomRow(
    title: 'Real P010 Main10 Diagnostic',
    trailing: SizedBox(
      height: 34,
      child: FilledButton(
        onPressed: c.tenBitRecordingBusy ? null : c.runTenBitDiagnosticRecording,
        child: Text(c.tenBitRecordingBusy ? 'ENCODING' : 'RECORD'),
      ),
    ),
  ),
  if (c.tenBitRecordingResult != null)
    _DiagnosticResultRow(
      title: 'HEVC Main10 Diag',
      value: c.tenBitRecordingResult!,
    ),
  const _NoticeRow(
    text:
        'Requested values are only confirmed when the Camera2 capture result matches.',
  ),
];

List<Widget> _audioRows(CameraUiController c) => <Widget>[
  const _ValueRow(title: 'Audio Source', value: 'Device mic (fixed)', chevron: false),
  const _ValueRow(title: 'Audio Input Selection', value: 'Not available', enabled: false),
  const _ValueRow(title: 'Audio Format', value: 'AAC'),
  const _ValueRow(title: 'Channel Request', value: 'Stereo'),
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

class _DiagnosticResultRow extends StatelessWidget {
  const _DiagnosticResultRow({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: ZirconColors.accentSoft,
        border: Border.all(color: ZirconColors.glassBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            SelectableText(
              value,
              style: const TextStyle(color: ZirconColors.textMuted, fontSize: 12, height: 1.35),
            ),
          ],
        ),
      ),
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
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: ZirconColors.settingsTrack,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZirconColors.glassBorder),
          ),
          child: Row(
            children: values.map((T item) {
              final bool selected = item == value;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(item),
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: selected
                          ? ZirconColors.settingsBlue
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label(item),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : ZirconColors.textDim,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
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
