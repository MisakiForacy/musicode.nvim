import argparse
import json
import math
import os
import statistics
import time


def summarize(dts, perfect, good, miss, total):
    n = len(dts)
    med = statistics.median(dts) if n else 0.0
    mu = statistics.fmean(dts) if n else 0.0
    sd = statistics.stdev(dts) if n > 1 else 0.0
    acc = (perfect + 0.5 * good) / total if total else 0.0
    return {"median": med, "mean": mu, "std": sd, "n": n, "acc": acc}


def skill_of(g):
    cv = (g["std"] / g["mean"]) if g["mean"] > 0 else 1.0
    s = 0.5 * (1.0 - min(cv, 1.0)) + 0.5 * g["acc"]
    return max(0.0, min(1.0, s))


def train(log_path):
    by_ft = {}
    allb = {"dts": [], "perfect": 0, "good": 0, "miss": 0, "total": 0}
    prev_t = None
    with open(log_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                e = json.loads(line)
            except json.JSONDecodeError:
                continue
            t = e.get("t")
            if t is None:
                continue
            ft = e.get("ft") or "_"
            b = by_ft.setdefault(ft, {"dts": [], "perfect": 0, "good": 0, "miss": 0, "total": 0})
            if prev_t is not None and t > prev_t:
                dt = t - prev_t
                if 20 < dt < 1500:
                    b["dts"].append(dt)
                    allb["dts"].append(dt)
            j = e.get("j")
            if j in ("perfect", "good", "miss"):
                b[j] += 1
                allb[j] += 1
            b["total"] += 1
            allb["total"] += 1
            prev_t = t
    per_ft = {ft: summarize(b["dts"], b["perfect"], b["good"], b["miss"], b["total"]) for ft, b in by_ft.items()}
    g = summarize(allb["dts"], allb["perfect"], allb["good"], allb["miss"], allb["total"])
    return {"per_ft": per_ft, "global": g, "skill": skill_of(g), "generated": int(time.time())}


def default_data_dir():
    base = os.environ.get("LOCALAPPDATA") or os.path.expanduser("~/.local/share")
    return os.path.join(base, "nvim-data", "musicode")


def main():
    dd = default_data_dir()
    ap = argparse.ArgumentParser(description="Train a musicode rhythm profile from rhythm.jsonl")
    ap.add_argument("--log", default=os.path.join(dd, "rhythm.jsonl"))
    ap.add_argument("--out", default=os.path.join(dd, "profile.json"))
    args = ap.parse_args()
    if not os.path.isfile(args.log):
        raise SystemExit("log not found: " + args.log)
    profile = train(args.log)
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(profile, f)
    print("skill={:.3f} samples={} fts={}".format(profile["skill"], profile["global"]["n"], len(profile["per_ft"])))


if __name__ == "__main__":
    main()
