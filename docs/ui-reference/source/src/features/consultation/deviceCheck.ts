/** The minimum media-track shape needed by the pre-consultation gate. */
export interface ConsultationMediaTrackLike {
  readyState: string
}

export interface ConsultationMediaStreamLike {
  getVideoTracks(): readonly ConsultationMediaTrackLike[]
  getAudioTracks(): readonly ConsultationMediaTrackLike[]
}

/**
 * A consultation may proceed only when at least one live camera track and one
 * live microphone track are available. A stream with only one of the two is
 * not enough to enter the room.
 */
export function consultationDevicesReady(stream: ConsultationMediaStreamLike): boolean {
  return stream.getVideoTracks().some((track) => track.readyState === 'live')
    && stream.getAudioTracks().some((track) => track.readyState === 'live')
}
