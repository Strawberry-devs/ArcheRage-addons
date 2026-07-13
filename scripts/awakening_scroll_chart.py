#!/usr/bin/env python3
"""Compare 30% and 50% awakening scrolls with a growing failure bonus.

The 30% scroll is the unit cost.  By default the 50% scroll costs 1.5 units.
After each failure, the success chance of either scroll increases by five
percentage points.  Chances are capped at 100%.
"""

from __future__ import annotations

import argparse
import csv
import math
from pathlib import Path

try:
    import matplotlib.pyplot as plt
except ImportError as exc:  # pragma: no cover - only reached without dependency
    raise SystemExit("This script needs matplotlib: python -m pip install matplotlib") from exc


BASE_CHANCES = {"30% scroll": 0.30, "50% scroll": 0.50}
COLORS = {"30% scroll": "#2878B5", "50% scroll": "#D95319"}


def chance(scroll: str, failures: int, bonus: float) -> float:
    """Success probability for a scroll after ``failures`` failed attempts."""
    return min(1.0, BASE_CHANCES[scroll] + failures * bonus)


def expected_costs(
    costs: dict[str, float], bonus: float, max_failures: int
) -> tuple[dict[str, list[float]], list[float], list[str]]:
    """Return fixed-scroll costs plus optimal cost/policy for every state.

    Recurrence: E[state] = attempt_cost + failure_probability * E[state + 1].
    The final state has 100% success for both scrolls, so backwards dynamic
    programming gives exact values rather than a simulation estimate.
    """
    fixed = {scroll: [0.0] * (max_failures + 1) for scroll in BASE_CHANCES}
    optimal = [0.0] * (max_failures + 1)
    policy = [""] * (max_failures + 1)

    for failures in range(max_failures, -1, -1):
        for scroll in BASE_CHANCES:
            next_cost = fixed[scroll][failures + 1] if failures < max_failures else 0.0
            fixed[scroll][failures] = costs[scroll] + (1 - chance(scroll, failures, bonus)) * next_cost

        candidates = {}
        for scroll in BASE_CHANCES:
            next_cost = optimal[failures + 1] if failures < max_failures else 0.0
            candidates[scroll] = costs[scroll] + (1 - chance(scroll, failures, bonus)) * next_cost
        policy[failures] = min(candidates, key=candidates.get)
        optimal[failures] = candidates[policy[failures]]

    return fixed, optimal, policy


def write_csv(
    path: Path,
    failures_range: range,
    costs: dict[str, float],
    bonus: float,
    fixed: dict[str, list[float]],
    optimal: list[float],
    policy: list[str],
) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow([
            "failures", "30_chance", "50_chance", "30_chance_per_cost",
            "50_chance_per_cost", "always_30_expected_cost",
            "always_50_expected_cost", "optimal_expected_cost", "optimal_next_scroll",
        ])
        for f in failures_range:
            writer.writerow([
                f, chance("30% scroll", f, bonus), chance("50% scroll", f, bonus),
                chance("30% scroll", f, bonus) / costs["30% scroll"],
                chance("50% scroll", f, bonus) / costs["50% scroll"],
                fixed["30% scroll"][f], fixed["50% scroll"][f], optimal[f], policy[f],
            ])


def create_chart(
    path: Path,
    failures_range: range,
    costs: dict[str, float],
    bonus: float,
    fixed: dict[str, list[float]],
    optimal: list[float],
    policy: list[str],
) -> None:
    xs = list(failures_range)
    fig, axes = plt.subplots(2, 2, figsize=(14, 9), constrained_layout=True)

    ax = axes[0, 0]
    for scroll in BASE_CHANCES:
        ax.plot(xs, [100 * chance(scroll, f, bonus) for f in xs], marker="o",
                label=scroll, color=COLORS[scroll])
    ax.set(title="Success chance on the next attempt", xlabel="Previous failures", ylabel="Success chance (%)")
    ax.set_ylim(0, 105)
    ax.legend()

    ax = axes[0, 1]
    for scroll in BASE_CHANCES:
        ax.plot(xs, [chance(scroll, f, bonus) / costs[scroll] for f in xs], marker="o",
                label=scroll, color=COLORS[scroll])
    ax.set(title="Immediate chance per cost unit", xlabel="Previous failures", ylabel="Probability / cost")
    ax.legend()

    ax = axes[1, 0]
    ax.plot(xs, [fixed["30% scroll"][f] for f in xs], marker="o", linewidth=3,
            label="Always 30% (also optimal)", color=COLORS["30% scroll"])
    ax.plot(xs, [fixed["50% scroll"][f] for f in xs], marker="o", linewidth=2,
            label="Always 50%", color=COLORS["50% scroll"])
    ax.set(title="Expected remaining cost until success", xlabel="Previous failures", ylabel="Cost units (30% scroll = 1)")
    ax.legend()

    ax = axes[1, 1]
    penalties = []
    for f in xs:
        continuation = optimal[f + 1] if f < xs[-1] else 0.0
        use_30 = costs["30% scroll"] + (1 - chance("30% scroll", f, bonus)) * continuation
        use_50 = costs["50% scroll"] + (1 - chance("50% scroll", f, bonus)) * continuation
        penalties.append(100 * (use_50 - use_30) / use_30)
    ax.axhline(0, color="black", linewidth=1)
    ax.fill_between(xs, 0, penalties, where=[p >= 0 for p in penalties],
                    color=COLORS["30% scroll"], alpha=0.18)
    ax.fill_between(xs, 0, penalties, where=[p < 0 for p in penalties],
                    color=COLORS["50% scroll"], alpha=0.18)
    ax.plot(xs, penalties, marker="o", linewidth=3, color="#6F42C1")
    ax.set(title="Penalty for choosing 50% on the next attempt",
           xlabel="Previous failures", ylabel="Extra expected cost vs 30% (%)")
    ax.text(0.02, 0.96, "Above 0% = choose 30%\nBelow 0% = choose 50%",
            transform=ax.transAxes, va="top",
            bbox={"facecolor": "white", "edgecolor": "#bbbbbb", "alpha": 0.9})

    for ax in axes.flat:
        ax.grid(alpha=0.25)
        ax.set_xticks(xs)

    fig.suptitle(
        f"Awakening scroll comparison — 50% scroll costs {costs['50% scroll']:.2f}×; "
        f"fail bonus +{bonus * 100:.0f} points",
        fontsize=15,
    )
    fig.savefig(path, dpi=160)
    plt.close(fig)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cost-30", type=float, default=1.0, help="Actual or relative 30%% scroll cost")
    parser.add_argument("--cost-50", type=float, default=1.5, help="Actual or relative 50%% scroll cost")
    parser.add_argument("--bonus", type=float, default=5.0, help="Percentage-point chance added after each failure")
    parser.add_argument("--output-dir", type=Path, default=Path(__file__).with_name("awakening_scroll_output"))
    args = parser.parse_args()
    if args.cost_30 <= 0 or args.cost_50 <= 0 or not 0 < args.bonus <= 100:
        parser.error("costs must be positive and bonus must be between 0 and 100")

    bonus = args.bonus / 100
    costs = {"30% scroll": args.cost_30, "50% scroll": args.cost_50}
    max_failures = max(math.ceil((1.0 - base) / bonus) for base in BASE_CHANCES.values())
    failures_range = range(max_failures + 1)
    fixed, optimal, policy = expected_costs(costs, bonus, max_failures)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    chart_path = args.output_dir / "awakening_scroll_comparison.png"
    csv_path = args.output_dir / "awakening_scroll_data.csv"
    create_chart(chart_path, failures_range, costs, bonus, fixed, optimal, policy)
    write_csv(csv_path, failures_range, costs, bonus, fixed, optimal, policy)

    print(f"Chart: {chart_path.resolve()}")
    print(f"Data:  {csv_path.resolve()}")
    print(f"From zero failures: always 30% = {fixed['30% scroll'][0]:.3f} cost units")
    print(f"From zero failures: always 50% = {fixed['50% scroll'][0]:.3f} cost units")
    print(f"From zero failures: optimal switching = {optimal[0]:.3f} cost units")
    groups: list[tuple[int, int, str]] = []
    start = 0
    for i in range(1, len(policy) + 1):
        if i == len(policy) or policy[i] != policy[start]:
            groups.append((start, i - 1, policy[start]))
            start = i
    print("Optimal next choice by existing failure count:")
    for start, end, scroll in groups:
        label = str(start) if start == end else f"{start}-{end}"
        print(f"  {label} failures: {scroll}")


if __name__ == "__main__":
    main()
