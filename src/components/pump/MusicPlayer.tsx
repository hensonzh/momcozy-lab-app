import React, { useState, useEffect, useRef, useCallback, useMemo } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Play, Pause, SkipForward } from "lucide-react";
import { cn } from "@/lib/utils";
import { resolvePumpTrackUrl } from "@/assets/music/pump/tracks";

interface Props {
  isLetdown: boolean;
  isLowFlow: boolean;
  running: boolean;
}

const PLAYLISTS = [
  { id: "letdown", name: "💧 奶阵喷射", tracks: ["奶阵节拍", "喷射律动", "泌乳脉冲"] },
  { id: "nature", name: "🌿 自然白噪音", tracks: ["雨声", "海浪", "森林鸟鸣"] },
  { id: "lullaby", name: "🍼 宝宝摇篮曲", tracks: ["Twinkle Star", "小星星", "摇篮曲"] },
];

const BAR_COUNT = 24;

function getAudioContextCtor(): typeof AudioContext | null {
  if (typeof window === "undefined") return null;
  return window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext ?? null;
}

async function resumeAudioContextIfNeeded(ctx: AudioContext | null) {
  if (ctx && ctx.state === "suspended") await ctx.resume().catch(() => {});
}

const MusicPlayer: React.FC<Props> = ({ isLetdown, isLowFlow, running }) => {
  const [isPlaying, setIsPlaying] = useState(false);
  const [showPlaylists, setShowPlaylists] = useState(false);
  const [playlistIdx, setPlaylistIdx] = useState(0);
  const [trackIdx, setTrackIdx] = useState(0);
  const [bars, setBars] = useState<number[]>(() => Array(BAR_COUNT).fill(0.1));
  const spectrumRafRef = useRef(0);
  const spectrumDataRef = useRef<Uint8Array | null>(null);
  const prevBarsRef = useRef<number[]>(Array(BAR_COUNT).fill(0.1));
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const audioContextRef = useRef<AudioContext | null>(null);
  const analyserRef = useRef<AnalyserNode | null>(null);
  const isPlayingRef = useRef(false);

  const playlist = PLAYLISTS[playlistIdx];
  const track = playlist.tracks[trackIdx];
  const trackUrl = useMemo(
    () => resolvePumpTrackUrl(playlist.id, trackIdx),
    [playlist.id, trackIdx]
  );

  isPlayingRef.current = isPlaying;

  useEffect(() => {
    const a = new Audio();
    a.preload = "auto";
    a.loop = true;
    audioRef.current = a;

    const Ctor = getAudioContextCtor();
    if (Ctor) {
      const ctx = new Ctor();
      const source = ctx.createMediaElementSource(a);
      const analyser = ctx.createAnalyser();
      analyser.fftSize = 256;
      analyser.smoothingTimeConstant = 0.62;
      analyser.minDecibels = -85;
      analyser.maxDecibels = -10;
      source.connect(analyser);
      analyser.connect(ctx.destination);
      audioContextRef.current = ctx;
      analyserRef.current = analyser;
    }

    return () => {
      cancelAnimationFrame(spectrumRafRef.current);
      spectrumRafRef.current = 0;
      const ctx = audioContextRef.current;
      audioContextRef.current = null;
      analyserRef.current = null;
      void ctx?.close();
      a.pause();
      a.src = "";
      audioRef.current = null;
    };
  }, []);

  useEffect(() => {
    if (!running) {
      audioRef.current?.pause();
      setIsPlaying(false);
    }
  }, [running]);

  useEffect(() => {
    const a = audioRef.current;
    if (!a || !trackUrl) return;
    a.pause();
    a.src = trackUrl;
    a.load();
    if (isPlayingRef.current) {
      void resumeAudioContextIfNeeded(audioContextRef.current).then(() => {
        void a.play().catch(() => setIsPlaying(false));
      });
    }
  }, [trackUrl]);

  const togglePlay = useCallback(() => {
    if (!trackUrl) return;
    const a = audioRef.current;
    if (!a) return;
    if (isPlaying) {
      a.pause();
      setIsPlaying(false);
    } else {
      void resumeAudioContextIfNeeded(audioContextRef.current).then(() => {
        void a.play()
          .then(() => setIsPlaying(true))
          .catch(() => setIsPlaying(false));
      });
    }
  }, [isPlaying, trackUrl]);

  /** 频谱驱动柱状条（Web Audio Analyser） */
  useEffect(() => {
    if (!isPlaying) {
      cancelAnimationFrame(spectrumRafRef.current);
      spectrumRafRef.current = 0;
      prevBarsRef.current = Array(BAR_COUNT).fill(0.05);
      setBars(Array(BAR_COUNT).fill(0.05));
      return;
    }

    const tick = () => {
      const analyser = analyserRef.current;
      if (!analyser || !isPlayingRef.current) return;
      const binCount = analyser.frequencyBinCount;
      let data = spectrumDataRef.current;
      if (!data || data.length !== binCount) {
        data = new Uint8Array(binCount);
        spectrumDataRef.current = data;
      }
      analyser.getByteFrequencyData(data as Uint8Array<ArrayBuffer>);
      const n = data.length;
      if (n === 0) {
        spectrumRafRef.current = requestAnimationFrame(tick);
        return;
      }

      const newBars = Array.from({ length: BAR_COUNT }, (_, i) => {
        const t0 = Math.pow(i / BAR_COUNT, 1.2);
        const t1 = Math.pow((i + 1) / BAR_COUNT, 1.2);
        const start = Math.min(n - 1, Math.floor(t0 * n));
        const end = Math.max(start + 1, Math.min(n, Math.floor(t1 * n)));
        let peak = 0;
        for (let j = start; j < end; j++) peak = Math.max(peak, data[j]!);
        const normalized = peak / 255;
        const prev = prevBarsRef.current[i] ?? 0.08;
        const target = Math.min(1, Math.max(0.04, normalized * 1.2));
        return prev + (target - prev) * 0.42;
      });
      prevBarsRef.current = newBars;
      setBars(newBars);
      spectrumRafRef.current = requestAnimationFrame(tick);
    };

    spectrumRafRef.current = requestAnimationFrame(tick);
    return () => {
      cancelAnimationFrame(spectrumRafRef.current);
      spectrumRafRef.current = 0;
    };
  }, [isPlaying]);

  const nextTrack = useCallback(() => {
    setTrackIdx(p => (p + 1) % playlist.tracks.length);
  }, [playlist.tracks.length]);

  const selectPlaylist = useCallback((idx: number) => {
    setPlaylistIdx(idx);
    setTrackIdx(0);
    setIsPlaying(true);
    setShowPlaylists(false);
  }, []);

  const barColor = isLetdown
    ? "from-orange-400 to-orange-600"
    : isLowFlow
      ? "from-primary/40 to-primary/60"
      : "from-primary/60 to-primary";

  const modeLabel = isLetdown ? "🌊 奶阵" : isLowFlow ? "😌 舒缓" : "🎵 标准";

  return (
    <div className="bg-card/40 backdrop-blur-lg rounded-xl border border-border/20">
      <div className="flex items-center gap-1.5 px-2 py-1.5">
        {/* Play/pause */}
        <motion.button
          type="button"
          whileTap={{ scale: 0.85 }}
          onClick={togglePlay}
          disabled={!trackUrl}
          title={!trackUrl ? "请将 mp3 放入 src/assets/music/pump/（命名：歌单id-序号.mp3）" : undefined}
          className={cn(
            "w-6 h-6 rounded-full flex items-center justify-center flex-shrink-0 transition-colors",
            isPlaying ? "bg-primary text-primary-foreground" : "bg-muted/60 text-foreground",
            !trackUrl && "opacity-40"
          )}
        >
          {isPlaying ? <Pause className="w-3 h-3" /> : <Play className="w-3 h-3 ml-0.5" />}
        </motion.button>

        {/* Center area: waveform OR playlist pills */}
        <div className="flex-1 min-w-0">
          <AnimatePresence mode="wait">
            {showPlaylists ? (
              <motion.div
                key="playlists"
                initial={{ opacity: 0, x: 10 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: -10 }}
                transition={{ duration: 0.15 }}
                className="flex items-center gap-1 overflow-x-auto no-scrollbar"
              >
                {PLAYLISTS.map((pl, idx) => (
                  <motion.button
                    key={pl.id}
                    whileTap={{ scale: 0.93 }}
                    onClick={() => selectPlaylist(idx)}
                    className={cn(
                      "flex-shrink-0 px-2 py-0.5 rounded-full text-[8px] font-bold transition-all whitespace-nowrap",
                      playlistIdx === idx
                        ? "bg-primary/15 text-primary border border-primary/25"
                        : "bg-muted/30 text-muted-foreground hover:bg-muted/50"
                    )}
                  >
                    {pl.name}
                  </motion.button>
                ))}
              </motion.div>
            ) : (
              <motion.div
                key="waveform"
                initial={{ opacity: 0, x: -10 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: 10 }}
                transition={{ duration: 0.15 }}
                className="flex items-center gap-[2px] h-[18px] px-0.5"
              >
                {bars.map((h, i) => (
                  <motion.div
                    key={i}
                    className={cn("w-[2.5px] rounded-full bg-gradient-to-t", barColor)}
                    style={{ height: `${Math.max(2, h * 18)}px` }}
                    transition={{ duration: 0.05 }}
                  />
                ))}
              </motion.div>
            )}
          </AnimatePresence>
        </div>

        {/* Right controls */}
        <div className="flex items-center gap-1 flex-shrink-0">
          {/* Mode badge (only when playing & not selecting) */}
          {isPlaying && !showPlaylists && (
            <span className={cn(
              "text-[7px] font-bold px-1.5 py-0.5 rounded-full whitespace-nowrap",
              isLetdown ? "bg-orange-100/60 text-orange-600" : isLowFlow ? "bg-primary/10 text-primary/70" : "bg-muted/40 text-muted-foreground"
            )}>
              {modeLabel}
            </span>
          )}

          {/* Track name - tap to switch playlist */}
          <motion.button
            whileTap={{ scale: 0.9 }}
            onClick={() => setShowPlaylists(p => !p)}
            className="text-right max-w-[56px] px-1 py-0.5 rounded-lg hover:bg-muted/30 transition-colors"
          >
            <p className="text-[8px] font-bold text-foreground truncate">{track}</p>
            <p className="text-[6px] text-muted-foreground truncate">{playlist.name}</p>
          </motion.button>

          <motion.button whileTap={{ scale: 0.85 }} onClick={nextTrack}
            className="w-5 h-5 rounded-full bg-muted/40 flex items-center justify-center">
            <SkipForward className="w-2.5 h-2.5 text-muted-foreground" />
          </motion.button>
        </div>
      </div>
    </div>
  );
};

export default React.memo(MusicPlayer);
