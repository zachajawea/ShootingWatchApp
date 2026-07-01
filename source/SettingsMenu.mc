//
// SettingsMenu.mc
//
// On-watch configuration via Menu2: course-of-fire drill, start-delay mode,
// par on/off, par time, and the firearm/ammunition profile. Selecting most
// items cycles/toggles the value in place; the numeric profile values
// (muzzle velocity, bullet weight, firearm weight) open a multi-digit
// WatchUi.Picker instead (see BallisticPicker.mc). Settings are persisted when
// the menu closes.
//
import Toybox.Lang;
import Toybox.WatchUi;

class SettingsMenu extends WatchUi.Menu2 {

    private var _settings as Settings;

    function initialize(settings as Settings) {
        Menu2.initialize({ :title => WatchUi.loadResource(Rez.Strings.Settings) as String });
        _settings = settings;

        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.CourseFire) as String,
            drillLabel(), :drill, null));

        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.StartDelay) as String,
            delayLabel(), :delay, null));

        addItem(new WatchUi.ToggleMenuItem(
            WatchUi.loadResource(Rez.Strings.ParEnabled) as String,
            null, :parOn, _settings.parEnabled, null));

        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.ParSeconds) as String,
            parSecondsLabel(), :parSec, null));

        addItem(new WatchUi.ToggleMenuItem(
            WatchUi.loadResource(Rez.Strings.RecordFit) as String,
            null, :fitOn, _settings.recordFit, null));

        // Firearm / ammunition profile. These shape how the accelerometer
        // detects shots (see Settings.getThresholdMilliG / getRefractoryMs).
        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.MuzzleVelocity) as String,
            muzzleLabel(), :muzzle, null));

        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.BulletWeight) as String,
            bulletLabel(), :bullet, null));

        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.FirearmWeight) as String,
            firearmLabel(), :firearm, null));

        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.Detection) as String,
            detectionLabel(), :detection, null));
    }

    function getSettings() as Settings {
        return _settings;
    }

    // ---- Mutators (called by the delegate) ---------------------------------

    function cycleDrill(item as WatchUi.MenuItem) as Void {
        _settings.drill = ((_settings.drill + 1) % DRILL_COUNT) as Drill;
        item.setSubLabel(drillLabel());
    }

    function cycleDelay(item as WatchUi.MenuItem) as Void {
        _settings.delayMode = ((_settings.delayMode + 1) % 3) as DelayMode;
        item.setSubLabel(delayLabel());
    }

    function setParEnabled(enabled as Boolean) as Void {
        _settings.parEnabled = enabled;
    }

    function setFitEnabled(enabled as Boolean) as Void {
        _settings.recordFit = enabled;
    }

    function cycleParSeconds(item as WatchUi.MenuItem) as Void {
        var v = _settings.parSeconds + 0.5;
        if (v > 10.0) {
            v = 2.0;
        }
        _settings.parSeconds = v;
        item.setSubLabel(parSecondsLabel());
    }

    // ---- Ballistic profile: number pickers ---------------------------------
    // Each of these values spans a wide range, so selecting the item opens a
    // multi-digit WatchUi.Picker (see BallisticPicker.mc). UP/DOWN change the
    // focused digit, START advances to the next digit, and accepting the last
    // digit applies the value via the paired onXxxEdited callback, which stores
    // it and refreshes the labels.

    function openMuzzleEditor() as Void {
        WatchUi.pushView(
            new BallisticPicker(
                WatchUi.loadResource(Rez.Strings.MuzzleVelocity) as String,
                "fps", _settings.muzzleVelocityFps,
                MUZZLE_MIN_FPS, MUZZLE_MAX_FPS),
            new BallisticPickerDelegate(
                MUZZLE_MIN_FPS, MUZZLE_MAX_FPS, method(:onMuzzleEdited)),
            WatchUi.SLIDE_UP);
    }

    function openBulletEditor() as Void {
        WatchUi.pushView(
            new BallisticPicker(
                WatchUi.loadResource(Rez.Strings.BulletWeight) as String,
                "gr", _settings.bulletWeightGr,
                BULLET_MIN_GR, BULLET_MAX_GR),
            new BallisticPickerDelegate(
                BULLET_MIN_GR, BULLET_MAX_GR, method(:onBulletEdited)),
            WatchUi.SLIDE_UP);
    }

    function openFirearmEditor() as Void {
        WatchUi.pushView(
            new BallisticPicker(
                WatchUi.loadResource(Rez.Strings.FirearmWeight) as String,
                "oz", _settings.firearmWeightOz,
                FIREARM_MIN_OZ, FIREARM_MAX_OZ),
            new BallisticPickerDelegate(
                FIREARM_MIN_OZ, FIREARM_MAX_OZ, method(:onFirearmEdited)),
            WatchUi.SLIDE_UP);
    }

    function onMuzzleEdited(value as Number) as Void {
        _settings.muzzleVelocityFps = value;
        setSubLabelById(:muzzle, muzzleLabel());
        refreshDetection();
    }

    function onBulletEdited(value as Number) as Void {
        _settings.bulletWeightGr = value;
        setSubLabelById(:bullet, bulletLabel());
        refreshDetection();
    }

    function onFirearmEdited(value as Number) as Void {
        _settings.firearmWeightOz = value;
        setSubLabelById(:firearm, firearmLabel());
        refreshDetection();
    }

    // Keep the read-only detection-summary item in sync after any ballistic
    // variable changes.
    private function refreshDetection() as Void {
        setSubLabelById(:detection, detectionLabel());
    }

    // Update a menu item's sub-label by its id, if present.
    private function setSubLabelById(id as Symbol, label as String) as Void {
        var idx = findItemById(id);
        if (idx >= 0) {
            var item = getItem(idx);
            if (item != null) {
                item.setSubLabel(label);
            }
        }
    }

    // ---- Labels ------------------------------------------------------------

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

    private function parSecondsLabel() as String {
        return _settings.parSeconds.format("%.1f") + "s";
    }

    private function muzzleLabel() as String {
        return _settings.muzzleVelocityFps.toString() + " fps";
    }

    private function bulletLabel() as String {
        return _settings.bulletWeightGr.toString() + " gr";
    }

    private function firearmLabel() as String {
        return _settings.firearmWeightOz.toString() + " oz";
    }

    // Read-only summary of the recoil-derived detection tuning so the shooter
    // can see how the ballistic profile affects shot detection.
    private function detectionLabel() as String {
        return _settings.getThresholdMilliG().toString() + " mG / "
            + _settings.getRefractoryMs().toString() + " ms";
    }
}


class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _menu as SettingsMenu;

    function initialize(menu as SettingsMenu) {
        Menu2InputDelegate.initialize();
        _menu = menu;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :drill) {
            _menu.cycleDrill(item);
        } else if (id == :delay) {
            _menu.cycleDelay(item);
        } else if (id == :parOn) {
            _menu.setParEnabled((item as WatchUi.ToggleMenuItem).isEnabled());
        } else if (id == :parSec) {
            _menu.cycleParSeconds(item);
        } else if (id == :fitOn) {
            _menu.setFitEnabled((item as WatchUi.ToggleMenuItem).isEnabled());
        } else if (id == :muzzle) {
            _menu.openMuzzleEditor();
        } else if (id == :bullet) {
            _menu.openBulletEditor();
        } else if (id == :firearm) {
            _menu.openFirearmEditor();
        }
        // :detection is read-only (no cycle action).
        WatchUi.requestUpdate();
    }

    function onBack() as Void {
        // Persist and close.
        _menu.getSettings().save();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
