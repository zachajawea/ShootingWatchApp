//
// FitRecorder.mc
//
// Writes each shooting string to a Garmin .FIT activity file so it syncs to
// Garmin Connect (and Connect's web/app analysis tools) the next time the watch
// syncs. This turns the on-watch split list into a permanent, shareable record.
//
// FIT mapping
// -----------
//   * One ActivityRecording session  == one string of fire. The session name
//     is the selected course-of-fire so strings are easy to tell apart in
//     Garmin Connect.
//   * One FIT lap == one shot. Each shot's lap carries two custom developer
//     fields (Toybox.FitContributor):
//         shot_time (s) – time of the shot from the start beep
//         split     (s) – gap from the previous shot (== shot_time for shot 1)
//     These developer fields hold the *precise* values derived from the
//     accelerometer sample timestamps, so they are accurate even though the
//     native lap timing is only as good as when addLap() happens to fire.
//   * Session-scope developer fields summarise the whole string:
//         shots       – number of shots detected
//         first_shot  (s) – draw / first-shot time
//         total_time  (s) – last-shot time from the beep
//
// Laps are opened just-in-time: the session's initial lap becomes shot 1, and
// every subsequent shot calls addLap() *before* writing its fields. That yields
// exactly one lap per shot with no trailing empty/duplicate lap.
//
// Everything is guarded so the app still runs on devices (or permission setups)
// without activity recording: start() simply returns false and the timer works
// as before, just without the FIT export.
//
import Toybox.Lang;
import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.FitContributor;

class FitRecorder {

    // Stable developer-field ids within this app's FIT developer data.
    private const FIELD_SHOTS      as Number = 0;   // session
    private const FIELD_FIRST_SHOT as Number = 1;   // session
    private const FIELD_TOTAL      as Number = 2;   // session
    private const FIELD_SHOT_TIME  as Number = 3;   // lap
    private const FIELD_SPLIT      as Number = 4;   // lap

    private var _session as ActivityRecording.Session?;
    private var _shotsRecorded as Number = 0;

    private var _fShots    as FitContributor.Field?;
    private var _fFirst    as FitContributor.Field?;
    private var _fTotal    as FitContributor.Field?;
    private var _fShotTime as FitContributor.Field?;
    private var _fSplit    as FitContributor.Field?;

    function initialize() {
    }

    // True when the platform can record FIT activities at all.
    static function isSupported() as Boolean {
        return (Toybox has :ActivityRecording) && (Toybox has :FitContributor);
    }

    // True while a session is open and recording.
    function isActive() as Boolean {
        return _session != null && _session.isRecording();
    }

    // Begin a recording session for one string. `label` is the activity name
    // shown in Garmin Connect. Returns false (and records nothing) when
    // recording is unavailable or could not be started.
    function start(label as String) as Boolean {
        if (!FitRecorder.isSupported()) {
            return false;
        }
        // A leftover session from an abnormal exit must never be reused.
        if (_session != null) {
            discard();
        }

        try {
            _session = ActivityRecording.createSession({
                :name => label,
                :sport => Activity.SPORT_GENERIC,
                :subSport => Activity.SUB_SPORT_GENERIC
            });
            createFields();
            _session.start();
        } catch (e) {
            _session = null;
            return false;
        }

        _shotsRecorded = 0;
        return true;
    }

    private function createFields() as Void {
        var s = _session;
        if (s == null) {
            return;
        }
        _fShots = s.createField("shots", FIELD_SHOTS,
            FitContributor.DATA_TYPE_UINT16,
            { :mesgType => FitContributor.MESG_TYPE_SESSION });
        _fFirst = s.createField("first_shot", FIELD_FIRST_SHOT,
            FitContributor.DATA_TYPE_FLOAT,
            { :mesgType => FitContributor.MESG_TYPE_SESSION, :units => "s" });
        _fTotal = s.createField("total_time", FIELD_TOTAL,
            FitContributor.DATA_TYPE_FLOAT,
            { :mesgType => FitContributor.MESG_TYPE_SESSION, :units => "s" });
        _fShotTime = s.createField("shot_time", FIELD_SHOT_TIME,
            FitContributor.DATA_TYPE_FLOAT,
            { :mesgType => FitContributor.MESG_TYPE_LAP, :units => "s" });
        _fSplit = s.createField("split", FIELD_SPLIT,
            FitContributor.DATA_TYPE_FLOAT,
            { :mesgType => FitContributor.MESG_TYPE_LAP, :units => "s" });
    }

    // Record one shot. `shotTimeMs` is the time from the beep; `splitMs` is the
    // gap from the previous shot (== shotTimeMs for the first shot). Each call
    // becomes one FIT lap carrying the precise values as developer fields.
    function recordShot(shotTimeMs as Number, splitMs as Number) as Void {
        if (_session == null || !_session.isRecording()) {
            return;
        }
        try {
            // Shot 1 reuses the session's initial lap; later shots open a fresh
            // lap first so each lap maps to exactly one shot.
            if (_shotsRecorded > 0) {
                _session.addLap();
            }
            if (_fShotTime != null) {
                _fShotTime.setData(shotTimeMs / 1000.0);
            }
            if (_fSplit != null) {
                _fSplit.setData(splitMs / 1000.0);
            }
            _shotsRecorded++;
        } catch (e) {
            // Out of memory / lap limit reached: keep timing, drop the export.
        }
    }

    // Write the string's summary fields and save the activity so it syncs to
    // Garmin Connect. Safe to call even if no session is open.
    function finish(shotCount as Number, firstShotMs as Number?,
            totalMs as Number) as Void {
        if (_session == null) {
            return;
        }
        try {
            if (_fShots != null) {
                _fShots.setData(shotCount);
            }
            if (_fFirst != null && firstShotMs != null) {
                _fFirst.setData(firstShotMs / 1000.0);
            }
            if (_fTotal != null) {
                _fTotal.setData(totalMs / 1000.0);
            }
            if (_session.isRecording()) {
                _session.stop();
            }
            _session.save();
        } catch (e) {
            // Nothing more we can do; fall through to clear state.
        }
        clear();
    }

    // Throw away the in-progress recording without saving (cancelled string).
    // Safe to call even if no session is open.
    function discard() as Void {
        if (_session == null) {
            return;
        }
        try {
            if (_session.isRecording()) {
                _session.stop();
            }
            _session.discard();
        } catch (e) {
        }
        clear();
    }

    private function clear() as Void {
        _session = null;
        _shotsRecorded = 0;
        _fShots = null;
        _fFirst = null;
        _fTotal = null;
        _fShotTime = null;
        _fSplit = null;
    }
}
