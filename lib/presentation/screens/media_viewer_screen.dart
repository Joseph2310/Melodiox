import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/localization/app_localizations.dart';
import '../../domain/entities/media_item.dart';
import '../providers/audio_player_provider.dart';
import '../widgets/tutorial_media.dart';
import 'media_trimmer_screen.dart';

class ImageViewerItem {
  const ImageViewerItem({
    required this.path,
    required this.title,
  });

  final String path;
  final String title;
}

class FullscreenImageScreen extends StatefulWidget {
  const FullscreenImageScreen({
    required this.path,
    required this.title,
    this.items,
    this.initialIndex = 0,
    super.key,
  });

  final String path;
  final String title;
  final List<ImageViewerItem>? items;
  final int initialIndex;

  @override
  State<FullscreenImageScreen> createState() => _FullscreenImageScreenState();
}

class _FullscreenImageScreenState extends State<FullscreenImageScreen> {
  late final List<ImageViewerItem> _items =
      widget.items == null || widget.items!.isEmpty
          ? [ImageViewerItem(path: widget.path, title: widget.title)]
          : widget.items!;
  late final PageController _controller = PageController(
    initialPage: _initialIndex,
  );
  late int _index = _initialIndex;
  var _pagingEnabled = true;

  int get _initialIndex =>
      widget.initialIndex.clamp(0, _items.length - 1).toInt();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _items[_index];
    return Scaffold(
      appBar: AppBar(
        title: Text(current.title),
        actions: [
          if (_items.length > 1)
            Center(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 16),
                child: Text('${_index + 1}/${_items.length}'),
              ),
            ),
        ],
      ),
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _controller,
        physics: _pagingEnabled
            ? const PageScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        itemCount: _items.length,
        onPageChanged: (value) {
          setState(() {
            _index = value;
            _pagingEnabled = true;
          });
        },
        itemBuilder: (context, index) {
          return _GalleryImagePage(
            path: _items[index].path,
            onZoomChanged: (zoomed) {
              if (_pagingEnabled == !zoomed) {
                return;
              }
              setState(() => _pagingEnabled = !zoomed);
            },
          );
        },
      ),
    );
  }
}

class _GalleryImagePage extends StatefulWidget {
  const _GalleryImagePage({
    required this.path,
    required this.onZoomChanged,
  });

  final String path;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_GalleryImagePage> createState() => _GalleryImagePageState();
}

class _GalleryImagePageState extends State<_GalleryImagePage> {
  final _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;
  var _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_handleTransformChanged);
  }

  @override
  void dispose() {
    _transformationController
      ..removeListener(_handleTransformChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1,
        maxScale: 4,
        clipBehavior: Clip.hardEdge,
        child: SizedBox.expand(
          child: TutorialFullImage(path: widget.path),
        ),
      ),
    );
  }

  void _toggleZoom() {
    if (_currentScale > 1.01) {
      _transformationController.value = Matrix4.identity();
      return;
    }

    final position = _doubleTapDetails?.localPosition ?? Offset.zero;
    const scale = 2.5;
    _transformationController.value = Matrix4.identity()
      ..translateByDouble(
        -position.dx * (scale - 1),
        -position.dy * (scale - 1),
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _handleTransformChanged() {
    final zoomed = _currentScale > 1.01;
    if (zoomed == _zoomed) {
      return;
    }
    _zoomed = zoomed;
    widget.onZoomChanged(zoomed);
  }

  double get _currentScale {
    return _transformationController.value.getMaxScaleOnAxis();
  }
}

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({required this.media, super.key});

  final MediaItem media;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  static const _seekStep = Duration(seconds: 5);

  VideoPlayerController? _controller;
  String? _errorMessage;
  var _speed = 1.0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.media.title),
        actions: [
          IconButton(
            tooltip: context.t('Trim media'),
            onPressed: controller == null || !controller.value.isInitialized
                ? null
                : _openTrimmer,
            icon: const Icon(Icons.content_cut),
          ),
        ],
      ),
      body: _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_errorMessage!, textAlign: TextAlign.center),
              ),
            )
          : controller == null || !controller.value.isInitialized
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: controller.value.aspectRatio,
                          child: VideoPlayer(controller),
                        ),
                      ),
                    ),
                    _MediaControls(
                      playing: controller.value.isPlaying,
                      position: controller.value.position,
                      duration: controller.value.duration,
                      speed: _speed,
                      onToggle: _togglePlayback,
                      onSeek: _seekTo,
                      onSkipBack: () => _seekBy(-_seekStep),
                      onSkipForward: () => _seekBy(_seekStep),
                      onSpeedChanged: _setSpeed,
                    ),
                  ],
                ),
    );
  }

  Future<void> _initialize() async {
    try {
      setState(() => _errorMessage = null);
      final path = widget.media.localPath;
      if (path == null || path.trim().isEmpty) {
        setState(() => _errorMessage = context.t('Video file is missing.'));
        return;
      }
      final file = File(path);
      if (!await file.exists()) {
        setState(() => _errorMessage = context.t('Video file was not found.'));
        return;
      }
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      controller.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
      setState(() => _controller = controller);
    } catch (error) {
      setState(
          () => _errorMessage = '${context.t('Unable to open video')}: $error');
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    controller.value.isPlaying
        ? await controller.pause()
        : await controller.play();
  }

  Future<void> _seekBy(Duration offset) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    await _seekTo(controller.value.position + offset);
  }

  Future<void> _seekTo(Duration position) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final duration = controller.value.duration;
    final clamped = _clampDuration(position, duration);
    await controller.seekTo(clamped);
  }

  Future<void> _setSpeed(double speed) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    await controller.setPlaybackSpeed(speed);
    setState(() => _speed = speed);
  }

  Future<void> _openTrimmer() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    final duration = controller.value.duration;
    await controller.pause();
    setState(() => _controller = null);
    await controller.dispose();
    if (!mounted) {
      return;
    }

    final trimmed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MediaTrimmerScreen(
          media: widget.media,
          duration: duration,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    await _initialize();
    if (trimmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('Media trimmed'))),
      );
    }
  }
}

class AudioPlayerScreen extends StatefulWidget {
  const AudioPlayerScreen({required this.media, super.key});

  final MediaItem media;

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  late AudioPlayerProvider _audio;
  var _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialized = true;
    _audio = context.read<AudioPlayerProvider>();
    _audio.setFullScreenVisible(true);
    _audio.load(widget.media);
  }

  @override
  void didUpdateWidget(covariant AudioPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.localPath != widget.media.localPath ||
        oldWidget.media.externalUrl != widget.media.externalUrl) {
      _audio.load(widget.media);
    }
  }

  @override
  void dispose() {
    _audio.setFullScreenVisible(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioPlayerProvider>();
    final media = audio.media ?? widget.media;
    return Scaffold(
      appBar: AppBar(
        title: Text(media.title),
        actions: [
          IconButton(
            tooltip: context.t('Trim media'),
            onPressed: audio.duration <= Duration.zero
                ? null
                : () => _openTrimmer(
                      audio,
                      media,
                    ),
            icon: const Icon(Icons.content_cut),
          ),
          IconButton(
            tooltip: context.t('Stop audio'),
            onPressed: () async {
              await audio.stopAndClear();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: audio.errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.t(audio.errorMessage!),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : audio.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Icon(
                          Icons.audiotrack,
                          size: 96,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    _MediaControls(
                      playing: audio.isPlaying,
                      position: audio.position,
                      duration: audio.duration,
                      speed: audio.speed,
                      onToggle: audio.togglePlayback,
                      onSeek: audio.seekTo,
                      onSkipBack: audio.skipBack,
                      onSkipForward: audio.skipForward,
                      onSpeedChanged: audio.setSpeed,
                    ),
                  ],
                ),
    );
  }

  Future<void> _openTrimmer(
    AudioPlayerProvider audio,
    MediaItem media,
  ) async {
    final duration = audio.duration;
    if (duration <= Duration.zero) {
      return;
    }
    await audio.stopForEditing();
    if (!mounted) {
      return;
    }
    final trimmed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MediaTrimmerScreen(media: media, duration: duration),
      ),
    );
    if (!mounted) {
      return;
    }
    await audio.load(media, forceReload: true);
    if (trimmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('Media trimmed'))),
      );
    }
  }
}

class _MediaControls extends StatelessWidget {
  const _MediaControls({
    required this.playing,
    required this.position,
    required this.duration,
    required this.speed,
    required this.onToggle,
    required this.onSeek,
    required this.onSkipBack,
    required this.onSkipForward,
    required this.onSpeedChanged,
  });

  final bool playing;
  final Duration position;
  final Duration duration;
  final double speed;
  final VoidCallback onToggle;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onSkipBack;
  final VoidCallback onSkipForward;
  final ValueChanged<double> onSpeedChanged;

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    final max =
        duration.inMilliseconds <= 0 ? 1.0 : duration.inMilliseconds.toDouble();
    final value = position.inMilliseconds.clamp(0, max.toInt()).toDouble();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Slider(
              value: value,
              max: max,
              onChanged: (next) {
                onSeek(Duration(milliseconds: next.round()));
              },
            ),
            Row(
              children: [
                Text(_formatDuration(position)),
                const Spacer(),
                Text(_formatDuration(duration)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: context.t('Back 5 seconds'),
                  onPressed: onSkipBack,
                  icon: const Icon(Icons.replay_5),
                ),
                IconButton.filled(
                  tooltip: context.t(playing ? 'Pause' : 'Play'),
                  iconSize: 36,
                  onPressed: onToggle,
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                ),
                IconButton(
                  tooltip: context.t('Forward 5 seconds'),
                  onPressed: onSkipForward,
                  icon: const Icon(Icons.forward_5),
                ),
                const SizedBox(width: 12),
                PopupMenuButton<double>(
                  tooltip: context.t('Playback speed'),
                  onSelected: onSpeedChanged,
                  itemBuilder: (context) => [
                    for (final item in _speeds)
                      PopupMenuItem(value: item, child: Text('${item}x')),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('${speed}x'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Duration _clampDuration(Duration value, Duration? max) {
  final upper = max ?? Duration.zero;
  if (value < Duration.zero) {
    return Duration.zero;
  }
  if (upper > Duration.zero && value > upper) {
    return upper;
  }
  return value;
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}
