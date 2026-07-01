# Monkey C & Connect IQ — working reference

Distilled from Garmin's official docs (developer.garmin.com/connect-iq/monkey-c/
and the API reference at developer.garmin.com/connect-iq/api-docs/) and applied
in this project. This is the "skill" knowledge the app was built on.

> Note on scraping: the prose guide pages under `/connect-iq/monkey-c/` and
> `/connect-iq/connect-iq-basics/` are JavaScript-rendered single-page-app
> content and return only a navigation shell to a plain HTTP fetch, so they
> cannot be exhaustively scraped that way. The **API reference** (the
> `/api-docs/Toybox/...` pages) is server-rendered and *is* scrapable — that's
> where the authoritative method signatures below come from.

---

## Language essentials

- **Typing:** dynamically typed at runtime, with an optional static type checker
  ("Monkey Types"). Annotate with `as Type`; nullable is `Type?` or `Type or
  Null`. Local variable types are *inferred* — you cannot explicitly type a
  `var` local.
- **Modules / imports:** `import Toybox.WatchUi;` brings a module's symbols into
  scope (`View`, `Menu2`, …). Submodules can be imported too, e.g.
  `import Toybox.Application.Storage;`. The older `using Toybox.X as Y;` form is
  equivalent. Fully-qualified names (`Toybox.Math.rand()`) always work.
- **Classes:** `class Foo extends Bar { function initialize() { Bar.initialize(); } }`.
  Methods are public by default; mark internals `private`. `me`/`self` refer to
  the instance.
- **Symbols:** `:name` literals. Method references for callbacks use
  `method(:onThing)` (bound to the enclosing instance).
- **Containers:** `Array` (`[]`, `.add`, `.size`) and `Dictionary`
  (`{ :key => value }`, `.get`, `.hasKey`). Dictionaries are the idiomatic way
  to pass option bags to APIs.
- **Capability checks:** `if (Module has :symbol)` / `if (obj has :member)` to
  guard optional APIs and device-specific features. Essential for portability.
- **Numbers:** `Number` (32-bit int), `Long`, `Float`, `Double`. `Float`/`Double`
  have `.format("%.2f")`; convert with `.toNumber()` / `.toFloat()`.
- **Enums** are integer-backed; arithmetic and `%` work, cast back with `as`.

---

## App structure (watch-app)

```
AppBase (Application)
  initialize() / onStart(state) / onStop(state)
  getInitialView() -> [View] or [View, InputDelegate]

View (WatchUi)
  initialize() / onLayout(dc) / onShow() / onUpdate(dc) / onHide()

BehaviorDelegate (WatchUi)   // extends InputDelegate
  onSelect()/onBack()/onMenu()/onNextPage()/onPreviousPage()/onKey(evt)
  // return true if the input was consumed
```

- Push/replace screens with `WatchUi.pushView(view, delegate, transition)` and
  `WatchUi.popView(transition)`. Transitions: `SLIDE_UP`, `SLIDE_DOWN`,
  `SLIDE_IMMEDIATE`, …
- Request a redraw with `WatchUi.requestUpdate()` (triggers `onUpdate`).
- Menus: `Menu2` + `Menu2InputDelegate` (`onSelect(item)`, `onBack()`);
  `MenuItem(label, subLabel, id, options)`, `ToggleMenuItem(... , enabled, ...)`.
  Use `item.getId()`, `item.setSubLabel(...)`, `toggle.isEnabled()`.

## Drawing (Graphics.Dc in onUpdate)

```
dc.setColor(fg, bg); dc.clear();
dc.drawText(x, y, font, text, justify);   // TEXT_JUSTIFY_CENTER, …
dc.getWidth(); dc.getHeight(); dc.getFontHeight(font);
```
Fonts: `FONT_XTINY…FONT_LARGE`, numeric `FONT_NUMBER_MILD/MEDIUM/HOT/THAI_HOT`.
Colors: `COLOR_WHITE`, `COLOR_BLACK`, `COLOR_RED`, …, `COLOR_TRANSPARENT`.

## Resources

Defined in XML under `resources/`, referenced in code via the generated `Rez`
namespace and loaded with `WatchUi.loadResource(Rez.Strings.Foo)`. Strings,
drawables (`<bitmap>`), layouts, menus, etc.

## Timers & persistence

- `Timer.Timer().start(method(:cb), milliseconds, repeat as Boolean)` / `.stop()`.
- `System.getTimer()` → monotonic uptime in ms (use for elapsed timing).
- `Application.Storage.getValue(key)` / `setValue(key, value)` — simple
  key/value object store that survives restarts. (`Properties` is the related
  store for Garmin-Connect-editable settings.)

---

## Sensors — the load-bearing API for this app

`Toybox.Sensor` (requires the **Sensor** permission in `manifest.xml`).

**Low frequency (1 Hz):** `enableSensorEvents(method(:onSensor))` → callback gets
a `Sensor.Info`; or poll `Sensor.getInfo()` from a `Timer`. Too slow for recoil.

**High frequency (the right tool):**

```monkeyc
Sensor.registerSensorDataListener(method(:onAccelData), {
    :period => 1,                        // seconds of data per callback (batch)
    :accelerometer => {
        :enabled => true,
        :sampleRate => rate,             // Hz; clamp to device max
        :includeTimestamps => true,      // per-sample ms timestamps
        :includePower => true            // optional vector-magnitude array
    }
});
// ...
Sensor.unregisterSensorDataListener();

var rate = Sensor.getMaxSampleRateForSensorType(:accelerometer); // device cap
```

Callback receives a `Sensor.SensorData`; `data.accelerometerData` is a
`Sensor.AccelerometerData` with **arrays of equal length**:

- `x`, `y`, `z` — `Array<Number>` in **milli-G** (1000 mG = 1 G; rest ≈ 1000)
- `timestamp` — `Array<Number>` in **ms** (when requested)
- `power` — `Array<Number>` vector magnitude in mG (when requested)
- `pitch`, `roll` — `Array<Float>` degrees (when requested)

Any field may be `null` if not requested or unsupported — null-check first.

## Attention — start beep / par beep

`Toybox.Attention` (not on every device → guard with `has`).

```monkeyc
if (Attention has :playTone) {
    var profile = [ new Attention.ToneProfile(freqHz, durMs) ] as Array<Attention.ToneProfile>;
    Attention.playTone({ :toneProfile => profile, :repeatCount => 2 });
    // or a built-in: Attention.playTone(Attention.TONE_START);
}
if (Attention has :vibrate) {
    var v = [ new Attention.VibeProfile(dutyCyclePct, durMs) ] as Array<Attention.VibeProfile>;
    Attention.vibrate(v);
}
```

---

## Activity recording & FIT export

`Toybox.ActivityRecording` + `Toybox.FitContributor` (requires the **Fit**
permission in `manifest.xml`). Produces a `.FIT` activity that syncs to Garmin
Connect. Guard with `Toybox has :ActivityRecording` / `:FitContributor` — not
every product/permission setup supports it.

```monkeyc
var session = ActivityRecording.createSession({
    :name => "Shooting String",
    :sport => Activity.SPORT_GENERIC,        // Activity.SPORT_* / SUB_SPORT_*
    :subSport => Activity.SUB_SPORT_GENERIC
});

// Custom developer fields — create BEFORE save(). mesgType scopes the field to
// the session / lap / record message.
var f = session.createField("split", 4, FitContributor.DATA_TYPE_FLOAT, {
    :mesgType => FitContributor.MESG_TYPE_LAP, :units => "s"
});

session.start();
f.setData(0.18);        // writes to the currently-open lap
session.addLap();       // closes the current lap, opens the next
// ... summary fields then:
session.stop();
session.save();         // or session.discard() to throw the recording away
```

- Data types: `DATA_TYPE_{SINT8,UINT8,SINT16,UINT16,SINT32,UINT32,FLOAT,DOUBLE,STRING}`.
- `addLap()` is the natural FIT construct for per-event splits/segments. To get
  exactly one lap per event with no trailing empty lap, write the first event
  into the session's initial lap and call `addLap()` *before* each subsequent
  event (not after the last one).
- Native lap wall-clock times reflect when `addLap()` actually fired. If your
  events come from a buffered/batched source, prefer carrying the precise value
  in a developer field rather than trusting the native lap duration.

---

## Gotchas encountered / good practices

- Calling several `Sensor`/`WatchUi` functions **crashes data-field apps** — use
  a `watch-app` (this project is one).
- Always `has`-check `Attention`, optional sensor fields, and newer key
  constants before use; devices differ widely.
- For accurate event timing from batched sensor data, derive times from the
  per-sample `timestamp` array, **not** from when the batch callback fires
  (batches are buffered and arrive up to `:period` seconds late).
- Strict type-checking can complain that array literals infer as `Array<Any>`
  when passed to `playTone`/`vibrate`; annotate `as Array<Attention.ToneProfile>`
  / `as Array<Attention.VibeProfile>`.
- Stop timers and unregister sensor listeners in `onHide` so nothing leaks when
  the view is replaced or the app exits.
```
