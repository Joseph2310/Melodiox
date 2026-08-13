import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:video_player/video_player.dart';

import '../../core/constants/media_types.dart';
import '../../core/localization/app_localizations.dart';
import '../../domain/entities/media_item.dart';
import '../../services/media_trim_service.dart';

class MediaTrimmerScreen extends StatefulWidget {
  const MediaTrimmerScreen({
    required this.media,
    required this.duration,
    super.key,
  });

  final MediaItem media;
  final Duration duration;

  @override
  State<MediaTrimmerScreen> createState() => _MediaTrimmerScreenState();
}

class _MediaTrimmerScreenState extends State<MediaTrimmerScreen> {
  final _previewKey = GlobalKey<_MediaTrimPreviewState>();

  Duration _start = Duration.zero;
  late Duration _end = widget.duration;
  var _saving = false;

  Duration get _minimumGap {
    return widget.duration.inMilliseconds >= 1000
        ? const Duration(seconds: 1)
        : const Duration(milliseconds: 1);
  }

  bool get _canTrim {
    return widget.media.localPath != null &&
        widget.media.localPath!.trim().isNotEmpty &&
        widget.duration > Duration.zero &&
        _end > _start &&
        (_start > Duration.zero || _end < widget.duration);
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.duration;
    final path = widget.media.localPath;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('Trim media')),
        actions: [
          TextButton(
            onPressed: _saving ? null : _reset,
            child: Text(context.t('Reset')),
          ),
        ],
      ),
      body: path == null || path.trim().isEmpty
          ? Center(child: Text(context.t('Media file is missing.')))
          : duration <= Duration.zero
              ? Center(child: Text(context.t('Media duration is unavailable.')))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      widget.media.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _MediaTrimPreview(
                      key: _previewKey,
                      media: widget.media,
                      start: _start,
                      end: _end,
                      duration: duration,
                    ),
                    const SizedBox(height: 12),
                    _SelectionSummary(
                      start: _start,
                      end: _end,
                      total: duration,
                    ),
                    const SizedBox(height: 20),
                    _TrimRangeSlider(
                      start: _start,
                      end: _end,
                      duration: duration,
                      onChanged: _setRange,
                    ),
                    const SizedBox(height: 20),
                    _DurationInput(
                      label: context.t('Start'),
                      value: _start,
                      max: duration - _minimumGap,
                      onChanged: _setStart,
                    ),
                    const SizedBox(height: 12),
                    _DurationInput(
                      label: context.t('End'),
                      value: _end,
                      max: duration,
                      onChanged: _setEnd,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: Text(context.t('Fast trim')),
                        subtitle: Text(
                          context.t(
                            'The selected copied media file will be replaced after the trim succeeds.',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _saving || !_canTrim ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.content_cut),
            label: Text(context.t(_saving ? 'Trimming...' : 'Save trim')),
          ),
        ),
      ),
    );
  }

  void _setRange(RangeValues values) {
    final start = Duration(milliseconds: values.start.round());
    final end = Duration(milliseconds: values.end.round());
    setState(() {
      _start = _clampStart(start);
      _end = _clampEnd(end);
      if (_end <= _start) {
        _end = _clampEnd(_start + _minimumGap);
      }
    });
  }

  void _setStart(Duration value) {
    setState(() {
      _start = _clampStart(value);
      if (_end <= _start) {
        _end = _clampEnd(_start + _minimumGap);
      }
    });
  }

  void _setEnd(Duration value) {
    setState(() {
      _end = _clampEnd(value);
      if (_end <= _start) {
        _start = _clampStart(_end - _minimumGap);
      }
    });
  }

  void _reset() {
    setState(() {
      _start = Duration.zero;
      _end = widget.duration;
    });
  }

  Future<void> _save() async {
    final path = widget.media.localPath;
    if (path == null || path.trim().isEmpty) {
      return;
    }
    setState(() => _saving = true);
    try {
      await _previewKey.currentState?.releaseForTrim();
      await MediaTrimService().trimInPlace(
        sourcePath: path,
        start: _start,
        end: _end,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        await _previewKey.currentState?.reload();
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.t('Trim failed')}: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Duration _clampStart(Duration value) {
    final max = widget.duration - _minimumGap;
    return _clampDuration(value, Duration.zero, max);
  }

  Duration _clampEnd(Duration value) {
    return _clampDuration(value, _minimumGap, widget.duration);
  }
}

class _MediaTrimPreview extends StatefulWidget {
  const _MediaTrimPreview({
    required this.media,
    required this.start,
    required this.end,
    required this.duration,
    super.key,
  });

  final MediaItem media;
  final Duration start;
  final Duration end;
  final Duration duration;

  @override
  State<_MediaTrimPreview> createState() => _MediaTrimPreviewState();
}

class _MediaTrimPreviewState extends State<_MediaTrimPreview> {
  just_audio.AudioPlayer? _audioPlayer;
  VideoPlayerController? _videoController;
  StreamSubscription<Duration>? _audioPositionSubscription;
  Timer? _seekDebounce;
  Duration _position = Duration.zero;
  String? _errorMessage;
  var _loading = true;
  var _playingSelection = false;

  bool get _isVideo => widget.media.mediaType == MediaType.performanceVideo;

  bool get _isPlaying {
    if (_isVideo) {
      return _videoController?.value.isPlaying ?? false;
    }
    return _audioPlayer?.playing ?? false;
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant _MediaTrimPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.localPath != widget.media.localPath ||
        oldWidget.media.mediaType != widget.media.mediaType) {
      reload();
      return;
    }
    if (oldWidget.start != widget.start || oldWidget.end != widget.end) {
      _scheduleSeekToStart();
    }
  }

  @override
  void dispose() {
    _seekDebounce?.cancel();
    _audioPositionSubscription?.cancel();
    _audioPlayer?.dispose();
    _videoController
      ?..removeListener(_handleVideoTick)
      ..dispose();
    super.dispose();
  }

  Future<void> releaseForTrim() async {
    _seekDebounce?.cancel();
    _playingSelection = false;
    await _audioPositionSubscription?.cancel();
    _audioPositionSubscription = null;
    await _audioPlayer?.dispose();
    _audioPlayer = null;
    final videoController = _videoController;
    if (videoController != null) {
      videoController.removeListener(_handleVideoTick);
      await videoController.dispose();
      _videoController = null;
    }
    if (mounted) {
      setState(() => _loading = true);
    }
  }

  Future<void> reload() async {
    await releaseForTrim();
    await _initialize();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.t('Preview selection'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            _buildMediaSurface(context),
            const SizedBox(height: 10),
            _PreviewSeekSlider(
              start: widget.start,
              end: widget.end,
              position: _position,
              onChanged: _seek,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(_formatDuration(_position)),
                const Spacer(),
                Text(
                  '${_formatDuration(widget.start)} - ${_formatDuration(widget.end)}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: context.t('Back 5 seconds'),
                  onPressed: _canPreview
                      ? () => _seekBy(const Duration(seconds: -5))
                      : null,
                  icon: const Icon(Icons.replay_5),
                ),
                FilledButton.icon(
                  onPressed: _canPreview ? _toggleSelectionPlayback : null,
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  label: Text(
                    context.t(
                      _isPlaying ? 'Pause preview' : 'Play selected part',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.t('Forward 5 seconds'),
                  onPressed: _canPreview
                      ? () => _seekBy(const Duration(seconds: 5))
                      : null,
                  icon: const Icon(Icons.forward_5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSurface(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 172,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorMessage != null) {
      return SizedBox(
        height: 172,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    if (_isVideo) {
      final controller = _videoController;
      if (controller == null || !controller.value.isInitialized) {
        return const _PreviewPlaceholder(icon: Icons.videocam_off_outlined);
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ColoredBox(
          color: Colors.black,
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
        ),
      );
    }
    return const _PreviewPlaceholder(icon: Icons.audiotrack);
  }

  Future<void> _initialize() async {
    final path = widget.media.localPath;
    if (path == null || path.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = context.t('Media file is missing.');
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
        _position = widget.start;
      });
    }

    try {
      if (_isVideo) {
        final controller = VideoPlayerController.file(File(path));
        await controller.initialize();
        controller.addListener(_handleVideoTick);
        _videoController = controller;
        await controller.seekTo(widget.start);
      } else {
        final player = just_audio.AudioPlayer();
        await player.setFilePath(path);
        await player.seek(widget.start);
        _audioPositionSubscription = player.positionStream.listen((position) {
          _handlePositionTick(position);
        });
        _audioPlayer = player;
      }
      if (mounted) {
        setState(() {
          _loading = false;
          _position = widget.start;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = '${context.t('Preview unavailable')}: $error';
        });
      }
    }
  }

  Future<void> _toggleSelectionPlayback() async {
    if (_isPlaying) {
      _playingSelection = false;
      await _pause();
      return;
    }
    await _seek(_resumePosition);
    _playingSelection = true;
    await _play();
  }

  Future<void> _play() async {
    if (_isVideo) {
      await _videoController?.play();
    } else {
      await _audioPlayer?.play();
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pause() async {
    if (_isVideo) {
      await _videoController?.pause();
    } else {
      await _audioPlayer?.pause();
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _seek(Duration position) async {
    final clamped = _clampDuration(position, widget.start, widget.end);
    if (_isVideo) {
      await _videoController?.seekTo(clamped);
    } else {
      await _audioPlayer?.seek(clamped);
    }
    if (mounted) {
      setState(() => _position = clamped);
    }
  }

  Future<void> _seekBy(Duration offset) {
    final base = _clampDuration(_position, widget.start, widget.end);
    return _seek(base + offset);
  }

  Duration get _resumePosition {
    if (_position > widget.start && _position < widget.end) {
      return _position;
    }
    return widget.start;
  }

  void _scheduleSeekToStart() {
    _seekDebounce?.cancel();
    _seekDebounce = Timer(const Duration(milliseconds: 90), () async {
      final wasPlaying = _isPlaying;
      await _seek(widget.start);
      if (wasPlaying) {
        _playingSelection = true;
        await _play();
      }
    });
  }

  void _handleVideoTick() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    _handlePositionTick(controller.value.position);
  }

  void _handlePositionTick(Duration position) {
    if (_playingSelection && position >= widget.end) {
      _playingSelection = false;
      _pause();
      _seek(widget.start);
      return;
    }
    if (mounted) {
      setState(() => _position = position);
    }
  }

  bool get _canPreview {
    return !_loading &&
        _errorMessage == null &&
        widget.end > widget.start &&
        (_isVideo
            ? (_videoController?.value.isInitialized ?? false)
            : _audioPlayer != null);
  }
}

class _PreviewSeekSlider extends StatelessWidget {
  const _PreviewSeekSlider({
    required this.start,
    required this.end,
    required this.position,
    required this.onChanged,
  });

  final Duration start;
  final Duration end;
  final Duration position;
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) {
    final min = start.inMilliseconds.toDouble();
    final max = math.max(min + 1, end.inMilliseconds.toDouble());
    final value = position.inMilliseconds.clamp(min.round(), max.round());
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),
      child: Slider(
        value: value.toDouble(),
        min: min,
        max: max,
        label: _formatDuration(Duration(milliseconds: value)),
        onChanged: (next) {
          onChanged(Duration(milliseconds: next.round()));
        },
      ),
    );
  }
}

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 172,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 72, color: colors.primary),
    );
  }
}

class _TrimRangeSlider extends StatelessWidget {
  const _TrimRangeSlider({
    required this.start,
    required this.end,
    required this.duration,
    required this.onChanged,
  });

  final Duration start;
  final Duration end;
  final Duration duration;
  final ValueChanged<RangeValues> onChanged;

  @override
  Widget build(BuildContext context) {
    final max = math.max(1, duration.inMilliseconds).toDouble();
    final values = RangeValues(
      start.inMilliseconds.clamp(0, max.toInt()).toDouble(),
      end.inMilliseconds.clamp(0, max.toInt()).toDouble(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('Drag handles'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        RangeSlider(
          values: values,
          max: max,
          labels: RangeLabels(_formatDuration(start), _formatDuration(end)),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SelectionSummary extends StatelessWidget {
  const _SelectionSummary({
    required this.start,
    required this.end,
    required this.total,
  });

  final Duration start;
  final Duration end;
  final Duration total;

  @override
  Widget build(BuildContext context) {
    final selected = end - start;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _TimeSummaryValue(
              label: context.t('Start'),
              value: _formatDuration(start),
            ),
            _TimeSummaryValue(
              label: context.t('End'),
              value: _formatDuration(end),
            ),
            _TimeSummaryValue(
              label: context.t('Selected'),
              value: _formatDuration(selected),
            ),
            _TimeSummaryValue(
              label: context.t('Total'),
              value: _formatDuration(total),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeSummaryValue extends StatelessWidget {
  const _TimeSummaryValue({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

class _DurationInput extends StatefulWidget {
  const _DurationInput({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final Duration value;
  final Duration max;
  final ValueChanged<Duration> onChanged;

  @override
  State<_DurationInput> createState() => _DurationInputState();
}

class _DurationInputState extends State<_DurationInput> {
  late final TextEditingController _hoursController;
  late final TextEditingController _minutesController;
  late final TextEditingController _secondsController;

  @override
  void initState() {
    super.initState();
    _hoursController = TextEditingController();
    _minutesController = TextEditingController();
    _secondsController = TextEditingController();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant _DurationInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _syncControllers();
    }
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TimeNumberField(
                    controller: _hoursController,
                    label: context.t('Hours'),
                    onChanged: _notifyChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TimeNumberField(
                    controller: _minutesController,
                    label: context.t('Minutes'),
                    onChanged: _notifyChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TimeNumberField(
                    controller: _secondsController,
                    label: context.t('Seconds'),
                    onChanged: _notifyChanged,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _syncControllers() {
    _hoursController.text = widget.value.inHours.toString();
    _minutesController.text =
        widget.value.inMinutes.remainder(60).toString().padLeft(2, '0');
    _secondsController.text =
        widget.value.inSeconds.remainder(60).toString().padLeft(2, '0');
  }

  void _notifyChanged() {
    final hours = int.tryParse(_hoursController.text) ?? 0;
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    final seconds = int.tryParse(_secondsController.text) ?? 0;
    widget.onChanged(
      _clampDuration(
        Duration(hours: hours, minutes: minutes, seconds: seconds),
        Duration.zero,
        widget.max,
      ),
    );
  }
}

class _TimeNumberField extends StatelessWidget {
  const _TimeNumberField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => onChanged(),
    );
  }
}

Duration _clampDuration(Duration value, Duration min, Duration max) {
  if (value < min) {
    return min;
  }
  if (max > min && value > max) {
    return max;
  }
  return value;
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}
