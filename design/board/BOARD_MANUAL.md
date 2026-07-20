# 🎲 The Craps Machine — Board Demo Operator's Manual

*Basys3 · everything you will see, what it means, and what to say about it.*

---

## 1. What this machine is

The same `craps_core` that produced your graded simulation results, synthesized onto real silicon. It contains two LFSR dice with rejection sampling, the pass-line game FSM, and the hard-8 watcher, all running at 100 MHz. The board wrapper adds only input/output plumbing: a debounced button, a mode switch, a BCD converter, and the display driver. **Nothing about the game logic differs from the simulation** — that's why the numbers below can be stated in advance.

## 2. Controls at a glance

| Control | Function |
|:--|:--|
| **BTNU** (up button) | Reset — zeroes all counters AND restarts the LFSRs from their seeds |
| **BTNC** (center button) | Action — run a batch (stats mode) or roll once (play mode) |
| **SW0** (rightmost switch) | Mode: **down = stats**, **up = play** |

| Output | Meaning |
|:--|:--|
| 7-seg display | Stats: wins per 10,000-game batch · Play: `[die1][die2][sum]` |
| LED0 | Game is in the **come-out** phase |
| LED1 | Game is in the **point** phase |
| LED5:2 | The current point value, in binary (see table in §5) |
| LED6 | The most recent game was **won** (sticky until next press) |
| LED7 | The most recent game was **lost** (sticky until next press) |

---

## 3. Stats mode (SW0 down) — the headline demo

### What one press does
The machine plays **exactly 10,000 fresh games** — dealing, rolling, resolving every one — and displays the total number of *wins*. All of it takes about **0.6 milliseconds**: the result is on the display before your finger leaves the button.

### What the number means
This is the trick that avoids a hardware divider: wins-per-10,000 **is** the win rate × 10⁴. Theory says the pass line wins with probability 244/495 = 0.4929, so the display should read **≈ 4929**.

### How much scatter is normal
Each batch is a Binomial(10000, 0.4929) sample. Its standard deviation is √(10000·p·(1−p)) ≈ **50**, so:

- ~68% of presses land in **4879–4979** (±1σ)
- ~95% of presses land in **4829–5029** (±2σ)
- A press outside 4779–5079 (±3σ) should happen less than once in 300 presses

**This scatter is the point, not a flaw.** Each press is an independent 10,000-game experiment (the LFSRs keep marching between presses, so no two batches reuse the same dice). Pressing repeatedly and watching values cluster tightly around 4929 is the sampling distribution of an estimator, demonstrated live in hardware.

### The determinism party trick
The machine contains no true randomness — same seeds, same sequence, always. Therefore **after every reset, the batch sequence is identical and predictable**. Press BTNU, then BTNC repeatedly, and you will see:

| Press | Display | Press | Display |
|:-:|:-:|:-:|:-:|
| 1 | **4934** | 5 | 4925 |
| 2 | 4839 | 6 | 4886 |
| 3 | 4880 | 7 | 5015 |
| 4 | 4964 | 8 | 4875 |

(Press 1 is exact every time; later presses may occasionally drift by a game or two because of the batch-boundary quirk in §6.) Predicting "4934" out loud *before* pressing is a killer moment — and then explaining *why* you could (PRNG determinism) is exactly the understanding the assignment grades.

### LEDs during stats mode
The batch is too fast to watch, so the state LEDs just show wherever the machine halted, and LED6/LED7 show the outcome of the **last game of the batch** — effectively a coin-flip decoration. Occasionally LED1 + a point value light up after a batch: that's the stray extra roll (§6) having started a new game. All normal.

---

## 4. Play mode (SW0 up) — one roll per press

### Reading the display
Four digits: `[die 1] [die 2] [sum tens] [sum ones]`. Examples: `4509` = rolled 4 and 5, sum 9. `5611` = rolled 5 and 6, sum 11. `0000` = no roll yet since reset.

### The game, mapped to lights
You are always in one of two phases, shown by LED0/LED1:

**Come-out phase (LED0 lit).** Press to roll. Three outcomes:
| You rolled | What happens | What you see |
|:--|:--|:--|
| 7 or 11 | Instant win ("natural") | LED6 lights, LED0 stays — new game, still come-out |
| 2, 3, or 12 | Instant loss ("craps") | LED7 lights, LED0 stays |
| 4, 5, 6, 8, 9, 10 | That number becomes the point | LED1 lights, LED5:2 show the point |

**Point phase (LED1 lit).** Now only two numbers matter:
| You rolled | What happens | What you see |
|:--|:--|:--|
| The point again | You win | LED6, back to LED0 (come-out) |
| Any 7 | "Seven out" — you lose | LED7, back to LED0 |
| Anything else | Nothing — the game continues | No LED change; keep pressing |

That last row is the soul of craps: rolls that would have decided the game instantly on the come-out now do nothing, and the 7 that would have won it now kills you.

### Decoding the point on LED5:2 (binary, LED2 = least significant bit)
| Point | LED5 | LED4 | LED3 | LED2 |
|:-:|:-:|:-:|:-:|:-:|
| 4 | · | ● | · | · |
| 5 | · | ● | · | ● |
| 6 | · | ● | ● | · |
| 8 | ● | · | · | · |
| 9 | ● | · | · | ● |
| 10 | ● | · | ● | · |

### Example annotated session (a real deterministic trace from this design)
Roll `4509` → sum 9 on come-out → LED1 on, LEDs show 9 (●··●) — *point is 9*.
Roll `5611` → sum 11 → **nothing happens** (11 only matters on come-out).
Roll `3205` → sum 5 → nothing (not 9, not 7). The game simply continues.

### Win/lose LEDs are sticky
LED6/LED7 stay lit until your **next press**, so you have time to see the result. Both dark = the last roll resolved nothing.

---

## 5. What's happening that you can't see

- **The hard-8 bet is still running.** Every roll in either mode feeds the hard-8 watcher and its counters — there's just no LED assigned to it. (If asked: it's in the silicon, verified in simulation; the board display budget went to the pass line.)
- **Rejection sampling is invisible.** When a die's 3-bit draw comes up 6 or 7, it silently redraws next cycle (10 ns). In play mode a "one press = one roll" may internally take 1–4 cycles. You will never perceive it.
- **Play-mode games count too.** Games you resolve by hand add to the same cumulative counters as stats batches. Harmless — each batch measures only its own 10,000 games.

## 6. Things that look weird but are correct

| Observation | Explanation |
|:--|:--|
| Display reads `0000` after reset | No batch run / no roll latched yet. Press BTNC. |
| Point LEDs lit right after a stats batch | The stray extra roll: `enable` drops one cycle after the batch target hits, so one bonus roll can start a new game. The displayed batch count is exact regardless (it's sampled at precisely 10,000 games). |
| Press 2+ occasionally differs a hair from the table in §3 | Same stray roll shifting a batch boundary by one game. Press 1 after reset is always exactly 4934. |
| First press after reset is always 4934 | Determinism — see §3. Feature, not bug. |
| LED6 lights but LED0 never left come-out | You rolled a natural (7/11) — instant win without entering the point phase. Rules working correctly. |
| Sum shows a leading zero (`09`) | Two digits are reserved for the sum because 10, 11, 12 exist. |
| Mode switch changes the display instantly without a press | The display source is combinational; the *behavior* of the next press is what the switch really selects. |

## 7. Failure signatures (what a real bug would look like)

| Symptom | Likely cause |
|:--|:--|
| Batches consistently land far outside 4829–5029, press after press | Dice bias (rejection sampling broken) or decode miswired — this is exactly the deviation size the broken mod-6 die would cause |
| Every press shows the identical number without pressing reset | LFSRs not advancing between batches (enable/consume wiring) |
| Display frozen at `0000`, LEDs dead | Wrong top module synthesized, bitstream not programmed (check the DONE LED), or BTNU stuck high |
| Digits ghosting/smearing into each other | Display refresh rate — one-line fix in `sevenseg_display.v` |
| One digit permanently dark | Anode pin mixup in the `.xdc` |
| Button needs mashing | Debounce period vs a bouncy button — raise `DB_BITS` |

## 8. Suggested demo scripts

**The 15-second version (for the presentation — this is the whole thing):**
Reset. "This board contains our entire experiment. Watch — a million... sorry, *ten thousand* games." Press. "4934 — that's a 49.3% win rate, our 244/495, computed by silicon faster than I released the button." Press three more times silently: 4839, 4880, 4964. "Every press, a fresh ten thousand games, always inside the band theory predicts." Done — back to slides.

**The 60-second version (for after class / TA curiosity):**
Do the above, then: "And because it's an LFSR, it's deterministic — reset, and I'll tell you the number before I press: 4934." Reset, press, 4934. Then flip SW0: "Or play it yourself — one press, one roll." Walk one game on the LEDs, narrating come-out → point → resolution.

**One rule:** never let the board eat the 5-minute clock. It's the encore, not the act.

## 9. Q&A ammunition (board-specific)

- *"How does it show a win rate with no divider?"* — The batch is exactly 10⁴ games, so the win **count** is the rate × 10⁴. Choosing the batch size to make the count readable **is** the divide.
- *"Is it really playing the games or just showing numbers?"* — Same RTL as the simulation that produced our plots; the board testbench verified batch counts and single-roll behavior before synthesis. Also: play mode *is* the same FSM, visibly obeying the rules one roll at a time.
- *"Why is the first press always 4934?"* — Deterministic PRNG: same seed → same 33,700-ish rolls → same result. Reproducibility is why hardware verification works at all.
- *"Could it be truly random?"* — Yes: latch a free-running counter on the first human button press and use it as the seed — press timing at 10 ns resolution is unpredictable. We kept fixed seeds deliberately so results are reproducible and verifiable.
- *"How fast is it really?"* — ~1.7 clock cycles per roll, ~3.4 rolls per game → a full million-game run in ~57 ms. The two-minute Vivado simulation compresses to an eyeblink at 100 MHz.
