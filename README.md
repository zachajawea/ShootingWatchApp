# Shooting Watch App (Connect IQ / Monkey C)

A wrist-worn **shot timer** for competition shooters. It plays a start beep,
then uses the Garmin watch's **accelerometer** to detect each shot's recoil and
records the time of every shot relative to the beep — giving you your draw /
first-shot time, every split, and the total string time.

This is a standard Connect IQ `watch-app`. The detection logic lives in
`source/ShotDetector.mc`; everything else is UI/state/persistence.

---

## How shot detection works

A gunshot's recoil is a brief, large spike in acceleration. The app:

1. Subscribes to **high-frequency batched accelerometer data** via
   `Toybox.Sensor.registerSensorDataListener` at the device's maximum sample
   rate (from `getMaxSampleRateForSensorType(:accelerometer)`, commonly 25 Hz).
   The 1 Hz `Sensor.getInfo` / `enableSensorEvents` path is far too slow to
   catch a recoil impulse, so it is **not** used.
2. Computes each sample's **acceleration magnitude** `sqrt(x² + y² + z²)` in
   milli-G (rest ≈ 1000 milli-G because of gravity).
3. Flags a shot when the magnitude crosses a **sensitivity threshold**, then
   applies a **refractory window** so the recoil's oscillation tail isn't
   double-counted.
4. Timestamps each shot from the accelerometer's **per-sample `timestamp`
   array** (ms). Time 0 is the first sample after the beep, so splits are exact
   differences of sample timestamps regardless of how batches are buffered.

### Sensitivity presets (`source/Settings.mc`)

| Preset | Threshold | Refractory | Intended use |
|--------|-----------|-----------|--------------|
| High   | 2200 mG   | 90 ms     | light recoil (rimfire / .22) |
| Medium | 3000 mG   | 110 ms    | typical centerfire pistol (9mm / .40) |
| Low    | 4200 mG   | 130 ms    | heavy recoil only, fewest false positives |

Tune these to your firearm and how the watch is worn. Strong-hand wrist mounting
gives the cleanest recoil signal.

---

## Controls

| Screen | START / Select | BACK | MENU | Up / Down |
|--------|----------------|------|------|-----------|
| Ready   | Begin string (stand-by → beep) | Exit app | Open Settings | — |
| Stand-by| Cancel | Cancel | — | — |
| Running | Stop string | Stop string | — | — |
| Review  | New string | New string | — | Scroll splits |

## Settings

- **Sensitivity** — Low / Medium / High (see table above)
- **Start Delay** — Instant / Fixed 3 s / Random 2–4 s (random = standard
  "stand by … *beep*" par-timer behavior)
- **Par Time** — on/off plus a configurable par in seconds; a distinct double
  beep fires at par so you can train to a time standard

Settings persist between sessions via the application object store
(`Application.Storage`).

---

## Building & running

You need the **Connect IQ SDK** and a generated developer key.

**VS Code (recommended):** install the *Monkey C* extension, open this folder,
then **Connect IQ: Build Current Project** / **Run** (launches the simulator).

**Command line:**

```bash
# Compile for a specific device (e.g. fenix7) into a runnable .prg
monkeyc -f monkey.jungle -o bin/ShootingTimer.prg -y developer_key.der -d fenix7

# Run in the simulator
connectiq            # start the simulator first
monkeydo bin/ShootingTimer.prg fenix7
```

**Sideload to a watch:** build a `.prg` (or package a `.iq` with
`monkeyc -e`), connect the watch via USB, and copy the `.prg` into
`GARMIN/APPS/` on the device.

> Replace the placeholder `id` UUID in `manifest.xml` with your own before
> store submission, and adjust `<iq:products>` to the devices you target. Every
> listed product must support `Toybox.Sensor.AccelerometerData`.

---

## Precision & limitations (read this)

- **Sample-rate quantization.** Shot/split resolution is bounded by the sensor
  rate. At 25 Hz that's ~40 ms granularity. Fast pistol splits (0.15–0.25 s) are
  resolved but quantized; this is great for training and tracking relative
  improvement, **but it is not a millisecond-accurate acoustic match timer.**
- **Start anchor.** Time 0 is the first accelerometer sample after the beep,
  which can trail the audible beep by up to one sample interval (≤ ~40 ms). This
  is a small, roughly constant offset; splits between shots are unaffected.
- **False positives / misses.** Aggressive movement can read as a shot on High
  sensitivity; very light loads can be missed on Low. Pick the preset that
  matches your gun and confirm against a known string.
- **Hardware.** Requires an accelerometer-capable device and the **Sensor**
  permission (declared in `manifest.xml`). Some watches lack a tone generator;
  the app checks `Attention has :playTone` and falls back to vibration.
- **Safety.** A training aid only. Always follow safe firearm handling and your
  range's rules.

---

## Project layout

```
ShootingTimer/
├── manifest.xml                 # app id, type, Sensor permission, products
├── monkey.jungle                # build config
├── resources/
│   ├── drawables/               # launcher icon + drawables.xml
│   └── strings/strings.xml      # UI strings
└── source/
    ├── ShootingTimerApp.mc      # AppBase: lifecycle, shared Settings
    ├── Settings.mc              # settings + detection tuning + persistence
    ├── ShotString.mc            # model: shot times, splits, totals
    ├── ShotDetector.mc          # accelerometer capture + peak detection
    ├── ShotTimerView.mc         # state machine, rendering, tones
    ├── ShotTimerDelegate.mc     # input → view actions
    └── SettingsMenu.mc          # Menu2 settings UI
```
