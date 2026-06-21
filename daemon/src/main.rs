use rodio::{OutputStream, OutputStreamHandle, Source};
use std::f32::consts::PI;
use std::io::{self, BufRead, Write};
use std::time::Duration;

const SAMPLE_RATE: u32 = 44100;

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

    let play = |freq: f32, secs: f32, amp: f32| {
        if let Some(h) = &handle {
            let _ = h.play_raw(Blip::new(freq, secs, amp));
        }
    };

    let mut out = io::stdout();
    let _ = writeln!(out, "ready");
    let _ = out.flush();

    let stdin = io::stdin();
    for line in stdin.lock().lines() {
        let line = match line {
            Ok(l) => l,
            Err(_) => break,
        };
        match line.trim() {
            "quit" => break,
            "perfect" => play(880.0, 0.10, 0.35),
            "good" => play(620.0, 0.10, 0.30),
            "miss" => play(160.0, 0.18, 0.30),
            "tick" => play(1320.0, 0.05, 0.22),
            "" => {}
            _ => {}
        }
    }
}
