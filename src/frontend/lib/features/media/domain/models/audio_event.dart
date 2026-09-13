import 'package:carnine_frontend/lib/carnine.pb.dart';

enum AudioEventKind {
  ready,
  sourceStarted,
  sourcePauseRequested,
  sourceResumeRequested,
  sourceStopRequested,
  decoderStopped,
  sourceRemoved,
  deviceChanged,
  error,
  unknown,
}

AudioEventKind audioEventKindFrom(AudioEventType raw) {
  return switch (raw) {
    AudioEventType.AUDIO_READY => AudioEventKind.ready,
    AudioEventType.AUDIO_SOURCE_STARTED => AudioEventKind.sourceStarted,
    AudioEventType.AUDIO_SOURCE_PAUSE_REQUESTED =>
      AudioEventKind.sourcePauseRequested,
    AudioEventType.AUDIO_SOURCE_RESUME_REQUESTED =>
      AudioEventKind.sourceResumeRequested,
    AudioEventType.AUDIO_SOURCE_STOP_REQUESTED =>
      AudioEventKind.sourceStopRequested,
    AudioEventType.AUDIO_DECODER_STOPPED => AudioEventKind.decoderStopped,
    AudioEventType.AUDIO_SOURCE_REMOVED => AudioEventKind.sourceRemoved,
    AudioEventType.AUDIO_DEVICE_CHANGED => AudioEventKind.deviceChanged,
    AudioEventType.AUDIO_ERROR => AudioEventKind.error,
    _ => AudioEventKind.unknown,
  };
}

class AudioEvent {
  const AudioEvent({required this.kind, required this.message});

  final AudioEventKind kind;
  final String message;
}
