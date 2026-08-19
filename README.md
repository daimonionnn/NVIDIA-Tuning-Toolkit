# NVIDIA RTX Tuning Toolkit for Linux

> ### Scope narrowed — tuning is now handled by LACT
>
> As of **2026-08-19**, day-to-day power/clock tuning on this machine is done with
> **[LACT](https://github.com/ilya-zlobintsev/LACT)** (GPU control daemon + GTK GUI),
> not with the scripts in this repo. **On a desktop** LACT is better at that job: it
> has a real GUI, its settings survive reboot *and* resume-from-sleep, it works
> natively on Wayland without the Coolbits/Xorg detour, and it manages AMD, NVIDIA
> and Intel GPUs from one place. It is *not* better everywhere — its CLI is much
> weaker than these scripts, see
> [What LACT's CLI can't do](#what-lacts-cli-cant-do).
>
> **No scripts have been removed.** Everything still works and stays in the repo for
> reference — the tuning parts are simply marked *superseded* below rather than
> recommended. The card-specific data (memory-offset tables, power-limit constants,
> validated 5090 profiles) is still worth keeping and is preserved in full.
>
> **Four things here that LACT does not do** — these remain the actively
> recommended path:
>
> | Still use this repo for | Why LACT can't |
> | --- | --- |
> | [`install-driver.sh`](install-driver.sh) — NVIDIA open-driver + CUDA bootstrap with Secure Boot MOK enrollment | LACT is a tuning daemon; it assumes a working driver and has no installer, `mokutil`, or DKMS handling whatsoever |
> | [`nvidia-settings/ecc-pro6000.sh`](nvidia-settings/ecc-pro6000.sh) — ECC on/off | LACT has **no ECC support** (verified: the only `ECC` strings in its binary are TLS certificate names) |
> | [`monitor.sh`](monitor.sh) — live stats incl. **ECC error counters** | `lact cli stats` reports clocks, power, temps, fan and VRAM — but no ECC counters |
> | [`nvidia-tuner/apply-*.sh`](nvidia-tuner/) — core offset + memory offset + power limit in one command, **fully headless** | LACT's CLI has no clock-offset command at all. Offsets can only be set in the GTK GUI, so a headless/SSH-only box can't apply them through LACT |

Scripts for tuning and overclocking NVIDIA RTX GPUs. Originally built and
tested on an MSI RTX 5090 Vanguard; now also covers an RTX PRO 6000 Blackwell
(Workstation Edition) after a card swap.

Every script that carries GPU-specific defaults (power limits, clock offsets)
comes in two versions, picked by filename suffix:

| Suffix     | Card                                         | Status                                                             |
| ---------- | -------------------------------------------- | ------------------------------------------------------------------ |
| `-5090`    | RTX 5090 (MSI Vanguard)                      | Validated — offsets/profiles below were tested on this card        |
| `-pro6000` | RTX PRO 6000 Blackwell (Workstation Edition) | New — defaults are conservative starting points, not yet validated |

Shared, model-agnostic files (`install-driver.sh`, `nvidia-settings/install.sh`,
`monitor.sh`, `nvidia-settings/config/10-coolbits.conf`) have no suffix and
work with either card.

GPU currently installed: **RTX PRO 6000 Blackwell (Workstation Edition)** · GB202 · GDDR7 96 GB ECC
Run `nvidia-smi` to confirm your driver version — swapping the card doesn't change it automatically.

---

## Quick Start (current, recommended)

```bash
# 1. Install the NVIDIA driver + CUDA toolkit (this repo — LACT has no equivalent)
sudo bash install-driver.sh

# 2. Install LACT for power/clock tuning
sudo apt install lact          # or grab a .deb from the LACT releases page
sudo systemctl enable --now lactd

# 3. Tune — GUI for clocks/fan/voltage, CLI for power limit and profiles
lact gui
lact cli list
lact cli -g <gpu-id> power-limit set 300
lact cli -g <gpu-id> stats

# 4. ECC toggle (this repo — LACT has no ECC support)
./nvidia-settings/ecc-pro6000.sh status   # no sudo needed
./nvidia-settings/ecc-pro6000.sh on       # pending — needs a reboot to apply
./nvidia-settings/ecc-pro6000.sh off

# 5. Monitor, including ECC error counters (this repo — LACT has no ECC counters)
./monitor.sh
```

If Secure Boot is enabled, `install-driver.sh` will prompt for a MOK enrollment password and the key will be enrolled on the next reboot.
If the driver is already installed and the GPU is working, `install-driver.sh` is optional unless you want the CUDA toolkit or need to refresh the Secure Boot enrollment path.

---

## Using LACT

### What LACT covers

| Task | LACT | Replaces |
| --- | --- | --- |
| Power limit, persistent across reboot **and** resume | `lact cli -g <id> power-limit set <W>`, or GUI | `nvidia-settings/power-limit-*.sh` |
| Core / memory clock offsets | **GUI only** — no CLI subcommand exists | `nvidia-settings/oc-memory-*.sh`, `oc-reset-*.sh` |
| Fan curve, voltage offset | GUI only | — (not covered here before) |
| Live stats (clocks, power, temps, fan, VRAM) | `lact cli -g <id> stats` + GUI | most of `monitor.sh` (except ECC counters) |
| Named profiles, switchable from a script | Create in GUI, then `lact cli profile set <name>` | `nvidia-tuner/apply-*.sh` |
| Applying settings at boot | Automatic — `lactd` applies its own config | `systemd/nvidia-tuner-low-power-pro6000.service` |
| Unlocking OC controls | Uses NVML directly; works on Wayland | `nvidia-settings/install.sh` + Coolbits/Xorg |

The full CLI surface is just `list`, `info`, `stats`, `snapshot`, `power-limit`
and `profile` — clock offsets, fan control and voltage are GUI-only. If you need
offsets applied non-interactively, define them as a **profile** in the GUI and
switch with `lact cli profile set <name>`.

Config lives in `/etc/lact/config.yaml`, keyed per GPU:

```yaml
gpus:
  10DE:2BB1-103C:204B-0000:01:00.0:
    fan_control_enabled: false
    power_cap: 300.0
```

The CLI needs no `sudo` — `lactd` authorizes over its socket against the group in
`daemon.admin_group` (default `sudo`).

### What LACT's CLI can't do

Worth being blunt about, since it cuts the other way: **`lact cli` is weaker than
the scripts in this repo.** Its entire surface is

```
lact cli   list   info   stats   snapshot   power-limit   profile
```

There is no `clocks`, `offset`, `overclock`, `fan`, `voltage` or `ecc`
subcommand — those exist only in the GTK GUI. Practical consequences:

| Scenario | This repo | LACT |
| --- | --- | --- |
| Set core + memory offset and power limit in one shell command | `./nvidia-tuner/apply-efficient-pro6000.sh` | not possible from the CLI |
| Tune a headless / SSH-only machine with no GTK stack | works — `nvidia-tuner` needs no display server at all | offsets unreachable; only `power-limit` works |
| Version-control a profile as reviewable code | the `apply-*.sh` scripts are the profile | profiles are GUI-authored state in `/etc/lact/config.yaml` |
| Toggle ECC | `./nvidia-settings/ecc-pro6000.sh on` | unsupported |

The `nvidia-tuner` path really is display-independent: the boot unit in
[`systemd/`](systemd/) runs `apply-low-power-pro6000.sh` as root at
`multi-user.target`, before any session exists, and it applies cleanly.

(The older `nvidia-settings/oc-memory-*.sh` path is *not* headless — that one
does need an NVIDIA-managed Xorg session, which is exactly why `nvidia-tuner`
replaced it here.)

The workaround for LACT is to author a profile once in the GUI and then switch it
non-interactively with `lact cli profile set <name>` — fine on a desktop, no help
on a headless box.


### Two gotchas worth knowing

**1. LACT silently overwrites this repo's boot service.** `lactd.service` and any
`nvidia-tuner-*.service` are both ordered only `After=multi-user.target`, with no
ordering between them. LACT reliably lands **~0.4 s after** the tuning script and
resets any GPU it has no config entry for back to board defaults — power limit to
stock TGP, clock offsets to 0. The tuner service still exits `0` and logs
"power 300W", which makes this very easy to misdiagnose. Confirm with:

```bash
journalctl -b | grep 'initialized nvidia controller'
```

Do not run both. Put the value in `/etc/lact/config.yaml` and disable the old unit:

```bash
sudo systemctl disable --now nvidia-tuner-low-power-pro6000.service
```

**2. LACT config keys are PCI-address-based.** Adding, removing or moving a card
renumbers the PCI bus, the key stops matching, and your settings silently fall
back to defaults. Re-check `/etc/lact/config.yaml` after any hardware change.

---

# Superseded below

> Everything from here on is the **pre-LACT** tuning path. It is kept for
> reference and still functional — the card-specific measurements in particular
> (memory-offset risk tables, power-limit constants, validated RTX 5090 profiles)
> are not recorded anywhere else. Prefer LACT for new setups.
>
> Do **not** combine the systemd units described below with a running `lactd` —
> see the gotcha above.

---

## Superseded Quick Start (RTX PRO 6000)

```bash
# 1. Install the NVIDIA driver + CUDA toolkit first
sudo bash install-driver.sh

# 2. Run the one-time setup (requires sudo for xorg config + display restart)
bash nvidia-settings/install.sh

# 3. Set power limit (stock/default TGP: 600 W; board min: 150 W, confirmed via nvidia-smi)
./nvidia-settings/power-limit-pro6000.sh 500       # 500 W — reduced power profile
./nvidia-settings/power-limit-pro6000.sh default   # 600 W — stock TGP
./nvidia-settings/power-limit-pro6000.sh status    # show current limits (no sudo)

# 4. After your session restarts, apply a memory overclock — UNVALIDATED,
#    start low (see "Memory Offset" below for why this card gets a lower cap)
./nvidia-settings/oc-memory-pro6000.sh 250    # very conservative start
./nvidia-settings/oc-memory-pro6000.sh 500    # moderate — test thoroughly

# 5. Revert to stock
./nvidia-settings/oc-reset-pro6000.sh

# Wayland-friendly method: nvidia-tuner presets
nvidia-tuner --core-clock-offset -50 --memory-clock-offset 500 --power-limit 500

# Or reset clocks to stock and unlock max power with the bundled helper
./nvidia-tuner/apply-default-pro6000.sh        # core 0, mem 0, PL 600W

# Undervolt profile helpers (UNVALIDATED starting points — see caveat below)
./nvidia-tuner/apply-balanced-pro6000.sh       # core -75, mem +2000, PL 500W
./nvidia-tuner/apply-efficient-pro6000.sh      # core -75, mem +1000, PL 450W
./nvidia-tuner/apply-max-efficiency-pro6000.sh # core -75, mem +1000, PL 400W
./nvidia-tuner/apply-low-power-pro6000.sh      # core -75, mem +1000, PL 300W
```

> **RTX PRO 6000 caveat:** none of the offsets/profiles above have been
> validated on real hardware yet — they're conservative starting points, not
> "reported working" numbers. This card's memory is **ECC-capable, but ECC
> is currently *disabled*** on this install (confirmed via
> `nvidia-smi --query-gpu=ecc.mode.current,ecc.mode.pending`) — check with
> `./nvidia-settings/ecc-pro6000.sh status` and toggle it with `on`/`off` if
> you want it back. With ECC off there's no error counter and no correction
> layer at all, so an unstable memory offset can silently corrupt compute
> results with zero warning — validate with real workload output (not just a
> crash-free stress test) before trusting a profile.
> The power-limit constants (150–600 W) were confirmed via
> `nvidia-smi --query-gpu=power.min_limit,power.max_limit,power.default_limit`
> on an actual Workstation Edition card, so `apply-low-power-pro6000.sh`'s
> 300 W is safely within range. If you have a Max-Q (300 W hard cap) or
> Server edition (450–600 W depending on power cable) instead, run
> `power-limit-pro6000.sh status` and adjust the `LIMIT_*` constants in that
> script to match your card.

---

## Superseded Quick Start (RTX 5090 — previous card, kept for reference)

Keep this around in case you reinstall a 5090, or as a template for tuning
another 5090.


```bash
# 1. Install the NVIDIA driver + CUDA toolkit first
sudo bash install-driver.sh

# 2. Run the one-time setup (requires sudo for xorg config + display restart)
bash nvidia-settings/install.sh

# 3. Set power limit (daily default: 500 W; stock: 575 W; max: 600 W)
./nvidia-settings/power-limit-5090.sh 500       # 500 W — daily default profile
./nvidia-settings/power-limit-5090.sh default   # 575 W — stock TDP
./nvidia-settings/power-limit-5090.sh max       # 600 W — board maximum
./nvidia-settings/power-limit-5090.sh status    # show current limits (no sudo)

# 4. After your session restarts, apply a memory overclock (daily default: +2500)
./nvidia-settings/oc-memory-5090.sh 2500   # daily default (RTX 5090 MSI Vanguard)
./nvidia-settings/oc-memory-5090.sh 500    # conservative start
./nvidia-settings/oc-memory-5090.sh 1000   # moderate
./nvidia-settings/oc-memory-5090.sh 1500   # aggressive (test for stability first)
./nvidia-settings/oc-memory-5090.sh 3000   # extreme (reported working on RTX 5090 MSI Vanguard)

# 5. Monitor in real time
./monitor.sh

# 6. Revert to stock
./nvidia-settings/oc-reset-5090.sh

# Wayland-friendly method: nvidia-tuner presets
nvidia-tuner --core-clock-offset -125 --memory-clock-offset 2500 --power-limit 500
nvidia-tuner --memory-clock-offset 3000 --power-limit 500

# Or reset clocks to stock and unlock max power with the bundled helper
./nvidia-tuner/apply-default-5090.sh        # core 0, mem 0, PL 600W

# Undervolt profile helpers (increasing efficiency, all validated on this card)
./nvidia-tuner/apply-balanced-5090.sh       # core -75,  mem +2500, PL 500W
./nvidia-tuner/apply-efficient-5090.sh      # core -125, mem +2500, PL 450W
./nvidia-tuner/apply-max-efficiency-5090.sh # core -125, mem +3000, PL 400W
```

---

## How It Works

### Coolbits (xorg)
NVIDIA locks overclocking in the driver by default. Setting `Coolbits=28` in
`/etc/X11/xorg.conf.d/10-coolbits.conf` unlocks:

| Bit | Value | Feature               |
| --- | ----- | --------------------- |
| 2   | 4     | Clock rate adjustment |
| 3   | 8     | GPU overclocking      |
| 4   | 16    | Fan speed control     |

This config is generic — it's not tied to either GPU model, only to the PCI
BusID of the slot the card is in (see Troubleshooting if `BusID` needs updating).

### Memory offset (`GPUMemoryTransferRateOffsetAllPerformanceLevels`)
`nvidia-settings` exposes this attribute once Coolbits is set. The value is a
**transfer-rate offset in MHz** applied on top of the stock GDDR7 frequency.

> **Important:** this control is exposed only from an NVIDIA-managed **Xorg**
> session. A Wayland session that only provides Xwayland compatibility is not
> enough.

Both cards use the same 512-bit bus, 28 Gbps GDDR7 signalling (GB202 die), so
stock nvidia-smi memory clock reads the same on both: **14001 MHz**. What
differs is validated headroom and risk profile:

**RTX 5090** (`oc-memory-5090.sh`) — validated on this card:

| Offset | Effective memory clock | Risk                                        |
| ------ | ---------------------- | ------------------------------------------- |
| 0      | 14001 MHz (stock)      | None                                        |
| +500   | ~14501 MHz             | Very low                                    |
| +1000  | ~15001 MHz             | Low                                         |
| +1500  | ~15501 MHz             | Medium — test thoroughly                    |
| +2000  | ~16001 MHz             | High                                        |
| +2500  | ~16501 MHz             | Very high — validate with long stress tests |
| +3000  | ~17001 MHz             | Extreme — may be unstable on many cards     |

> Reported working on one sample: **RTX 5090 MSI Vanguard** at +2500 and +3000.

**RTX PRO 6000** (`oc-memory-pro6000.sh`) — **not yet validated**:

| Offset | Effective memory clock | Risk                                                                               |
| ------ | ---------------------- | ---------------------------------------------------------------------------------- |
| 0      | 14001 MHz (stock)      | None                                                                               |
| +250   | ~14251 MHz             | Unknown — untested, very conservative start                                        |
| +500   | ~14501 MHz             | Unknown — untested                                                                 |
| +750   | ~14751 MHz             | Unknown — untested                                                                 |
| +1000+ | —                      | Blocked above +1500 by the script's safety cap until a stable point is established |

This card has **ECC-capable memory** and denser, clamshell-mounted modules
(96 GB vs. 32 GB), which typically means less OC headroom than a gaming
card. ECC is currently **disabled** on this install (see
`./nvidia-settings/ecc-pro6000.sh status`) — with it off there's neither an
error counter nor a correction layer, so an unstable offset risks silent
data corruption in compute results rather than an obvious crash or visual
artifact. If you re-enable ECC (`ecc-pro6000.sh on`, then reboot), corrected
single-bit errors get counted instead of silently landing in your data — see
the [Stability Testing](#stability-testing) section below — but uncorrected
multi-bit errors can still slip through unnoticed either way. Increase in
small steps and validate against known-good workload output, not just
uptime.

> **Note:** GDDR7 uses PAM4 signalling. Small offsets can yield meaningfully
> higher bandwidth. If you see visual artifacts, GPU resets, incorrect
> compute results, or crashes → reduce the offset.

---

## Power Limit

> **Superseded.** `lact cli -g <id> power-limit set <W>` does the same thing and
> persists it to `/etc/lact/config.yaml` across reboots. The board constants below
> are still accurate and worth reading.

Max is **600 W** on both cards via `nvidia-smi -pl`, but the stock/default
value and board minimum differ (RTX 5090: 400–600 W; RTX PRO 6000: 150–600 W,
confirmed live on the installed card):

| Card         | Command                          | Watts | Notes                                                                                    |
| ------------ | -------------------------------- | ----- | ---------------------------------------------------------------------------------------- |
| RTX 5090     | `power-limit-5090.sh status`     | —     | Read current limits (no sudo)                                                            |
| RTX 5090     | `power-limit-5090.sh default`    | 575 W | Stock TDP, best performance/cooling balance                                              |
| RTX 5090     | `power-limit-5090.sh max`        | 600 W | +4% headroom over default (partner-card OEM headroom)                                    |
| RTX 5090     | `power-limit-5090.sh 500`        | 500 W | Daily default profile used on this card                                                  |
| RTX 5090     | `power-limit-5090.sh min`        | 400 W | Board minimum                                                                            |
| RTX PRO 6000 | `power-limit-pro6000.sh status`  | —     | Read current limits (no sudo)                                                            |
| RTX PRO 6000 | `power-limit-pro6000.sh default` | 600 W | Stock TGP (Workstation Edition — no extra headroom above stock)                          |
| RTX PRO 6000 | `power-limit-pro6000.sh max`     | 600 W | Same as default on this edition                                                          |
| RTX PRO 6000 | `power-limit-pro6000.sh min`     | 150 W | Board minimum (confirmed via `nvidia-smi power.min_limit` on a Workstation Edition card) |

> Power limit changes take effect immediately and persist until the next driver unload or reboot.
> To make a limit persistent, add the relevant `power-limit-*.sh` call to a boot-time service (see below).

---

## Stability Testing

After applying an offset, stress-test before committing to it:

```bash
# Simple VRAM bandwidth test (requires cuda-samples or pytorch)
python3 -c "
import torch, time
a = torch.randn(8192, 8192, device='cuda')
b = torch.randn(8192, 8192, device='cuda')
torch.cuda.synchronize()
t = time.time()
for _ in range(200):
    c = a @ b
torch.cuda.synchronize()
print(f'Matmul throughput test: {200/(time.time()-t):.1f} iter/s')
"

# Or use gpu-burn (install separately)
# gpu-burn 120   # 2-minute stress test
```

Watch `./monitor.sh` in a second terminal for temperature spikes or
ECC error counts climbing. **On the RTX PRO 6000**, a rising corrected-ECC
count is a signal to back off the memory offset even if nothing has crashed —
correction means the offset is already causing bit errors, just ones the
memory can still fix.

This only works while ECC is **enabled** — it's currently disabled on this
install, so `monitor.sh` will just show `[N/A]` for both counters and give
you no early warning at all. Turn it on for OC testing sessions with
`./nvidia-settings/ecc-pro6000.sh on` (then reboot — the mode change is
pending until the GPU resets), and back off with `off` afterward if you'd
rather not keep the small VRAM/bandwidth overhead ECC carries day to day.

---

## Making the Overclock Persistent on Boot

> **Superseded.** LACT applies its own config at boot with no extra unit needed,
> and unlike this approach it also re-applies after resume from sleep. The service
> below will fight `lactd` if both are active.

Create a systemd service that re-applies the offset after each login. Point
`ExecStart` at the script suffix matching your card.

```bash
# /etc/systemd/system/gpu-oc.service
[Unit]
Description=GPU Memory Overclock
After=graphical.target

[Service]
Type=oneshot
Environment=DISPLAY=:0
ExecStart=/home/matt/development/nvidia-tuning-toolkit/nvidia-settings/oc-memory-pro6000.sh 250
RemainAfterExit=yes

[Install]
WantedBy=graphical.target
```

```bash
sudo systemctl enable --now gpu-oc.service
```

(For the RTX 5090, swap the `ExecStart` line for
`nvidia-settings/oc-memory-5090.sh 2500`.)

---

## Wayland-friendly method: nvidia-tuner

If you prefer `nvidia-tuner` (works well on Wayland), current daily-driver presets:

```bash
# RTX PRO 6000 (unvalidated starting point)
nvidia-tuner --core-clock-offset -50 --memory-clock-offset 500 --power-limit 500

# RTX 5090 (validated on this card)
nvidia-tuner --core-clock-offset -125 --memory-clock-offset 2500 --power-limit 500
```

### Install `nvidia-tuner`

```bash
# Download latest release binary
curl -fL https://github.com/WickedLukas/nvidia-tuner/releases/latest/download/nvidia-tuner -o nvidia-tuner

# Install system-wide
sudo install -m 0755 nvidia-tuner /usr/local/bin/nvidia-tuner

# Verify
nvidia-tuner --help
```

> On this machine `nvidia-tuner` actually ended up in `~/.local/bin` (not
> `/usr/local/bin`) — check `which nvidia-tuner` before copying any systemd
> unit below, and fix the `Environment=PATH=...` / `ExecStart=` line if your
> location differs.

### Make preset persistent after reboot (systemd)

> **Conflicts with LACT.** If `lactd` is running, it will overwrite whatever this
> unit applies roughly 0.4 s later, while the unit still reports success. Use one
> or the other, never both — see [Two gotchas worth knowing](#two-gotchas-worth-knowing).

**Currently provided: RTX PRO 6000 low-power profile, enabled at boot.**
[`systemd/nvidia-tuner-low-power-pro6000.service`](systemd/nvidia-tuner-low-power-pro6000.service)
in this repo runs `nvidia-tuner/apply-low-power-pro6000.sh` (core `-75`,
memory `+1000`, power `300 W`) as a `oneshot` service on every boot, targeting
`multi-user.target` so it doesn't wait on a display session. Install it with:

```bash
sudo cp systemd/nvidia-tuner-low-power-pro6000.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now nvidia-tuner-low-power-pro6000.service
```

Then verify it actually applied (don't just trust "active (exited)" —
confirm the clocks/power actually changed):

```bash
systemctl status nvidia-tuner-low-power-pro6000.service
sudo journalctl -u nvidia-tuner-low-power-pro6000.service -n 50 --no-pager
nvidia-smi --query-gpu=power.limit,clocks.current.graphics,clocks.current.memory --format=csv,noheader
```

> **Unverified in this session:** installing/enabling this service requires
> `sudo`, which needs interactive authentication — something only you can do
> from a real terminal, not something run through this toolkit's automation.
> The `ExecStart` command itself also wasn't dry-run as root here for the
> same reason. It follows the exact pattern already used by nvidia-tuner
> services elsewhere in this repo (root-run `oneshot`, no manual `sudo`
> prefix needed since the service already runs privileged), but if
> `systemctl status` shows a failure after enabling, check the journal output
> above first — it will show whether `nvidia-tuner` itself rejected something
> (e.g. a stale `PATH`) rather than a driver/hardware issue.

To disable it later:

```bash
sudo systemctl disable --now nvidia-tuner-low-power-pro6000.service
```

**Other profiles / a different card:** to persist any other
`apply-*.sh` script instead, copy the unit above, change `ExecStart` to point
at the script you want (or inline the `nvidia-tuner` flags directly), and
give it a distinct filename/`Description` so it doesn't collide with the
low-power one:

```ini
[Unit]
Description=NVIDIA tuner preset
After=multi-user.target
Wants=multi-user.target

[Service]
Type=oneshot
ExecStart=/home/matt/development/nvidia-tuning-toolkit/nvidia-tuner/apply-balanced-pro6000.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

### Undervolt profiles (Linux / `nvidia-tuner`)

These profiles trade a deeper core undervolt and lower power limit for efficiency
while keeping a memory overclock. Going down each table lowers the power limit
and increases the memory offset.

**RTX 5090** — all values validated on this card (MSI Vanguard); test for
stability on your own hardware before relying on them:

| Profile        | Core offset | Memory offset | Power limit |
| -------------- | ----------- | ------------- | ----------- |
| Balanced       | `-75`       | `+2500`       | `500 W`     |
| Efficient      | `-125`      | `+2500`       | `450 W`     |
| Max efficiency | `-125`      | `+3000`       | `400 W`     |

```bash
./nvidia-tuner/apply-balanced-5090.sh
./nvidia-tuner/apply-efficient-5090.sh
./nvidia-tuner/apply-max-efficiency-5090.sh
```

**RTX PRO 6000** — **unvalidated starting points** (no headroom data yet, and
ECC memory raises the cost of guessing wrong):

> The memory offsets here have been raised over time and `balanced` now sits at
> `+2000`, well past the `+1500` safety cap that `nvidia-settings/oc-memory-pro6000.sh`
> enforces on the other code path. Nothing validates these numbers — treat them as
> someone's working guesses, not tested values, and re-read the ECC warning above
> before trusting compute output produced under them.

| Profile        | Core offset | Memory offset | Power limit |
| -------------- | ----------- | ------------- | ----------- |
| Balanced       | `-75`       | `+2000`       | `500 W`     |
| Efficient      | `-75`       | `+1000`       | `450 W`     |
| Max efficiency | `-75`       | `+1000`       | `400 W`     |
| Low power      | `-75`       | `+1000`       | `300 W`     |

```bash
./nvidia-tuner/apply-balanced-pro6000.sh
./nvidia-tuner/apply-efficient-pro6000.sh
./nvidia-tuner/apply-max-efficiency-pro6000.sh
./nvidia-tuner/apply-low-power-pro6000.sh
```

If a profile is unstable on your card, lower the memory offset in `-250` steps
and re-test.

---

## Files

Legend: **[active]** = still the recommended tool · **[superseded]** = works, but LACT does it better

```
nvidia-tuning-toolkit/
├── install-driver.sh                    # [active]     Driver + CUDA bootstrap (NVIDIA open driver + Secure Boot) — either card
├── monitor.sh                           # [active]     Live GPU stats + ECC error counters (1s refresh) — LACT has no ECC counters
├── nvidia-settings/
│   ├── ecc-pro6000.sh                   # [active]     RTX PRO 6000: check/toggle ECC mode (pending until GPU reset) — LACT has no ECC support
│   ├── install.sh                        # [superseded] One-shot setup (Coolbits + permissions) — LACT uses NVML, needs no Coolbits
│   ├── config/
│   │   └── 10-coolbits.conf             # [superseded] xorg.conf.d snippet — unlock OC controls (Xorg only)
│   ├── power-limit-5090.sh              # [superseded] RTX 5090: set GPU power limit (400–600 W) — use `lact cli power-limit set`
│   ├── power-limit-pro6000.sh           # [superseded] RTX PRO 6000: set GPU power limit (150–600 W) — use `lact cli power-limit set`
│   ├── oc-memory-5090.sh                # [superseded] RTX 5090: apply memory transfer-rate offset — use LACT GUI
│   ├── oc-memory-pro6000.sh             # [superseded] RTX PRO 6000: apply memory transfer-rate offset (conservative cap)
│   ├── oc-reset-5090.sh                 # [superseded] RTX 5090: reset offset to stock (0)
│   └── oc-reset-pro6000.sh              # [superseded] RTX PRO 6000: reset offset to stock (0)
├── nvidia-tuner/                        # [superseded] all presets below — use LACT profiles instead
│   ├── apply-default-5090.sh            # RTX 5090: stock clocks, max power (0 core, 0 mem, 600 W)
│   ├── apply-default-pro6000.sh         # RTX PRO 6000: stock clocks, max power (0 core, 0 mem, 600 W)
│   ├── apply-balanced-5090.sh           # RTX 5090: -75 core, +2500 mem, 500 W (validated)
│   ├── apply-balanced-pro6000.sh        # RTX PRO 6000: -75 core, +2000 mem, 500 W (unvalidated)
│   ├── apply-efficient-5090.sh          # RTX 5090: -125 core, +2500 mem, 450 W (validated)
│   ├── apply-efficient-pro6000.sh       # RTX PRO 6000: -75 core, +1000 mem, 450 W (unvalidated)
│   ├── apply-max-efficiency-5090.sh     # RTX 5090: -125 core, +3000 mem, 400 W (validated)
│   ├── apply-max-efficiency-pro6000.sh  # RTX PRO 6000: -75 core, +1000 mem, 400 W (unvalidated)
│   └── apply-low-power-pro6000.sh       # RTX PRO 6000: -75 core, +1000 mem, 300 W (unvalidated clock offsets; wattage confirmed in-range)
└── systemd/
    └── nvidia-tuner-low-power-pro6000.service  # [superseded] Boot unit — CONFLICTS with lactd, see "Two gotchas worth knowing"
```

## Troubleshooting

| Symptom                                                                     | Likely cause                                                                                   | Fix                                                                                                                                             |
| --------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `No targets match 'gpu:0'`                                                  | Wayland/Xwayland session or Coolbits not active                                                | Log into an Xorg session, then restart display manager after installing config                                                                  |
| Screen goes black / GPU reset                                               | Offset too high                                                                                | Run the matching `oc-reset-*.sh` from a TTY (`Ctrl+Alt+F2`)                                                                                     |
| `nvidia-settings` not found                                                 | Package missing                                                                                | `sudo apt install nvidia-settings`                                                                                                              |
| Offset applied but clock unchanged                                          | Driver ignoring offset at idle                                                                 | Run a GPU load first                                                                                                                            |
| Coolbits installed but OC controls still missing                            | Wrong `BusID` in `10-coolbits.conf`                                                            | Run `lspci \| grep -i nvidia`, convert the address to `PCI:bus:device:function`, and update the `BusID` line (or omit it on single-GPU systems) |
| Ran the wrong `-5090` / `-pro6000` script for your card                     | Script targets a different GPU's tuned defaults                                                | Check `nvidia-smi --query-gpu=name --format=csv,noheader` and use the matching suffix; power-limit/OC values are model-specific                 |
| RTX PRO 6000: `power-limit-pro6000.sh` rejects a value you expected to work | Constants assume Workstation Edition (600 W); you may have Max-Q (300 W) or Server (450–600 W) | Run `power-limit-pro6000.sh status` and edit `LIMIT_DEFAULT`/`LIMIT_MAX`/`LIMIT_MIN` in the script to match your edition                        |
| Tuning silently reverts to stock a moment after boot                        | `lactd` is running and resets any GPU it has no config entry for                                | Don't run both. Put the values in `/etc/lact/config.yaml`, then `sudo systemctl disable --now nvidia-tuner-*.service`. Verify with `journalctl -b \| grep 'initialized nvidia controller'` |
| LACT settings lost after adding/moving a GPU                                | LACT config keys are PCI-address-based; the bus got renumbered                                  | Re-apply the setting in LACT; the new key is written to `/etc/lact/config.yaml` automatically                                                    |
| `lact cli` has no command for clock offsets                                 | Not a bug — the CLI only exposes `list`/`info`/`stats`/`snapshot`/`power-limit`/`profile`       | Set offsets in `lact gui`, save them as a profile, then switch non-interactively with `lact cli profile set <name>`                              |

---

## License

[MIT](LICENSE) © 2026 Daimonion

**Read this before running anything here.** These scripts change GPU power
limits and apply core/memory clock offsets. That can destabilise hardware, and
with ECC disabled — the current state of this install — an unstable memory
offset can silently corrupt compute results without ever crashing or producing
a visible artifact. The RTX PRO 6000 profiles in particular are **unvalidated
guesses, not tested values**. The MIT licence says this in legal terms: the
software is provided *"as is", without warranty of any kind*, and the authors
are not liable for any damages arising from its use. Validate any profile
against known-good workload output before trusting it.

Only the code in this repository is covered. [LACT](https://github.com/ilya-zlobintsev/LACT)
and [`nvidia-tuner`](https://github.com/WickedLukas/nvidia-tuner) are separate
upstream projects under their own licences — neither is vendored here, both are
installed from their own releases.
