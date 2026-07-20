#!/usr/bin/env python3
"""plot_results.py -- turns results.csv into the three payoff plots.

Run from the directory containing results.csv:
    python3 plot_results.py

Outputs: convergence.png, error_loglog.png, house_edge.png
and prints a final summary table.
"""

import numpy as np
import pandas as pd
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

# ---- exact theory ----------------------------------------------------
P_PASS = 244 / 495          # 0.492929...
P_HW = 1 / 11               # 0.090909...
EDGE_PASS = 7 / 495         # 1.414%   (even-money payout: edge = 1 - 2p)
EDGE_HW = 1 / 11            # 9.091%   (9:1 payout: edge = 1 - 11p... = 1/11)
ROLLS_PER_GAME = 557 / 165  # 3.376    (free bonus check)

# ---- load ------------------------------------------------------------
df = pd.read_csv("results.csv").drop_duplicates("games").sort_values("games")
df = df[df.games > 0]
df["rate"] = df.wins / df.games
df["hw_rate"] = df.hw_wins / df.hw_bets.clip(lower=1)

final = df.iloc[-1]
N = int(final.games)
sigma_pass = np.sqrt(P_PASS * (1 - P_PASS) / N)
sigma_hw = np.sqrt(P_HW * (1 - P_HW) / max(int(final.hw_bets), 1))

# ---- plot 1: convergence ---------------------------------------------
fig, axes = plt.subplots(1, 2, figsize=(11, 4.2))
axes[0].semilogx(df.games, df.rate, "o-", ms=4, label="measured")
axes[0].axhline(P_PASS, color="crimson", ls="--", label=f"theory 244/495 = {P_PASS:.4f}")
axes[0].set_xlabel("games played (log scale)")
axes[0].set_ylabel("pass-line win rate")
axes[0].set_title("Pass line converges to 244/495")
axes[0].legend()
axes[1].semilogx(df.hw_bets.clip(lower=1), df.hw_rate, "o-", ms=4,
                 color="darkorange", label="measured")
axes[1].axhline(P_HW, color="crimson", ls="--", label=f"theory 1/11 = {P_HW:.4f}")
axes[1].set_xlabel("hard-8 resolutions (log scale)")
axes[1].set_ylabel("hard-8 win rate")
axes[1].set_title("Hard 8 converges to 1/11")
axes[1].legend()
fig.tight_layout()
fig.savefig("convergence.png", dpi=150)

# ---- plot 2: log-log error decay -------------------------------------
err = (df.rate - P_PASS).abs()
mask = err > 0
fig2, ax = plt.subplots(figsize=(6.5, 4.6))
ax.loglog(df.games[mask], err[mask], "o-", ms=4, label="|measured - theory|")
ref = np.sqrt(P_PASS * (1 - P_PASS) / df.games)
ax.loglog(df.games, ref, "--", color="crimson",
          label=r"predicted 1$\sigma$: $\sqrt{p(1-p)/N}$  (slope $-1/2$)")
ax.set_xlabel("games played N")
ax.set_ylabel("pass-line win-rate error")
ax.set_title("Error decays at the Law-of-Large-Numbers rate")
ax.legend()
fig2.tight_layout()
fig2.savefig("error_loglog.png", dpi=150)

# ---- plot 3: house edges, measured vs exact --------------------------
meas_edge_pass = -(2 * final.rate - 1)
meas_edge_hw = -(10 * final.hw_rate - 1)
fig3, ax3 = plt.subplots(figsize=(6.0, 4.6))
x = np.arange(2)
ax3.bar(x - 0.18, [EDGE_PASS * 100, EDGE_HW * 100], 0.36,
        label="exact theory", color="lightsteelblue", edgecolor="k")
ax3.bar(x + 0.18, [meas_edge_pass * 100, meas_edge_hw * 100], 0.36,
        label="measured", color="darkorange", edgecolor="k")
ax3.set_xticks(x, ["Pass line\n(pays 1:1)", "Hard 8\n(pays 9:1)"])
ax3.set_ylabel("house edge (%)")
ax3.set_title("Same dice, two bets, two very different house edges")
ax3.legend()
fig3.tight_layout()
fig3.savefig("house_edge.png", dpi=150)

# ---- summary ---------------------------------------------------------
print(f"N = {N:,} games   ({int(final.rolls):,} rolls, "
      f"{final.rolls / N:.4f} rolls/game vs theory {ROLLS_PER_GAME:.4f})")
print(f"pass line: measured {final.rate:.6f}  theory {P_PASS:.6f}  "
      f"gap {abs(final.rate - P_PASS):.6f}  (1 sigma = {sigma_pass:.6f})")
print(f"hard 8   : measured {final.hw_rate:.6f}  theory {P_HW:.6f}  "
      f"gap {abs(final.hw_rate - P_HW):.6f}  (1 sigma = {sigma_hw:.6f})")
print(f"house edge pass line: measured {meas_edge_pass*100:.3f}%  exact {EDGE_PASS*100:.3f}%")
print(f"house edge hard 8   : measured {meas_edge_hw*100:.3f}%  exact {EDGE_HW*100:.3f}%")
print("wrote convergence.png, error_loglog.png, house_edge.png")
