//
// ShotTimerView.mc
//
// The main screen and controller. Drives a four-state machine:
//
//   READY  -> press START ->  DELAY  -> (beep) ->  RUNNING -> stop -> REVIEW
//     ^                                                                  |
//     +------------------------------ reset ------------------------------+
//
// While DELAY/RUNNING are active a ~50 ms UI timer requests redraws so the
// stand-by countdown and the elapsed clock animate smoothly. The precise shot
// times come from the accelerometer sample timestamps (see ShotDetector), not
// from this UI timer.
//
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Timer;
import Toybox.Attention;

enum TimerState {
    STATE_READY = 0,
    STATE_DELAY = 1,
    STATE_RUNNING = 2,
    STATE_REVIEW = 3
}

class ShotTimerView extends WatchUi.View {

    private var _settings as Settings;
    private var _detector as ShotDetector;
    private var _string as ShotString;

    private var _state as TimerState = STATE_READY;

    private var _startWallMs as Number = 0;   // System.getTimer() at the beep
    private var _delayEndWallMs as Number = 0; // for the stand-by countdown
    private var _sensorError as Boolean = false;
    private var _reviewScroll as Number = 0;

    private var _uiTimer as Timer.Timer?;
    private var _delayTimer as Timer.Timer?;
    private var _parTimer as Timer.Timer?;

    function initialize(settings as Settings) {
        View.initialize();
        _settings = settings;
        _string = new ShotString();
        _detector = new ShotDetector(method(:onShotDetected));
    }

    // ---- View lifecycle ----------------------------------------------------

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
    }

    function onHide() as Void {
        // Leaving the view (e.g. opening settings or exiting): make sure no
        // sensor or timers are left running.
        stopAllTimers();
        if (_detector.isRunning()) {
            _detector.stop();
        }
    }

    // ---- Public actions (invoked by the delegate) --------------------------

    function getState() as TimerState {
        return _state;
    }

    // START / SELECT pressed.
    function onActionSelect() as Void {
        switch (_state) {
            case STATE_READY:   beginString(); break;
            case STATE_DELAY:   cancelToReady(); break;
            case STATE_RUNNING: stopString(); break;
            case STATE_REVIEW:  resetToReady(); break;
        }
    }

    // BACK pressed. Returns true if handled (so the app does not exit).
    function onActionBack() as Boolean {
        switch (_state) {
            case STATE_DELAY:   cancelToReady(); return true;
            case STATE_RUNNING: stopString(); return true;
            case STATE_REVIEW:  resetToReady(); return true;
            case STATE_READY:
            default:            return false; // allow app to exit
        }
    }

    // Scroll the review list. dir is +1 (down) or -1 (up).
    function onActionScroll(dir as Number) as Void {
        if (_state != STATE_REVIEW) {
            return;
        }
        _reviewScroll += dir;
        if (_reviewScroll < 0) {
            _reviewScroll = 0;
        }
        var maxScroll = _string.count() - 1;
        if (maxScroll < 0) { maxScroll = 0; }
        if (_reviewScroll > maxScroll) {
            _reviewScroll = maxScroll;
        }
        WatchUi.requestUpdate();
    }

    // ---- State transitions -------------------------------------------------

    private function beginString() as Void {
        _sensorError = false;
        _string.reset();
        _reviewScroll = 0;

        var delayMs = _settings.computeStartDelayMs();
        if (delayMs <= 0) {
            startRunning();
            return;
        }

        _state = STATE_DELAY;
        _delayEndWallMs = System.getTimer() + delayMs;
        _delayTimer = new Timer.Timer();
        _delayTimer.start(method(:onDelayComplete), delayMs, false);
        startUiTimer();
        WatchUi.requestUpdate();
    }

    // Called when the stand-by delay elapses.
    function onDelayComplete() as Void {
        if (_delayTimer != null) {
            _delayTimer.stop();
            _delayTimer = null;
        }
        startRunning();
    }

    private function startRunning() as Void {
        playStartSignal();
        _startWallMs = System.getTimer();

        var ok = _detector.start(
            _settings.getThresholdMilliG(),
            _settings.getRefractoryMs()
        );
        if (!ok) {
            _sensorError = true;
        }

        _state = STATE_RUNNING;
        startUiTimer();

        // Schedule the par-time beep if enabled.
        if (_settings.parEnabled) {
            var parMs = (_settings.parSeconds * 1000.0).toNumber();
            _parTimer = new Timer.Timer();
            _parTimer.start(method(:onParTime), parMs, false);
        }

        WatchUi.requestUpdate();
    }

    // Par time reached.
    function onParTime() as Void {
        if (_parTimer != null) {
            _parTimer.stop();
            _parTimer = null;
        }
        playParSignal();
    }

    private function stopString() as Void {
        if (_detector.isRunning()) {
            _detector.stop();
        }
        stopAllTimers();
        _state = STATE_REVIEW;
        _reviewScroll = 0;
        WatchUi.requestUpdate();
    }

    private function cancelToReady() as Void {
        if (_detector.isRunning()) {
            _detector.stop();
        }
        stopAllTimers();
        _state = STATE_READY;
        WatchUi.requestUpdate();
    }

    private function resetToReady() as Void {
        _string.reset();
        _state = STATE_READY;
        WatchUi.requestUpdate();
    }

    // Shot detected (called from ShotDetector on the sensor callback).
    function onShotDetected(timeMs as Number) as Void {
        if (_state != STATE_RUNNING) {
            return;
        }
        _string.addShot(timeMs);
        WatchUi.requestUpdate();
    }

    // ---- Timers ------------------------------------------------------------

    private function startUiTimer() as Void {
        if (_uiTimer == null) {
            _uiTimer = new Timer.Timer();
            _uiTimer.start(method(:onUiTick), 50, true);
        }
    }

    private function stopUiTimer() as Void {
        if (_uiTimer != null) {
            _uiTimer.stop();
            _uiTimer = null;
        }
    }

    private function stopAllTimers() as Void {
        stopUiTimer();
        if (_delayTimer != null) {
            _delayTimer.stop();
            _delayTimer = null;
        }
        if (_parTimer != null) {
            _parTimer.stop();
            _parTimer = null;
        }
    }

    // Periodic UI refresh for the live clock / countdown.
    function onUiTick() as Void {
        WatchUi.requestUpdate();
    }

    // ---- Signals -----------------------------------------------------------

    private function playStartSignal() as Void {
        if (Attention has :playTone) {
            if (Attention has :ToneProfile) {
                var profile = [ new Attention.ToneProfile(1800, 400) ]
                    as Array<Attention.ToneProfile>;
                Attention.playTone({ :toneProfile => profile });
            } else {
                Attention.playTone(Attention.TONE_START);
            }
        }
        if (Attention has :vibrate) {
            var v = [ new Attention.VibeProfile(100, 400) ]
                as Array<Attention.VibeProfile>;
            Attention.vibrate(v);
        }
    }

    private function playParSignal() as Void {
        if (Attention has :playTone) {
            if (Attention has :ToneProfile) {
                var profile = [ new Attention.ToneProfile(3000, 120) ]
                    as Array<Attention.ToneProfile>;
                Attention.playTone({ :toneProfile => profile, :repeatCount => 2 });
            } else {
                Attention.playTone(Attention.TONE_ALARM);
            }
        }
        if (Attention has :vibrate) {
            var v = [
                new Attention.VibeProfile(100, 150),
                new Attention.VibeProfile(0, 80),
                new Attention.VibeProfile(100, 150)
            ] as Array<Attention.VibeProfile>;
            Attention.vibrate(v);
        }
    }

    // ---- Rendering ---------------------------------------------------------

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        switch (_state) {
            case STATE_READY:   drawReady(dc);   break;
            case STATE_DELAY:   drawDelay(dc);   break;
            case STATE_RUNNING: drawRunning(dc); break;
            case STATE_REVIEW:  drawReview(dc);  break;
        }
    }

    private function drawReady(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.22, Graphics.FONT_LARGE,
            WatchUi.loadResource(Rez.Strings.Ready) as String,
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.42, Graphics.FONT_SMALL,
            WatchUi.loadResource(Rez.Strings.PressStartHint) as String,
            Graphics.TEXT_JUSTIFY_CENTER);

        // Settings summary line.
        var summary = drillLabel() + "  |  " + delayLabel();
        if (_settings.parEnabled) {
            summary += "  |  PAR " + _settings.parSeconds.format("%.1f") + "s";
        }
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.66, Graphics.FONT_XTINY, summary,
            Graphics.TEXT_JUSTIFY_CENTER);

        if (_sensorError) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 0.80, Graphics.FONT_XTINY,
                "Accelerometer unavailable", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function drawDelay(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.30, Graphics.FONT_MEDIUM,
            WatchUi.loadResource(Rez.Strings.Standby) as String,
            Graphics.TEXT_JUSTIFY_CENTER);

        var remainMs = _delayEndWallMs - System.getTimer();
        if (remainMs < 0) { remainMs = 0; }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.46, Graphics.FONT_NUMBER_MEDIUM,
            formatSecs(remainMs), Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawRunning(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        // Big live elapsed clock.
        var elapsed = System.getTimer() - _startWallMs;
        if (elapsed < 0) { elapsed = 0; }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.30, Graphics.FONT_NUMBER_THAI_HOT,
            formatSecs(elapsed), Graphics.TEXT_JUSTIFY_CENTER);

        // Shot count.
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.60, Graphics.FONT_SMALL,
            WatchUi.loadResource(Rez.Strings.Shots) as String
                + ": " + _string.count().toString(),
            Graphics.TEXT_JUSTIFY_CENTER);

        // Last split.
        var lastSplit = _string.lastSplitMs();
        if (lastSplit != null) {
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 0.74, Graphics.FONT_TINY,
                WatchUi.loadResource(Rez.Strings.Split) as String
                    + " " + formatSecs(lastSplit),
                Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function drawReview(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        if (_string.isEmpty()) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h / 2, Graphics.FONT_SMALL,
                WatchUi.loadResource(Rez.Strings.NoShots) as String,
                Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        // Header: total time (big).
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.06, Graphics.FONT_NUMBER_MEDIUM,
            formatSecs(_string.totalMs()), Graphics.TEXT_JUSTIFY_CENTER);

        // Sub-header: shots + first-shot (draw) time.
        var first = _string.firstShotMs();
        var sub = WatchUi.loadResource(Rez.Strings.Shots) as String
            + " " + _string.count().toString();
        if (first != null) {
            sub += "   1st " + formatSecs(first);
        }
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.30, Graphics.FONT_XTINY, sub,
            Graphics.TEXT_JUSTIFY_CENTER);

        // Scrollable split list.
        var lineH = dc.getFontHeight(Graphics.FONT_XTINY) + 2;
        var listTop = h * 0.40;
        var maxLines = ((h - listTop) / lineH).toNumber();
        if (maxLines < 1) { maxLines = 1; }

        var i = _reviewScroll;
        var drawn = 0;
        while (i < _string.count() && drawn < maxLines) {
            var line = (i + 1).toString() + ")  "
                + formatSecs(_string.timeAt(i))
                + "   +" + formatSecs(_string.splitAt(i));
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, listTop + drawn * lineH, Graphics.FONT_XTINY,
                line, Graphics.TEXT_JUSTIFY_CENTER);
            i++;
            drawn++;
        }
    }

    // ---- Formatting helpers ------------------------------------------------

    private function formatSecs(ms as Number) as String {
        return (ms / 1000.0).format("%.2f");
    }

    private function drillLabel() as String {
        switch (_settings.drill) {
            case DRILL_BILL:            return WatchUi.loadResource(Rez.Strings.DrillBill) as String;
            case DRILL_MOZAMBIQUE:      return WatchUi.loadResource(Rez.Strings.DrillMozambique) as String;
            case DRILL_ONE_RELOAD_ONE:  return WatchUi.loadResource(Rez.Strings.DrillOneReloadOne) as String;
            case DRILL_EL_PREZ:         return WatchUi.loadResource(Rez.Strings.DrillElPrez) as String;
            case DRILL_UNSTRUCTURED:
            default:                    return WatchUi.loadResource(Rez.Strings.DrillUnstructured) as String;
        }
    }

    private function delayLabel() as String {
        switch (_settings.delayMode) {
            case DELAY_INSTANT: return WatchUi.loadResource(Rez.Strings.DelayInstant) as String;
            case DELAY_FIXED:   return WatchUi.loadResource(Rez.Strings.DelayFixed) as String;
            case DELAY_RANDOM:
            default:            return WatchUi.loadResource(Rez.Strings.DelayRandom) as String;
        }
    }
}
