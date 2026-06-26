use rodio::buffer::SamplesBuffer;
use rodio::{Decoder, OutputStream, OutputStreamHandle, Sink, Source};
use rustfft::num_complex::Complex;
use rustfft::FftPlanner;
use std::f32::consts::PI;
use std::fs::File;
use std::io::{self, BufRead, BufReader, Write};
use std::time::{Duration, Instant};

const SAMPLE_RATE: u32 = 44100;

const SCALE: [f32; 10] = [
    523.25, 587.33, 659.25, 783.99, 880.00, 1046.50, 1174.66, 1318.51, 1567.98, 1760.00,
];

struct Blip {
    freq: f32,
    pos: u32,
    len: u32,
    amp: f32,
}

impl Blip {
    fn new(freq: f32, secs: f32, amp: f32) -> Self {
        Blip {
            freq,
            pos: 0,
            len: (SAMPLE_RATE as f32 * secs) as u32,
            amp,
        }
    }
}

impl Iterator for Blip {
    type Item = f32;
    fn next(&mut self) -> Option<f32> {
        if self.pos >= self.len {
            return None;
        }
        let t = self.pos as f32 / SAMPLE_RATE as f32;
        let frac = self.pos as f32 / self.len as f32;
        let env = (1.0 - frac).powi(3);
        let v = (2.0 * PI * self.freq * t).sin() * env * self.amp;
        self.pos += 1;
        Some(v)
    }
}

impl Source for Blip {
    fn current_frame_len(&self) -> Option<usize> {
        Some((self.len - self.pos) as usize)
    }
    fn channels(&self) -> u16 {
        1
    }
    fn sample_rate(&self) -> u32 {
        SAMPLE_RATE
    }
    fn total_duration(&self) -> Option<Duration> {
        Some(Duration::from_secs_f32(self.len as f32 / SAMPLE_RATE as f32))
    }
}

struct Mallet {
    freq: f32,
    pos: u32,
    len: u32,
    amp: f32,
}

impl Mallet {
    fn new(freq: f32, secs: f32, amp: f32) -> Self {
        Mallet {
            freq,
            pos: 0,
            len: (SAMPLE_RATE as f32 * secs) as u32,
            amp,
        }
    }
}

impl Iterator for Mallet {
    type Item = f32;
    fn next(&mut self) -> Option<f32> {
        if self.pos >= self.len {
            return None;
        }
        let t = self.pos as f32 / SAMPLE_RATE as f32;
        let frac = self.pos as f32 / self.len as f32;
        let attack = (self.pos as f32 / (SAMPLE_RATE as f32 * 0.004)).min(1.0);
        let decay = (1.0 - frac).powi(2);
        let env = attack * decay;
        let w = 2.0 * PI * self.freq * t;
        let tone = w.sin() + 0.35 * (2.0 * w).sin() + 0.12 * (3.0 * w).sin();
        let v = tone * env * self.amp * 0.5;
        self.pos += 1;
        Some(v)
    }
}

impl Source for Mallet {
    fn current_frame_len(&self) -> Option<usize> {
        Some((self.len - self.pos) as usize)
    }
    fn channels(&self) -> u16 {
        1
    }
    fn sample_rate(&self) -> u32 {
        SAMPLE_RATE
    }
    fn total_duration(&self) -> Option<Duration> {
        Some(Duration::from_secs_f32(self.len as f32 / SAMPLE_RATE as f32))
    }
}

fn play_blip(handle: &Option<OutputStreamHandle>, freq: f32, secs: f32, amp: f32) {
    if let Some(h) = handle {
        let _ = h.play_raw(Blip::new(freq, secs, amp));
    }
}

fn play_mallet(handle: &Option<OutputStreamHandle>, freq: f32, secs: f32, amp: f32) {
    if let Some(h) = handle {
        let _ = h.play_raw(Mallet::new(freq, secs, amp));
    }
}

fn detect_onsets(samples: &[i16], channels: u16, sr: u32) -> Vec<f64> {
    let ch = channels.max(1) as usize;
    let n = samples.len() / ch;
    let win = 1024usize;
    let hop = 512usize;
    if n < win {
        return Vec::new();
    }
    let mut mono = vec![0f32; n];
    for i in 0..n {
        let mut s = 0f32;
        for c in 0..ch {
            s += samples[i * ch + c] as f32;
        }
        mono[i] = s / (ch as f32 * 32768.0);
    }
    let hann: Vec<f32> = (0..win)
        .map(|i| 0.5 - 0.5 * (2.0 * PI * i as f32 / (win as f32 - 1.0)).cos())
        .collect();
    let mut planner = FftPlanner::<f32>::new();
    let fft = planner.plan_fft_forward(win);
    let frames = (n - win) / hop + 1;
    let half = win / 2;
    let mut prev = vec![0f32; half];
    let mut flux = Vec::with_capacity(frames);
    let mut buf: Vec<Complex<f32>> = vec![Complex { re: 0.0, im: 0.0 }; win];
    for f in 0..frames {
        let start = f * hop;
        for i in 0..win {
            buf[i].re = mono[start + i] * hann[i];
            buf[i].im = 0.0;
        }
        fft.process(&mut buf);
        let mut sf = 0f32;
        for k in 0..half {
            let mag = (buf[k].re * buf[k].re + buf[k].im * buf[k].im).sqrt();
            let diff = mag - prev[k];
            if diff > 0.0 {
                sf += diff;
            }
            prev[k] = mag;
        }
        flux.push(sf);
    }
    let w = 8usize;
    let mut onsets = Vec::new();
    let mut last = -100i64;
    for i in 0..flux.len() {
        let lo = i.saturating_sub(w);
        let hi = (i + w + 1).min(flux.len());
        let mut mean = 0f32;
        for j in lo..hi {
            mean += flux[j];
        }
        mean /= (hi - lo) as f32;
        let thresh = mean * 1.5 + 1e-6;
        let peak = flux[i] > thresh
            && (i == 0 || flux[i] >= flux[i - 1])
            && (i + 1 >= flux.len() || flux[i] >= flux[i + 1]);
        if peak && (i as i64 - last) > 5 {
            onsets.push((i * hop) as f64 / sr as f64);
            last = i as i64;
        }
    }
    let min_gap = 0.28;
    let mut thinned = Vec::new();
    let mut last_t = -1.0f64;
    for &t in &onsets {
        if t - last_t >= min_gap {
            thinned.push(t);
            last_t = t;
        }
    }
    thinned
}

fn estimate_bpm(onsets: &[f64]) -> f64 {
    if onsets.len() < 4 {
        return 0.0;
    }
    let mut iois: Vec<f64> = onsets
        .windows(2)
        .map(|w| w[1] - w[0])
        .filter(|x| *x > 0.05 && *x < 2.0)
        .collect();
    if iois.is_empty() {
        return 0.0;
    }
    iois.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let med = iois[iois.len() / 2];
    let mut bpm = 60.0 / med;
    while bpm < 70.0 {
        bpm *= 2.0;
    }
    while bpm > 180.0 {
        bpm /= 2.0;
    }
    (bpm * 10.0).round() / 10.0
}

fn compute_bands(samples: &[i16], channels: u16, sr: u32) -> Vec<Vec<f32>> {
    let ch = channels.max(1) as usize;
    let n = samples.len() / ch;
    let win = 2048usize;
    let hop = (sr as f64 * 0.1) as usize;
    if n < win || hop == 0 {
        return Vec::new();
    }
    let mut mono = vec![0f32; n];
    for i in 0..n {
        let mut s = 0f32;
        for c in 0..ch {
            s += samples[i * ch + c] as f32;
        }
        mono[i] = s / (ch as f32 * 32768.0);
    }
    let hann: Vec<f32> = (0..win)
        .map(|i| 0.5 - 0.5 * (2.0 * PI * i as f32 / (win as f32 - 1.0)).cos())
        .collect();
    let diatonic: [i32; 7] = [0, 2, 4, 5, 7, 9, 11];
    let bin_hz = sr as f64 / win as f64;
    let half = win / 2;
    let mut planner = FftPlanner::<f32>::new();
    let fft = planner.plan_fft_forward(win);
    let frames = (n - win) / hop + 1;
    let mut result = Vec::with_capacity(frames);
    let mut buf: Vec<Complex<f32>> = vec![Complex { re: 0.0, im: 0.0 }; win];
    for f in 0..frames {
        let start = f * hop;
        for i in 0..win {
            buf[i].re = mono[start + i] * hann[i];
            buf[i].im = 0.0;
        }
        fft.process(&mut buf);
        let mut e = [0f32; 7];
        for k in 0..half {
            let hz = k as f64 * bin_hz;
            if hz < 20.0 {
                continue;
            }
            let midi = 69.0 + 12.0 * (hz / 440.0).log2();
            let pc = midi.round() as i32 % 12;
            let pc = if pc < 0 { pc + 12 } else { pc };
            let mag = (buf[k].re * buf[k].re + buf[k].im * buf[k].im).sqrt();
            for b in 0..7 {
                if pc == diatonic[b] {
                    e[b] += mag;
                } else if (pc + 12 - diatonic[b]) % 12 == 1 {
                    e[b] += mag * 0.3;
                }
            }
        }
        let mx = e.iter().fold(0.0f32, |a, &v| a.max(v));
        if mx > 0.0 {
            for i in 0..7 {
                e[i] /= mx;
            }
        }
        result.push(e.to_vec());
    }
    result
}

fn write_sidecar(path: &str, track_secs: f64, bpm: f64, onsets: &[f64], bands: &[Vec<f32>]) {
    let list: Vec<String> = onsets.iter().map(|o| format!("{:.3}", o)).collect();
    let bands_str: Vec<String> = bands
        .iter()
        .map(|b| {
            let inner: Vec<String> = b.iter().map(|x| format!("{:.3}", x)).collect();
            format!("[{}]", inner.join(","))
        })
        .collect();
    let json = format!(
        "{{\"track_secs\":{:.3},\"bpm\":{:.1},\"onsets\":[{}],\"bands\":[{}]}}",
        track_secs,
        bpm,
        list.join(","),
        bands_str.join(",")
    );
    let _ = std::fs::write(format!("{path}.beats.json"), json);
}

fn parse_after(s: &str, key: &str) -> Option<f64> {
    let i = s.find(key)? + key.len();
    let rest = &s[i..];
    let endi = rest.find(|c: char| c == ',' || c == '}' || c == ']').unwrap_or(rest.len());
    rest[..endi].trim().parse::<f64>().ok()
}

fn read_sidecar(path: &str) -> Option<(f64, Vec<f64>)> {
    let s = std::fs::read_to_string(format!("{path}.beats.json")).ok()?;
    let ts = parse_after(&s, "\"track_secs\":")?;
    let start = s.find("\"onsets\":[")? + "\"onsets\":[".len();
    let end = s[start..].find(']')? + start;
    let onsets: Vec<f64> = s[start..end]
        .split(',')
        .filter_map(|x| x.trim().parse::<f64>().ok())
        .collect();
    Some((ts, onsets))
}

fn analyze_file(path: &str) {
    match File::open(path) {
        Ok(f) => match Decoder::new(BufReader::new(f)) {
            Ok(dec) => {
                let ch = dec.channels();
                let sr = dec.sample_rate();
                let samples: Vec<i16> = dec.collect();
                let ons = detect_onsets(&samples, ch, sr);
                let secs = samples.len() as f64 / ch.max(1) as f64 / sr as f64;
                let bpm = estimate_bpm(&ons);
                let bands = compute_bands(&samples, ch, sr);
                write_sidecar(path, secs, bpm, &ons, &bands);
                eprintln!(
                    "musicode-daemon: analyzed {} onsets, {:.1}s, ~{} bpm: {}",
                    ons.len(),
                    secs,
                    bpm,
                    path
                );
            }
            Err(e) => eprintln!("musicode-daemon: decode failed: {e}"),
        },
        Err(e) => eprintln!("musicode-daemon: cannot open '{path}': {e}"),
    }
}

fn nearest_onset(onsets: &[f64], pos: f64, track: f64) -> (f64, usize) {
    if onsets.is_empty() {
        return (f64::INFINITY, 0);
    }
    let mut lo = 0usize;
    let mut hi = onsets.len();
    while lo < hi {
        let mid = (lo + hi) / 2;
        if onsets[mid] < pos {
            lo = mid + 1;
        } else {
            hi = mid;
        }
    }
    let mut best = f64::INFINITY;
    let mut bi = 0;
    for &cand in &[lo.saturating_sub(1), lo.min(onsets.len() - 1)] {
        let d = (onsets[cand] - pos).abs();
        if d < best {
            best = d;
            bi = cand;
        }
    }
    if track > 0.0 {
        let last = onsets.len() - 1;
        let dw1 = (onsets[0] + track - pos).abs();
        if dw1 < best {
            best = dw1;
            bi = 0;
        }
        let dw2 = (pos + track - onsets[last]).abs();
        if dw2 < best {
            best = dw2;
            bi = last;
        }
    }
    (best, bi)
}

fn grid_hit(handle: &Option<OutputStreamHandle>, period_ms: f64, subdivisions: i64, t0: Instant) {
    if period_ms <= 0.0 || subdivisions <= 0 {
        play_mallet(handle, SCALE[0], 0.22, 0.16);
        return;
    }
    let elapsed = t0.elapsed().as_secs_f64() * 1000.0;
    let idx = (elapsed / period_ms).round() as i64;
    let d = (elapsed - idx as f64 * period_ms).abs();
    let window = (period_ms / 2.0) * 0.45;
    if d > window {
        return;
    }
    let close = (1.0 - d / window).clamp(0.0, 1.0) as f32;
    let len = SCALE.len() as i64;
    let degree = ((idx % len) + len) % len;
    let note = SCALE[degree as usize];
    let amp = 0.10 * (0.6 + 0.4 * close);
    play_mallet(handle, note, 0.26, amp);
}

fn main() {
    let _stream: Option<OutputStream>;
    let handle: Option<OutputStreamHandle>;

    match OutputStream::try_default() {
        Ok((s, h)) => {
            _stream = Some(s);
            handle = Some(h);
        }
        Err(e) => {
            eprintln!("musicode-daemon: audio init failed: {e}; running silent");
            _stream = None;
            handle = None;
        }
    }

    let mut music: Option<Sink> = None;
    let mut music_vol: f32 = 0.7;
    let mut onsets: Vec<f64> = Vec::new();
    let mut track_secs: f64 = 0.0;
    let mut play_pos_ms: f64 = 0.0;
    let mut play_resume: Option<Instant> = None;
    let mut last_onset_idx: i64 = -1;

    let mut beat_period_ms: f64 = 0.0;
    let mut subdivisions: i64 = 4;
    let mut beat_t0 = Instant::now();

    let mut out = io::stdout();
    let _ = writeln!(out, "ready");
    let _ = out.flush();

    let stdin = io::stdin();
    for line in stdin.lock().lines() {
        let line = match line {
            Ok(l) => l,
            Err(_) => break,
        };
        let trimmed = line.trim();
        let mut parts = trimmed.splitn(2, ' ');
        let cmd = parts.next().unwrap_or("");
        let arg = parts.next().unwrap_or("");
        match cmd {
            "quit" => break,
            "hit" => {
                if !onsets.is_empty() && track_secs > 0.0 && play_resume.is_some() {
                    let pos_ms = play_pos_ms
                        + play_resume.unwrap().elapsed().as_secs_f64() * 1000.0;
                    let pos_secs = (pos_ms / 1000.0).rem_euclid(track_secs);
                    let (dist, idx) = nearest_onset(&onsets, pos_secs, track_secs);
                    if dist <= 0.055 && idx as i64 != last_onset_idx {
                        last_onset_idx = idx as i64;
                        let deg = idx % SCALE.len();
                        let close = (1.0 - dist / 0.055).clamp(0.0, 1.0) as f32;
                        let amp = 0.10 * (0.6 + 0.4 * close);
                        play_mallet(&handle, SCALE[deg], 0.18, amp);
                    }
                } else {
                    grid_hit(&handle, beat_period_ms, subdivisions, beat_t0);
                }
            }
            "perfect" => play_blip(&handle, 880.0, 0.10, 0.30),
            "good" => play_blip(&handle, 620.0, 0.10, 0.26),
            "miss" => play_blip(&handle, 160.0, 0.18, 0.26),
            "tick" => play_mallet(&handle, SCALE[9], 0.06, 0.14),
            "beat" => {
                let mut a = arg.split_whitespace();
                let bpm = a.next().and_then(|s| s.parse::<f64>().ok()).unwrap_or(0.0);
                let sub = a.next().and_then(|s| s.parse::<i64>().ok()).unwrap_or(4);
                if bpm > 0.0 && sub > 0 {
                    beat_period_ms = 60000.0 / bpm / sub as f64;
                    subdivisions = sub;
                    beat_t0 = Instant::now();
                } else {
                    beat_period_ms = 0.0;
                }
            }
            "musicvol" => {
                if let Ok(n) = arg.trim().parse::<f32>() {
                    music_vol = (n / 100.0).clamp(0.0, 1.0);
                    if let Some(s) = &music {
                        s.set_volume(music_vol);
                    }
                }
            }
            "musicstop" => {
                if let Some(s) = music.take() {
                    s.stop();
                }
                onsets.clear();
                track_secs = 0.0;
                play_pos_ms = 0.0;
                play_resume = None;
                last_onset_idx = -1;
            }
            "musicpause" => {
                if let Some(s) = &music {
                    s.pause();
                }
                if let Some(r) = play_resume.take() {
                    play_pos_ms += r.elapsed().as_secs_f64() * 1000.0;
                }
            }
            "musicresume" => {
                if let Some(s) = &music {
                    s.play();
                }
                if play_resume.is_none() {
                    play_resume = Some(Instant::now());
                }
            }
            "music" => {
                let path = arg.trim();
                if path.is_empty() {
                    continue;
                }
                if let Some(h) = &handle {
                    match File::open(path) {
                        Ok(f) => match Decoder::new(BufReader::new(f)) {
                            Ok(dec) => {
                                let channels = dec.channels();
                                let sr = dec.sample_rate();
                                let samples: Vec<i16> = dec.collect();
                                track_secs =
                                    samples.len() as f64 / channels.max(1) as f64 / sr as f64;
                                if let Some((_, cached)) = read_sidecar(path) {
                                    onsets = cached;
                                } else {
                                    onsets = detect_onsets(&samples, channels, sr);
                                    let bands = compute_bands(&samples, channels, sr);
                                    write_sidecar(path, track_secs, estimate_bpm(&onsets), &onsets, &bands);
                                }
                                eprintln!(
                                    "musicode-daemon: play {} onsets, {:.1}s",
                                    onsets.len(),
                                    track_secs
                                );
                                if let Some(s) = music.take() {
                                    s.stop();
                                }
                                match Sink::try_new(h) {
                                    Ok(sink) => {
                                        sink.set_volume(music_vol);
                                        let buf = SamplesBuffer::new(channels, sr, samples);
                                        sink.append(buf.buffered().repeat_infinite());
                                        music = Some(sink);
                                        play_pos_ms = 0.0;
                                        play_resume = Some(Instant::now());
                                        last_onset_idx = -1;
                                    }
                                    Err(e) => eprintln!("musicode-daemon: sink error: {e}"),
                                }
                            }
                            Err(e) => eprintln!("musicode-daemon: decode failed: {e}"),
                        },
                        Err(e) => eprintln!("musicode-daemon: cannot open '{path}': {e}"),
                    }
                }
            }
            "analyze" => {
                let path = arg.trim();
                if !path.is_empty() {
                    analyze_file(path);
                }
            }
            "pos" => {
                let ms = play_pos_ms
                    + match play_resume {
                        Some(r) => r.elapsed().as_secs_f64() * 1000.0,
                        None => 0.0,
                    };
                println!("pos {}", ms as u64);
                let _ = io::stdout().flush();
            }
            "" => {}
            _ => {}
        }
    }
}
