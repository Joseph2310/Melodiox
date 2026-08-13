import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/entities/media_item.dart';

class AudioPlayerProvider extends ChangeNotifier {
  AudioPlayerProvider() {
    _positionSubscription = _player.positionStream.listen((value) {
      _position = value;
      notifyListeners();
    });
    _durationSubscription = _player.durationStream.listen((value) {
      _duration = value ?? Duration.zero;
      notifyListeners();
    });
    _stateSubscription = _player.playerStateStream.listen((_) {
      notifyListeners();
    });
  }

  static const seekStep = Duration(seconds: 5);

  final AudioPlayer _player = AudioPlayer();
  late final StreamSubscription<Duration> _positionSubscription;
  late final StreamSubscription<Duration?> _durationSubscription;
  late final StreamSubscription<PlayerState> _stateSubscription;

  MediaItem? _media;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _errorMessage;
  var _speed = 1.0;
  var _isLoading = false;
  var _fullScreenVisible = false;

  MediaItem? get media => _media;
  Duration get position => _position;
  Duration get duration => _duration;
  String? get errorMessage => _errorMessage;
  double get speed => _speed;
  bool get isLoading => _isLoading;
  bool get isPlaying => _player.playing;
  bool get hasMedia => _media != null;
  bool get showMiniPlayer =>
      _media != null && _errorMessage == null && !_fullScreenVisible;

  Future<void> load(
    MediaItem media, {
    bool autoPlay = false,
    bool forceReload = false,
  }) async {
    final currentPath = _media?.localPath;
    final nextPath = media.localPath;
    if (currentPath != null &&
        nextPath != null &&
        currentPath == nextPath &&
        _errorMessage == null &&
        !forceReload) {
      _media = media;
      if (autoPlay) {
        await play();
      }
      notifyListeners();
      return;
    }

    _media = media;
    _position = Duration.zero;
    _duration = Duration.zero;
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      if (nextPath == null || nextPath.trim().isEmpty) {
        throw const AudioPlayerException('Audio file is missing.');
      }
      final file = File(nextPath);
      if (!await file.exists()) {
        throw const AudioPlayerException('Audio file was not found.');
      }
      await _player.stop();
      await _player.setFilePath(nextPath);
      await _player.setSpeed(_speed);
      if (autoPlay) {
        await _player.play();
      }
    } catch (error) {
      _errorMessage = error is AudioPlayerException
          ? error.message
          : 'Unable to open audio: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> togglePlayback() async {
    if (_player.playing) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> play() async {
    if (_media == null || _errorMessage != null || _isLoading) {
      return;
    }
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> stopForEditing() async {
    await _player.stop();
    _position = Duration.zero;
    notifyListeners();
  }

  Future<void> stopAndClear() async {
    await _player.stop();
    _media = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> skipBack() {
    return seekBy(-seekStep);
  }

  Future<void> skipForward() {
    return seekBy(seekStep);
  }

  Future<void> seekBy(Duration offset) {
    return seekTo(_position + offset);
  }

  Future<void> seekTo(Duration position) async {
    await _player.seek(_clampDuration(position, _duration));
  }

  Future<void> setSpeed(double speed) async {
    _speed = speed;
    await _player.setSpeed(speed);
    notifyListeners();
  }

  void setFullScreenVisible(bool value) {
    if (_fullScreenVisible == value) {
      return;
    }
    _fullScreenVisible = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSubscription.cancel();
    _durationSubscription.cancel();
    _stateSubscription.cancel();
    _player.dispose();
    super.dispose();
  }

  Duration _clampDuration(Duration value, Duration max) {
    if (value < Duration.zero) {
      return Duration.zero;
    }
    if (max > Duration.zero && value > max) {
      return max;
    }
    return value;
  }
}

class AudioPlayerException implements Exception {
  const AudioPlayerException(this.message);

  final String message;
}
