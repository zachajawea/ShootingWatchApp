//
// Settings.mc
//
// User-configurable settings plus the tuning constants that drive shot
// detection. Persisted to the application object store (Storage) so they
// survive between sessions.
//
import Toybox.Lang;
import Toybox.Application.Storage;

// Sensitivity presets. Each maps to an acceleration-magnitude threshold (in
// milli-G, where rest == ~1000 because of gravity) and a refractory/debounce
// window (ms) that suppresses the recoil's oscillation tail so one shot is
// counted once.
enum Sensitivity {
    SENS_HIGH = 0,   // light recoil (e.g. rimfire / .22) - most sensitive
    SENS_MEDIUM = 1, // typical centerfire pistol (9mm / .40)
    SENS_LOW = 2     // heavy recoil only - fewest false positives
}

// Behavior of the delay between pressing START and the start beep.
enum DelayMode {
    DELAY_INSTANT = 0,
    DELAY_FIXED = 1,   // fixed 3 s
    DELAY_RANDOM = 2   // random 2-4 s (par-timer style "stand by ... beep")
}

class Settings {

    // Storage keys
    private const KEY_SENS as String = "sensitivity";
    private const KEY_DELAY as String = "delayMode";
    private const KEY_PAR_ON as String = "parEnabled";
    private const KEY_PAR_SEC as String = "parSeconds";

    public var sensitivity as Sensitivity = SENS_MEDIUM;
    public var delayMode as DelayMode = DELAY_RANDOM;
    public var parEnabled as Boolean = false;
    public var parSeconds as Float = 3.0;

    function initialize() {
    }

    // ---- Persistence -------------------------------------------------------

    function load() as Void {
        var v;
        v = Storage.getValue(KEY_SENS);
        if (v != null) { sensitivity = v as Sensitivity; }
        v = Storage.getValue(KEY_DELAY);
        if (v != null) { delayMode = v as DelayMode; }
        v = Storage.getValue(KEY_PAR_ON);
        if (v != null) { parEnabled = v as Boolean; }
        v = Storage.getValue(KEY_PAR_SEC);
        if (v != null) { parSeconds = v as Float; }
    }

    function save() as Void {
        Storage.setValue(KEY_SENS, sensitivity);
        Storage.setValue(KEY_DELAY, delayMode);
        Storage.setValue(KEY_PAR_ON, parEnabled);
        Storage.setValue(KEY_PAR_SEC, parSeconds);
    }

    // ---- Derived detection tuning -----------------------------------------

    // Acceleration-magnitude threshold in milli-G for the current sensitivity.
    function getThresholdMilliG() as Number {
        switch (sensitivity) {
            case SENS_HIGH:   return 2200;
            case SENS_LOW:    return 4200;
            case SENS_MEDIUM:
            default:          return 3000;
        }
    }

    // Debounce window in ms between two distinct shots for the current
    // sensitivity. Tighter when more sensitive so fast splits still register.
    function getRefractoryMs() as Number {
        switch (sensitivity) {
            case SENS_HIGH:   return 90;
            case SENS_LOW:    return 130;
            case SENS_MEDIUM:
            default:          return 110;
        }
    }

    // Delay (ms) before the start beep, given the configured mode.
    function computeStartDelayMs() as Number {
        switch (delayMode) {
            case DELAY_INSTANT: return 0;
            case DELAY_FIXED:   return 3000;
            case DELAY_RANDOM:
            default:
                // 2000-4000 ms inclusive-ish: Math.rand() returns a non-negative
                // Number; take it modulo the 2001 ms span and offset by 2000.
                return 2000 + (Toybox.Math.rand() % 2001);
        }
    }
}
