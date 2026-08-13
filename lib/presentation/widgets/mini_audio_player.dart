import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../domain/entities/media_item.dart';
import '../providers/audio_player_provider.dart';
import '../screens/media_viewer_screen.dart';

class MiniAudioPlayerOverlay extends StatefulWidget {
  const MiniAudioPlayerOverlay({
    required this.navigatorKey,
    super.key,
  });

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<MiniAudioPlayerOverlay> createState() => _MiniAudioPlayerOverlayState();
}

class _MiniAudioPlayerOverlayState extends State<MiniAudioPlayerOverlay> {
  Offset? _iconPosition;
  var _minimized = false;

  @override
  Widget build(BuildContext context) {
    final showMiniPlayer = context.select<AudioPlayerProvider, bool>(
      (audio) => audio.showMiniPlayer,
    );
    if (!showMiniPlayer) {
      return const SizedBox.shrink();
    }

    final hasPushedRoute = widget.navigatorKey.currentState?.canPop() ?? false;
    if (_minimized) {
      return Positioned.fill(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bottomPadding = MediaQuery.paddingOf(context).bottom;
            final keyboardPadding = MediaQuery.viewInsetsOf(context).bottom;
            final fallback = Offset(
              constraints.maxWidth - 74,
              constraints.maxHeight -
                  bottomPadding -
                  keyboardPadding -
                  (hasPushedRoute ? 74 : 154),
            );
            final position = _clampIconPosition(
              constraints,
              _iconPosition ?? fallback,
            );
            return Stack(
              children: [
                Positioned(
                  left: position.dx,
                  top: position.dy,
                  child: _MiniAudioIcon(
                    onExpand: () => setState(() => _minimized = false),
                    onDrag: (delta) {
                      setState(() {
                        final currentPosition = _iconPosition ?? position;
                        _iconPosition = _clampIconPosition(
                          constraints,
                          currentPosition + delta,
                        );
                      });
                    },
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final keyboardPadding = MediaQuery.viewInsetsOf(context).bottom;
    return Positioned(
      left: 12,
      right: 12,
      bottom: bottomPadding + keyboardPadding + (hasPushedRoute ? 12 : 84),
      child: _MiniAudioPlayer(
        navigatorKey: widget.navigatorKey,
        onMinimize: () => setState(() => _minimized = true),
      ),
    );
  }

  Offset _clampIconPosition(BoxConstraints constraints, Offset value) {
    const size = 58.0;
    final maxX = (constraints.maxWidth - size - 8).clamp(8.0, double.infinity);
    final maxY = (constraints.maxHeight - size - 8).clamp(8.0, double.infinity);
    return Offset(
      value.dx.clamp(8.0, maxX).toDouble(),
      value.dy.clamp(8.0, maxY).toDouble(),
    );
  }
}

class _MiniAudioPlayer extends StatelessWidget {
  const _MiniAudioPlayer({
    required this.navigatorKey,
    required this.onMinimize,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final VoidCallback onMinimize;

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioPlayerProvider>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final media = audio.media;
    if (media == null) {
      return const SizedBox.shrink();
    }

    final duration = audio.duration;
    final position = audio.position;

    return Material(
      elevation: 12,
      color: colors.surface,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniSeekBar(
                position: position,
                duration: duration,
                onSeek: audio.seekTo,
              ),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _openFullPlayer(media),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 3,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.audiotrack,
                              color: colors.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    media.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  Text(
                                    '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.t('Back 5 seconds'),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 34,
                      height: 38,
                    ),
                    onPressed: audio.skipBack,
                    icon: const Icon(Icons.replay_5),
                  ),
                  IconButton.filledTonal(
                    tooltip: context.t(audio.isPlaying ? 'Pause' : 'Play'),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 38,
                      height: 38,
                    ),
                    onPressed: audio.togglePlayback,
                    icon:
                        Icon(audio.isPlaying ? Icons.pause : Icons.play_arrow),
                  ),
                  IconButton(
                    tooltip: context.t('Forward 5 seconds'),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 34,
                      height: 38,
                    ),
                    onPressed: audio.skipForward,
                    icon: const Icon(Icons.forward_5),
                  ),
                  IconButton(
                    tooltip: context.t('Minimize player'),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 34,
                      height: 38,
                    ),
                    onPressed: onMinimize,
                    icon: const Icon(Icons.remove),
                  ),
                  IconButton(
                    tooltip: context.t('Stop audio'),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 34,
                      height: 38,
                    ),
                    onPressed: audio.stopAndClear,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFullPlayer(MediaItem media) async {
    await navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => AudioPlayerScreen(media: media),
      ),
    );
  }
}

class _MiniAudioIcon extends StatelessWidget {
  const _MiniAudioIcon({
    required this.onExpand,
    required this.onDrag,
  });

  final VoidCallback onExpand;
  final ValueChanged<Offset> onDrag;

  @override
  Widget build(BuildContext context) {
    final isPlaying = context.select<AudioPlayerProvider, bool>(
      (audio) => audio.isPlaying,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onExpand,
      onPanUpdate: (details) => onDrag(details.delta),
      child: RepaintBoundary(
        child: Material(
          elevation: 10,
          color: Theme.of(context).colorScheme.primaryContainer,
          shape: const CircleBorder(),
          child: SizedBox.square(
            dimension: 58,
            child: Icon(
              isPlaying ? Icons.audiotrack : Icons.play_arrow,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniSeekBar extends StatelessWidget {
  const _MiniSeekBar({
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = duration > Duration.zero;
    final progress = enabled
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Semantics(
      label: context.t('Audio progress'),
      value: '${(progress * 100).round()}%',
      child: SizedBox(
        height: 24,
        child: LayoutBuilder(
          builder: (context, constraints) {
            void seekFromLocalPosition(Offset localPosition) {
              if (!enabled || constraints.maxWidth <= 0) {
                return;
              }
              final fraction =
                  (localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
              onSeek(
                Duration(
                  milliseconds: (duration.inMilliseconds * fraction).round(),
                ),
              );
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => seekFromLocalPosition(
                details.localPosition,
              ),
              onHorizontalDragStart: (details) => seekFromLocalPosition(
                details.localPosition,
              ),
              onHorizontalDragUpdate: (details) => seekFromLocalPosition(
                details.localPosition,
              ),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.outlineVariant.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: (constraints.maxWidth * progress - 5).clamp(
                      0.0,
                      constraints.maxWidth - 10,
                    ),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color:
                            enabled ? colors.primary : colors.onSurfaceVariant,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.shadow.withValues(alpha: 0.22),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}
