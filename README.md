# The Craps Machine — Core Simulation

Plays 2^20 (1,048,576) games of the craps pass line + hard-8 side bet,
writes `results.csv`, and a Python script turns it into the three plots.

## Files
```
src/lfsr.v           parameterized maximal LFSR (different taps per die)
src/die_gen.v        rejection sampling + valid handshake
src/passline_fsm.v   the pass-line game FSM (2 states + point register)
src/hardways_fsm.v   hard-8 watcher (permanently armed by construction)
src/craps_core.v     top: dice -> decode -> both FSMs
tb/tb_craps.v        testbench: power-of-two CSV snapshots
tb/tb_board.v        board top-level testbench (verified before hardware)
src/board/top.v      Basys3 top: stats mode + play mode
src/board/debounce.v      button synchronizer/debouncer
src/board/bin2bcd.v       double-dabble binary -> BCD
src/board/sevenseg_display.v   4-digit multiplexed display driver
constraints/basys3.xdc    pin constraints (Basys3 master names)
analysis/plot_results.py   makes the three plots + summary table
sample_output/       a verified run: results.csv + the three PNGs
```

## Board demo (Basys3)
Two modes, selected by SW0. BTNU = reset, BTNC = action.
* **SW0=0, stats mode:** each BTNC press plays a fresh batch of exactly
  10,000 games (~0.6 ms of real time) and shows the WIN COUNT on the
  7-seg -- expected ~4929, i.e. the win rate x 10^4, no divider needed.
  The LFSRs keep state between presses, so repeated presses are
  independent samples scattering within ~ +/-100 (2 sigma) of 4929:
  the sampling distribution, live.
* **SW0=1, play mode:** each press rolls once. Display shows
  [die1][die2][sum]; LED0/1 = come-out/point phase, LED5:2 = point
  value, LED6 = last game won, LED7 = last game lost.

To build: add `src/` + `src/board/` as design sources (top = `top`),
add `constraints/basys3.xdc`, Run Synthesis -> Implementation ->
Generate Bitstream, then Hardware Manager -> Program Device.
`tb_board` verifies both modes in simulation first (uses shrunk
debounce/batch parameters so presses simulate fast).

## Running in Vivado
1. New project (no board needed for simulation) → add all files in `src/`
   as design sources and `tb/tb_craps.v` as a **simulation source**.
2. Make sure `tb_craps` is the simulation top (right-click → Set as Top).
3. **Important:** the default 1000 ns runtime is nowhere near enough.
   Either type `run -all` in the Tcl console after launching, or set
   Settings → Simulation → xsim.simulate.runtime to `-all`.
4. Run Behavioral Simulation. Takes a couple of minutes; the Tcl console
   prints a summary when done.
5. Find `results.csv` where xsim runs (type `pwd` in the Tcl console):
   `<project>/<project>.sim/sim_1/behav/xsim/results.csv`
6. Copy `analysis/plot_results.py` next to it and run
   `python3 plot_results.py` (needs `pip install pandas matplotlib`).

## Quick local check without Vivado (optional)
Icarus Verilog runs the same code:
```
iverilog -o craps_sim src/*.v tb/tb_craps.v && vvp craps_sim
python3 analysis/plot_results.py    # run in the same directory as results.csv
```

## Verified results (the run in sample_output/)
| Quantity | Measured | Theory | Gap |
|---|---|---|---|
| Pass-line win rate | 0.492978 | 244/495 = 0.492929 | 0.000049 (1σ = 0.000488) |
| Hard-8 win rate | 0.090832 | 1/11 = 0.090909 | 0.000077 (1σ = 0.000276) |
| Rolls per game | 3.3714 | 557/165 = 3.3758 | — |
| Pass-line house edge | 1.404% | 1.414% | — |
| Hard-8 house edge | 9.168% | 9.091% | — |

## Where each piece of TA feedback lives
1. **Different polynomials** → `craps_core.v`: die 1 is a 24-bit LFSR
   (taps 24,23,22,17), die 2 a 23-bit LFSR (taps 23,18) — different
   polynomials *and* widths.
2. **Don't log every roll** → `tb_craps.v`: snapshots only when
   `(games & (games-1)) == 0` (powers of two, ~20 file writes), which
   also spaces the points evenly for the log-log plot.
3. **≥20-bit counters** → all counters are 32-bit (`passline_fsm.v`,
   `hardways_fsm.v`).
4. **Ready/valid handshake** → `die_gen.v` raises `valid`;
   `craps_core.v` strobes only on `valid1 & valid2`.
5. **Hard-8 re-arm timing** → `hardways_fsm.v`: permanently armed by
   construction; it evaluates every strobe and cannot miss a roll.

## One subtlety worth knowing (LFSR stepping)
The LFSR advances **4 bits per attempt**, not 3. Stepping by k shortens
the state cycle by gcd(k, 2^WIDTH - 1), and 2^WIDTH - 1 is divisible by
3 for even widths — stepping by 3 would cut the period to a third.
gcd(4, odd) = 1 keeps the full period. Good Q&A ammo.
