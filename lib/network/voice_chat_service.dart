import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:record/record.dart' hide IosAudioCategory;

class VoiceChatService {
  static const int sampleRate = 16000;
  static const int channels = 1;

  static const int _targetChunkBytes = 640; // 20 ms in PCM16 mono 16 kHz.
  static const double _noiseGateRms = 820;
  static const int _duplexSuppressWindowMs = 220;
  static const double _playbackGain = 0.58;

  final AudioRecorder _recorder = AudioRecorder();

  StreamSubscription<Uint8List>? _recordSubscription;
  Future<void> _playbackChain = Future<void>.value();

  bool _playerReady = false;
  bool _captureEnabled = false;
  bool _playbackEnabled = false;
  bool _disposed = false;
  DateTime? _lastRemotePlaybackAt;

  Future<bool> setPlaybackEnabled(bool enabled) async {
    if (_disposed) {
      return false;
    }

    if (enabled == _playbackEnabled) {
      return true;
    }

    if (enabled) {
      try {
        await _setupPlayerIfNeeded();
        _playbackEnabled = true;
        return true;
      } catch (_) {
        _playbackEnabled = false;
        return false;
      }
    }

    _playbackEnabled = false;
    _playbackChain = Future<void>.value();
    _lastRemotePlaybackAt = null;
    return true;
  }

  Future<bool> startCapture({
    required void Function(Uint8List chunk) onLocalAudioChunk,
    required void Function(Object error, StackTrace stackTrace) onCaptureError,
  }) async {
    if (_disposed) {
      return false;
    }
    if (_captureEnabled) {
      return true;
    }

    try {
      final hasPermission = await _recorder.hasPermission(request: true);
      if (!hasPermission) {
        return false;
      }

      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: channels,
          autoGain: false,
          echoCancel: true,
          noiseSuppress: true,
          streamBufferSize: _targetChunkBytes,
        ),
      );

      _captureEnabled = true;

      _recordSubscription = stream.listen(
        (chunk) {
          if (!_captureEnabled) {
            return;
          }
          _emitOutgoingChunks(chunk, onLocalAudioChunk);
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!_captureEnabled) {
            return;
          }
          onCaptureError(error, stackTrace);
        },
      );

      return true;
    } catch (error, stackTrace) {
      onCaptureError(error, stackTrace);
      await stopCapture();
      return false;
    }
  }

  Future<void> stopCapture() async {
    if (_disposed && !_captureEnabled) {
      return;
    }

    _captureEnabled = false;

    await _recordSubscription?.cancel();
    _recordSubscription = null;

    try {
      await _recorder.stop();
    } catch (_) {
      // Ignore stop errors when capture is already stopped.
    }
  }

  void handleRemoteAudioChunk(Uint8List chunk) {
    if (!_playbackEnabled ||
        !_playerReady ||
        _disposed ||
        chunk.lengthInBytes < 2) {
      return;
    }

    final safeChunk = _normalizePcm16Chunk(chunk);
    if (safeChunk == null) {
      return;
    }

    final chunkCopy = Uint8List.fromList(safeChunk);
    _attenuatePcm16(chunkCopy, gain: _playbackGain);

    _playbackChain = _playbackChain
        .then((_) async {
          if (!_playbackEnabled || !_playerReady || _disposed) {
            return;
          }
          _lastRemotePlaybackAt = DateTime.now();
          await FlutterPcmSound.feed(
            PcmArrayInt16(bytes: ByteData.sublistView(chunkCopy)),
          );
        })
        .catchError((_) {
          // Ignore playback errors to keep voice stream resilient.
        });
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;

    await stopCapture();

    try {
      await _recorder.dispose();
    } catch (_) {
      // Ignore recorder dispose errors.
    }

    if (_playerReady) {
      try {
        await FlutterPcmSound.release();
      } catch (_) {
        // Ignore release errors.
      }
      _playerReady = false;
    }
  }

  Future<void> _setupPlayerIfNeeded() async {
    if (_playerReady || _disposed) {
      return;
    }

    await FlutterPcmSound.setLogLevel(LogLevel.none);
    await FlutterPcmSound.setup(
      sampleRate: sampleRate,
      channelCount: channels,
      iosAudioCategory: IosAudioCategory.playAndRecord,
    );
    _playerReady = true;
  }

  void _emitOutgoingChunks(
    Uint8List rawChunk,
    void Function(Uint8List chunk) onLocalAudioChunk,
  ) {
    final safeRaw = _normalizePcm16Chunk(rawChunk);
    if (safeRaw == null) {
      return;
    }

    var offset = 0;
    while (offset < safeRaw.lengthInBytes) {
      final end = math.min(offset + _targetChunkBytes, safeRaw.lengthInBytes);
      final piece = Uint8List.sublistView(safeRaw, offset, end);
      final processed = _preprocessOutgoingChunk(piece);
      if (processed != null) {
        onLocalAudioChunk(processed);
      }
      offset = end;
    }
  }

  Uint8List? _preprocessOutgoingChunk(Uint8List chunk) {
    final safeChunk = _normalizePcm16Chunk(chunk);
    if (safeChunk == null) {
      return null;
    }

    final rms = _computeRms(safeChunk);
    if (rms < _noiseGateRms) {
      return null;
    }

    final lastRemotePlaybackAt = _lastRemotePlaybackAt;
    if (lastRemotePlaybackAt != null) {
      final deltaMs = DateTime.now()
          .difference(lastRemotePlaybackAt)
          .inMilliseconds;
      // Strong duplex suppression: while remote voice is very recent, do not
      // retransmit local audio to break acoustic feedback loops (larsen).
      if (deltaMs >= 0 && deltaMs <= _duplexSuppressWindowMs) {
        return null;
      }
    }

    return Uint8List.fromList(safeChunk);
  }

  double _computeRms(Uint8List pcm16Chunk) {
    final sampleCount = pcm16Chunk.lengthInBytes ~/ 2;
    if (sampleCount == 0) {
      return 0;
    }

    final data = ByteData.sublistView(pcm16Chunk);
    var sumSquares = 0.0;
    for (var i = 0; i < sampleCount; i++) {
      final sample = data.getInt16(i * 2, Endian.little).toDouble();
      sumSquares += sample * sample;
    }

    return math.sqrt(sumSquares / sampleCount);
  }

  void _attenuatePcm16(Uint8List pcm16Chunk, {required double gain}) {
    if (gain >= 0.999) {
      return;
    }

    final data = ByteData.sublistView(pcm16Chunk);
    final sampleCount = pcm16Chunk.lengthInBytes ~/ 2;
    for (var i = 0; i < sampleCount; i++) {
      final sample = data.getInt16(i * 2, Endian.little);
      var scaled = (sample * gain).round();
      if (scaled > 32767) {
        scaled = 32767;
      } else if (scaled < -32768) {
        scaled = -32768;
      }
      data.setInt16(i * 2, scaled, Endian.little);
    }
  }

  Uint8List? _normalizePcm16Chunk(Uint8List chunk) {
    if (chunk.lengthInBytes < 2) {
      return null;
    }
    if (chunk.lengthInBytes.isEven) {
      return chunk;
    }
    return Uint8List.sublistView(chunk, 0, chunk.lengthInBytes - 1);
  }
}
