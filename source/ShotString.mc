//
// ShotString.mc
//
// Model for a single recorded "string" of fire. Stores each shot's time in
// milliseconds relative to the start beep (time 0). Splits are derived: the
// first shot's split is its time from the beep (the draw / first-shot time),
// and every subsequent split is the gap from the previous shot.
//
import Toybox.Lang;

class ShotString {

    // Shot times in ms from the start beep, in chronological order.
    private var _times as Array<Number>;

    function initialize() {
        _times = [] as Array<Number>;
    }

    function reset() as Void {
        _times = [] as Array<Number>;
    }

    function addShot(timeMs as Number) as Void {
        _times.add(timeMs);
    }

    function count() as Number {
        return _times.size();
    }

    function isEmpty() as Boolean {
        return _times.size() == 0;
    }

    // Time of shot at index i (0-based) in ms from the beep.
    function timeAt(i as Number) as Number {
        return _times[i];
    }

    // Split for shot at index i in ms: time-from-beep for the first shot,
    // otherwise the gap from the previous shot.
    function splitAt(i as Number) as Number {
        if (i <= 0) {
            return _times[0];
        }
        return _times[i] - _times[i - 1];
    }

    // Total time of the string (last shot time from the beep), or 0 if empty.
    function totalMs() as Number {
        if (_times.size() == 0) {
            return 0;
        }
        return _times[_times.size() - 1];
    }

    // First-shot (draw) time in ms, or null if no shots.
    function firstShotMs() as Number? {
        if (_times.size() == 0) {
            return null;
        }
        return _times[0];
    }

    // Most recent split in ms, or null if no shots.
    function lastSplitMs() as Number? {
        var n = _times.size();
        if (n == 0) {
            return null;
        }
        return splitAt(n - 1);
    }
}
