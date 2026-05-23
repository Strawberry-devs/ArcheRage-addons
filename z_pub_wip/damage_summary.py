#!/usr/bin/env python3
import argparse
import re
from collections import defaultdict
from pathlib import Path

COLOR_CODE_RE = re.compile(r"\|c[0-9a-fA-F]{8}")
RESET_CODE_RE = re.compile(r"\|r")

ATTACK_RE = re.compile(
    r";(?P<source>[^|;]+) attacked (?P<target>[^|;]+) using (?P<ability>.+?) and caused "
    r"(?P<amount>-?\d+) Health \((?P<dtype>[^)]+)\)!"
)

TOOK_RE = re.compile(
    r";(?P<target>[^|;]+) took (?P<amount>\d+) (?P<ability>.+?) damage\."
)


def strip_codes(text: str) -> str:
    text = COLOR_CODE_RE.sub("", text)
    return RESET_CODE_RE.sub("", text)


def parse_file(path: Path):
    spell_stats = defaultdict(lambda: {"total": 0, "hits": 0, "crit_hits": 0, "max": 0})
    source_stats = defaultdict(lambda: {"total": 0, "hits": 0})

    lines_seen = 0
    damage_events = 0

    with path.open("r", encoding="utf-8", errors="replace") as f:
        for raw_line in f:
            lines_seen += 1
            line = strip_codes(raw_line.strip())

            attack = ATTACK_RE.search(line)
            if attack:
                amount_raw = attack.group("amount")
                if amount_raw is None:
                    continue

                amount = abs(int(amount_raw))
                if amount <= 0:
                    continue

                source = attack.group("source").strip()
                ability = attack.group("ability").strip()
                dtype = (attack.group("dtype") or "Damage").strip().lower()

                spell_stats[ability]["total"] += amount
                spell_stats[ability]["hits"] += 1
                spell_stats[ability]["max"] = max(spell_stats[ability]["max"], amount)
                if "critical" in dtype:
                    spell_stats[ability]["crit_hits"] += 1

                source_stats[source]["total"] += amount
                source_stats[source]["hits"] += 1

                damage_events += 1
                continue

            took = TOOK_RE.search(line)
            if took:
                amount = int(took.group("amount"))
                if amount <= 0:
                    continue

                ability = took.group("ability").strip()
                spell_stats[ability]["total"] += amount
                spell_stats[ability]["hits"] += 1
                spell_stats[ability]["max"] = max(spell_stats[ability]["max"], amount)
                source_stats["Environment"]["total"] += amount
                source_stats["Environment"]["hits"] += 1

                damage_events += 1

    return lines_seen, damage_events, spell_stats, source_stats


def top_items(dct, key, limit):
    return sorted(dct.items(), key=lambda kv: kv[1][key], reverse=True)[:limit]


def main():
    parser = argparse.ArgumentParser(description="Summarize damage events from ArcheRage combat logs.")
    parser.add_argument("logfile", type=Path, help="Path to combat log file")
    parser.add_argument("--top", type=int, default=15, help="How many top entries to display (default: 15)")
    args = parser.parse_args()

    lines_seen, damage_events, spell_stats, source_stats = parse_file(args.logfile)

    if damage_events == 0:
        print("No damage events found.")
        return

    total_damage = sum(v["total"] for v in spell_stats.values())

    print(f"Log: {args.logfile}")
    print(f"Lines scanned: {lines_seen}")
    print(f"Damage events: {damage_events}")
    print(f"Total recorded damage: {total_damage}")
    print()

    print("Top spells by total damage")
    for i, (spell, stat) in enumerate(top_items(spell_stats, "total", args.top), start=1):
        avg = stat["total"] / stat["hits"] if stat["hits"] else 0
        crit_rate = (stat["crit_hits"] / stat["hits"] * 100) if stat["hits"] else 0
        print(
            f"{i:>2}. {spell:<35} total={stat['total']:<8} hits={stat['hits']:<5} "
            f"avg={avg:>7.1f} max={stat['max']:<7} crit%={crit_rate:>5.1f}"
        )

    print()
    print("Top sources by total damage")
    for i, (source, stat) in enumerate(top_items(source_stats, "total", args.top), start=1):
        avg = stat["total"] / stat["hits"] if stat["hits"] else 0
        print(f"{i:>2}. {source:<35} total={stat['total']:<8} hits={stat['hits']:<5} avg={avg:>7.1f}")


if __name__ == "__main__":
    main()
