import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:record/record.dart' hide IosAudioCategory;

class VoiceChatService {
  static const int sampleRate = 16000;
  static const int channels = 1;

  final AudioRecorder _recorder = AudioRecorder();

  StreamSubscription<Uint8List>? _recordSubscription;
  Future<void> _playbackChain = Future<void>.value();
  bool _playerReady = false;
  bool _started = false;
  bool _disposed = false;

  Future<bool> start({
    required void Function(Uint8List chunk) onLocalAudioChunk,
    required void Function(Object error, StackTrace stackTrace) onCaptureError,
  }) async {
    if (_disposed) {
      return false;
    }
    if (_started) {
      return true;
    }

    try {
      await _setupPlayerIfNeeded();

      final hasPermission = await _recorder.hasPermission(request: true);
      if (!hasPermission) {
        return false;
      }

      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: channels,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
          streamBufferSize: 2048,
        ),
      );

      _started = true;

      _recordSubscription = stream.listen(
        (chunk) {
          if (!_started || chunk.lengthInBytes < 2) {
            return;
          }

          final safeChunk = _normalizePcm16Chunk(chunk);
          if (safeChunk == null) {
            return;
          }

          onLocalAudioChunk(safeChunk);
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!_started) {
            return;
          }
          onCaptureError(error, stackTrace);
        },
      );

      return true;
    } catch (error, stackTrace) {
      onCaptureError(error, stackTrace);
      await stop();
      return false;
    }
  }

  Future<void> stop() async {
    if (_disposed && !_started) {
      return;
    }

    _started = false;

    await _recordSubscription?.cancel();
    _recordSubscription = null;

    try {
      await _recorder.stop();
    } catch (_) {
      // Ignore stop errors when recorder is already stopped.
    }
  }

  void handleRemoteAudioChunk(Uint8List chunk) {
    if (!_started || !_playerReady || _disposed || chunk.lengthInBytes < 2) {
      return;
    }

    final safeChunk = _normalizePcm16Chunk(chunk);
    if (safeChunk == null) {
      return;
    }

    final chunkCopy = Uint8List.fromList(safeChunk);
    _playbackChain = _playbackChain
        .then((_) async {
          if (!_started || !_playerReady || _disposed) {
            return;
          }

          await FlutterPcmSound.feed(
            PcmArrayInt16(bytes: ByteData.sublistView(chunkCopy)),
          );
        })
        .catchError((_) {
          // Ignore playback errors to keep the voice channel resilient.
        });
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;

    await stop();

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
