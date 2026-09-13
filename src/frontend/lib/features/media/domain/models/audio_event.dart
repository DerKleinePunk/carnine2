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

AudioEventKind audioEventKindFrom(String raw) {
  return switch (raw.trim()) {
    'audio_ready' => AudioEventKind.ready,
    'source_started' => AudioEventKind.sourceStarted,
    'source_pause_requested' => AudioEventKind.sourcePauseRequested,
    'source_resume_requested' => AudioEventKind.sourceResumeRequested,
    'source_stop_requested' => AudioEventKind.sourceStopRequested,
    'decoder_stopped' => AudioEventKind.decoderStopped,
    'source_removed' => AudioEventKind.sourceRemoved,
    'device_changed' => AudioEventKind.deviceChanged,
    'error' => AudioEventKind.error,
    _ => AudioEventKind.unknown,
  };
}

class AudioEvent {
  const AudioEvent({required this.kind, required this.message});

  final AudioEventKind kind;
  final String message;
}
