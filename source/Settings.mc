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

// ---- Ballistic / firearm-profile bounds --------------------------------------
// The on-watch digit editor clamps each variable to [min, max] on save.
// Ranges cover common pistol/rifle loads.

const MUZZLE_MIN_FPS    as Number = 600;    // subsonic pistol floor
const MUZZLE_MAX_FPS    as Number = 3300;   // centerfire rifle ceiling

const BULLET_MIN_GR     as Number = 30;     // light rimfire
const BULLET_MAX_GR     as Number = 300;    // heavy magnum / rifle

const FIREARM_MIN_OZ    as Number = 12;     // pocket pistol
const FIREARM_MAX_OZ    as Number = 160;    // heavy rifle (10 lb)

class Settings {

    // Storage keys
    private const KEY_DRILL    as String = "drill";
    private const KEY_DELAY    as String = "delayMode";
    private const KEY_PAR_ON   as String = "parEnabled";
    private const KEY_PAR_SEC  as String = "parSeconds";
    private const KEY_FIT      as String = "recordFit";
    private const KEY_MUZZLE   as String = "muzzleVelocityFps";
    private const KEY_BULLET   as String = "bulletWeightGr";
    private const KEY_FIREARM  as String = "firearmWeightOz";

    public var drill      as Drill     = DRILL_UNSTRUCTURED;
    public var delayMode  as DelayMode = DELAY_RANDOM;
    public var parEnabled as Boolean   = false;
    public var parSeconds as Float     = 3.0;
    // Export each string as a Garmin Connect .FIT activity. On by default; the
    // export is silently skipped on devices that can't record activities.
    public var recordFit  as Boolean   = true;

    // Firearm / ammunition profile. Together these describe the recoil impulse
    // a shot produces, which drives the accelerometer detection tuning (see
    // getThresholdMilliG / getRefractoryMs). Defaults describe a typical 9mm
    // service-pistol load (124 gr at ~1150 fps from a ~30 oz pistol).
    public var muzzleVelocityFps as Number = 1150;  // bullet muzzle velocity, fps
    public var bulletWeightGr    as Number = 124;   // bullet weight, grains
    public var firearmWeightOz   as Number = 30;    // total firearm weight, oz

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
        v = Storage.getValue(KEY_FIT);
        if (v != null) { recordFit = v as Boolean; }
        v = Storage.getValue(KEY_MUZZLE);
        if (v != null) { muzzleVelocityFps = v as Number; }
        v = Storage.getValue(KEY_BULLET);
        if (v != null) { bulletWeightGr = v as Number; }
        v = Storage.getValue(KEY_FIREARM);
        if (v != null) { firearmWeightOz = v as Number; }
    }

    function save() as Void {
        Storage.setValue(KEY_DRILL,    drill);
        Storage.setValue(KEY_DELAY,    delayMode);
        Storage.setValue(KEY_PAR_ON,   parEnabled);
        Storage.setValue(KEY_PAR_SEC,  parSeconds);
        Storage.setValue(KEY_FIT,      recordFit);
        Storage.setValue(KEY_MUZZLE,   muzzleVelocityFps);
        Storage.setValue(KEY_BULLET,   bulletWeightGr);
        Storage.setValue(KEY_FIREARM,  firearmWeightOz);
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

    // ---- Recoil-derived detection tuning -----------------------------------
    //
    // Instead of a fixed sensitivity preset, the detection threshold and
    // refractory window are derived from the firearm/ammunition profile. The
    // physical driver is the shot's free-recoil energy, which is what produces
    // the acceleration spike at the wrist and governs how long the recoil rings
    // before settling.
    //
    //   * A bigger recoil impulse (heavy bullet, high velocity, light gun)
    //     produces a larger, cleaner spike, so the threshold can be raised to
    //     reject false positives, and the refractory window lengthened to span
    //     the longer oscillation tail.
    //   * A small recoil impulse (light rimfire load, heavy gun) produces a
    //     faint spike, so the threshold is lowered to avoid missing shots, and
    //     the refractory window shortened so fast splits aren't merged.
    //
    // The mapping is anchored to the previously hand-tuned presets:
    //   ~0.4 ft·lbf (.22 rimfire)     -> 2200 mG / 90 ms   (was "High")
    //   ~3.4 ft·lbf (9mm pistol)      -> 3000 mG / 110 ms  (was "Medium")
    //   ~11  ft·lbf (.44 Mag and up)  -> 4200 mG / 130 ms  (was "Low")

    // Free-recoil energy of the firearm in ft·lbf, from conservation of
    // momentum: the bullet's forward momentum equals the gun's rearward
    // momentum. The powder-charge/gas term is omitted (not collected), which
    // slightly understates magnum/rifle recoil but keeps the profile to the
    // three intuitive inputs.
    function getRecoilEnergy() as Float {
        var gunLb = firearmWeightOz / 16.0;
        if (gunLb < 0.01) { gunLb = 0.01; }  // guard against divide-by-zero
        // Gun recoil velocity (ft/s): m_bullet * v_bullet / m_gun, with grains
        // converted to pounds via the 7000 gr/lb factor.
        var gunVel = (bulletWeightGr.toFloat() * muzzleVelocityFps)
            / (7000.0 * gunLb);
        // E = 0.5 * m * v^2; mass = weight(lb) / g, g = 32.174 ft/s^2, so the
        // 0.5/g constant is 1 / 64.348.
        return (gunLb * gunVel * gunVel) / 64.348;
    }

    function getThresholdMilliG() as Number {
        var e = getRecoilEnergy();
        if (e <= 0.4)  { return 2200; }
        if (e <= 3.4)  { return interp(e, 0.4, 3.4, 2200.0, 3000.0).toNumber(); }
        if (e <= 11.0) { return interp(e, 3.4, 11.0, 3000.0, 4200.0).toNumber(); }
        return 4200;
    }

    function getRefractoryMs() as Number {
        var e = getRecoilEnergy();
        if (e <= 0.4)  { return 90; }
        if (e <= 3.4)  { return interp(e, 0.4, 3.4, 90.0, 110.0).toNumber(); }
        if (e <= 11.0) { return interp(e, 3.4, 11.0, 110.0, 130.0).toNumber(); }
        return 130;
    }

    // Linear interpolation of v0..v1 as e moves across e0..e1.
    private function interp(e as Float, e0 as Float, e1 as Float,
            v0 as Float, v1 as Float) as Float {
        return v0 + (e - e0) * (v1 - v0) / (e1 - e0);
    }

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
