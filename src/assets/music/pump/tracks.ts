/**
 * 约定：`src/assets/music/pump/{playlistId}-{trackIndex}.mp3`
 * 例如 letdown-0.mp3、nature-2.mp3（与 MusicPlayer 中 PLAYLISTS[].id 一致）
 */
const pumpTrackUrlGlob = import.meta.glob<string>("./*.mp3", {
  eager: true,
  query: "?url",
  import: "default",
});

export function resolvePumpTrackUrl(playlistId: string, trackIndex: number): string | undefined {
  const key = `./${playlistId}-${trackIndex}.mp3`;
  return pumpTrackUrlGlob[key];
}
