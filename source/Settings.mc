//
// Settings.mc
//
// User-configurable settings plus the tuning constants that drive shot
// detection. Persisted to the application object store (Storage) so they
// survive between sessions.
//
import Toybox.Lang;
import Toybox.Application.Storage;

// Course-of-fire presets. Each has a fixed expected round count that is used
// later to calibrate shot-detection accuracy. DRILL_UNSTRUCTURED has no fixed
// count (0) and lets the shooter run any string freely.
enum Drill {
    DRILL_BILL           = 0,   // Bill Drill          – 6 rounds
    DRILL_MOZAMBIQUE     = 1,   // Mozambique Drill    – 3 rounds (2 body + 1 head)
    DRILL_ONE_RELOAD_ONE = 2,   // 1-Reload-1          – 2 rounds
    DRILL_EL_PREZ        = 3,   // El Presidente       – 12 rounds
    DRILL_UNSTRUCTURED   = 4    // Unstructured / open – no fixed count
}

// Number of values in the Drill enum (used for cycling in the menu).
const DRILL_COUNT as Number = 5;

// Behavior of the delay between pressing START and the start beep.
enum DelayMode {
    DELAY_INSTANT = 0,
    DELAY_FIXED   = 1,  // fixed 3 s
    DELAY_RANDOM  = 2   // random 2-4 s (par-timer style "stand by ... beep")
}

class Settings {

    // Storage keys
    private const KEY_DRILL   as String = "drill";
    private const KEY_DELAY   as String = "delayMode";
    private const KEY_PAR_ON  as String = "parEnabled";
    private const KEY_PAR_SEC as String = "parSeconds";

    public var drill      as Drill     = DRILL_UNSTRUCTURED;
    public var delayMode  as DelayMode = DELAY_RANDOM;
    public var parEnabled as Boolean   = false;
    public var parSeconds as Float     = 3.0;

    function initialize() {
    }

    // ---- Persistence -------------------------------------------------------

    function load() as Void {
        var v;
        v = Storage.getValue(KEY_DRILL);
        if (v != null) { drill = v as Drill; }
        v = Storage.getValue(KEY_DELAY);
        if (v != null) { delayMode = v as DelayMode; }
        v = Storage.getValue(KEY_PAR_ON);
        if (v != null) { parEnabled = v as Boolean; }
        v = Storage.getValue(KEY_PAR_SEC);
        if (v != null) { parSeconds = v as Float; }
    }

    function save() as Void {
        Storage.setValue(KEY_DRILL,   drill);
        Storage.setValue(KEY_DELAY,   delayMode);
        Storage.setValue(KEY_PAR_ON,  parEnabled);
        Storage.setValue(KEY_PAR_SEC, parSeconds);
    }

    // ---- Drill metadata ----------------------------------------------------

    // Expected round count for the selected drill.  Returns 0 for
    // DRILL_UNSTRUCTURED (no fixed count).  Callers can use 0 to mean
    // "unconstrained" when calibrating detection accuracy.
    function getDrillExpectedRounds() as Number {
        switch (drill) {
            case DRILL_BILL:            return 6;
            case DRILL_MOZAMBIQUE:      return 3;
            case DRILL_ONE_RELOAD_ONE:  return 2;
            case DRILL_EL_PREZ:         return 12;
            case DRILL_UNSTRUCTURED:
            default:                    return 0;
        }
    }

    // ---- Fixed detection tuning --------------------------------------------
    // Sensitivity is no longer user-configurable; these constants represent
    // the "medium" preset that suits typical centerfire pistol recoil.

    function getThresholdMilliG() as Number { return 3000; }
    function getRefractoryMs()    as Number { return 110;  }

    // ---- Derived delay -----------------------------------------------------

    function computeStartDelayMs() as Number {
        switch (delayMode) {
            case DELAY_INSTANT: return 0;
            case DELAY_FIXED:   return 3000;
            case DELAY_RANDOM:
            default:
                return 2000 + (Toybox.Math.rand() % 2001);
        }
    }
}
