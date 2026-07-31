import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../model/camera_ui_controller.dart';
import '../widgets/glass_panel.dart';
import '../widgets/side_rail.dart';

class MediaScreen extends StatelessWidget {
  const MediaScreen({required this.controller, super.key});

  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: <Widget>[
          Expanded(
            child: SafeArea(
              minimum: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final bool compact = constraints.maxWidth < 1000;
                          return Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'MEDIA',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineSmall,
                                    ),
                                    const SizedBox(height: 3),
                                    const Text(
                                      'Review, protect, and verify clips',
                                      maxLines: 1,
                                      overflow: TextOverflow.fade,
                                      style: TextStyle(
                                        color: ZirconColors.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              PrototypeBadge(compact: compact),
                              const SizedBox(width: 10),
                              _StorageSummary(compact: compact),
                            ],
                          );
                        },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          flex: 7,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              ZirconRadius.lg,
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: <Widget>[
                                Image.asset(
                                  'assets/mock_preview.jpg',
                                  fit: BoxFit.cover,
                                ),
                                const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: <Color>[
                                        Colors.transparent,
                                        Color(0xCC05070A),
                                      ],
                                    ),
                                  ),
                                ),
                                Center(
                                  child: _PlaybackPrompt(
                                    controller: controller,
                                  ),
                                ),
                                Positioned(
                                  left: 14,
                                  right: 14,
                                  bottom: 12,
                                  child: _LastClipPath(controller: controller),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 4,
                          child: _MetadataPanel(controller: controller),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 62,
                    child: GlassPanel(
                      color: ZirconColors.panelStrong,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            controller.lastClipUri == null
                                ? Icons.video_file_outlined
                                : Icons.check_circle_outline_rounded,
                            color: controller.lastClipUri == null
                                ? ZirconColors.textMuted
                                : ZirconColors.good,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text(
                                  controller.lastClipUri == null
                                      ? 'NO COMPLETED CLIP THIS SESSION'
                                      : 'LAST CLIP FINALIZED IN MEDIASTORE',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  controller.lastClipUri ??
                                      'Record a real clip, then return here.',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SideRail(controller: controller),
        ],
      ),
    );
  }
}

class _StorageSummary extends StatelessWidget {
  const _StorageSummary({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.sd_storage_outlined,
            size: 16,
            color: ZirconColors.accent,
          ),
          const SizedBox(width: 8),
          if (compact)
            const Text(
              'MEDIASTORE',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'REAL CLIP DESTINATION',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const Text(
                  'Movies/ZirconCinema',
                  style: TextStyle(fontSize: 10),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PlaybackPrompt extends StatelessWidget {
  const _PlaybackPrompt({required this.controller});

  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    final bool hasClip = controller.lastClipUri != null;
    return Material(
      color: ZirconColors.panelStrong,
      borderRadius: BorderRadius.circular(ZirconRadius.pill),
      child: InkWell(
        onTap: hasClip ? controller.openLastClip : null,
        borderRadius: BorderRadius.circular(ZirconRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                hasClip
                    ? Icons.play_circle_outline_rounded
                    : Icons.videocam_off_outlined,
                color: hasClip ? ZirconColors.accent : ZirconColors.textMuted,
                size: 28,
              ),
              const SizedBox(width: 9),
              Text(
                hasClip ? 'OPEN LAST CLIP' : 'NO REAL CLIP YET',
                style: TextStyle(
                  color: hasClip ? ZirconColors.text : ZirconColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LastClipPath extends StatelessWidget {
  const _LastClipPath({required this.controller});

  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      color: ZirconColors.panelStrong,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Text(
        controller.lastClipUri ??
            'Preview image is illustrative. Real clips open in the Android player.',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: ZirconColors.textMuted, fontSize: 9),
      ),
    );
  }
}

class _MetadataPanel extends StatelessWidget {
  const _MetadataPanel({required this.controller});

  final CameraUiController controller;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(13),
      color: ZirconColors.panelStrong,
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'CLIP METADATA',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              const Icon(
                Icons.lock_outline_rounded,
                size: 17,
                color: ZirconColors.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MetadataRow('PROJECT', controller.project),
          _MetadataRow('NEXT CLIP', controller.clipName),
          _MetadataRow(
            'STATUS',
            controller.lastClipUri == null ? 'NO SESSION CLIP' : 'FINALIZED',
          ),
          _MetadataRow(
            'FORMAT',
            '${controller.resolution} • ${controller.fps} FPS',
          ),
          const _MetadataRow('PIPELINE', 'CAMERA2 DIRECT ISP'),
          _MetadataRow('PROFILE', controller.profile),
          const _MetadataRow('CODEC', 'HEVC MAIN 8-BIT + AAC'),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ZirconColors.warning.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(ZirconRadius.sm),
              border: Border.all(
                color: ZirconColors.warning.withValues(alpha: .35),
              ),
            ),
            child: Text(
              controller.lastClipUri == null
                  ? 'No completed clip is available in this app session.'
                  : 'Tap OPEN LAST CLIP to review the real MP4 in an Android video player.',
              style: const TextStyle(color: ZirconColors.warning, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 68,
            child: Text(label, style: Theme.of(context).textTheme.labelSmall),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
