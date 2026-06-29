//
// SettingsMenu.mc
//
// On-watch configuration via Menu2: sensitivity preset, start-delay mode,
// par on/off, and par time. Selecting an item cycles its value in place and
// updates the item's sub-label. Settings are persisted when the menu closes.
//
import Toybox.Lang;
import Toybox.WatchUi;

class SettingsMenu extends WatchUi.Menu2 {

    private var _settings as Settings;

    function initialize(settings as Settings) {
        Menu2.initialize({ :title => WatchUi.loadResource(Rez.Strings.Settings) as String });
        _settings = settings;

        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.Sensitivity) as String,
            sensitivityLabel(), :sensitivity, null));

        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.StartDelay) as String,
            delayLabel(), :delay, null));

        addItem(new WatchUi.ToggleMenuItem(
            WatchUi.loadResource(Rez.Strings.ParEnabled) as String,
            null, :parOn, _settings.parEnabled, null));

        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.ParSeconds) as String,
            parSecondsLabel(), :parSec, null));
    }

    function getSettings() as Settings {
        return _settings;
    }

    // ---- Mutators (called by the delegate) ---------------------------------

    function cycleSensitivity(item as WatchUi.MenuItem) as Void {
        _settings.sensitivity = ((_settings.sensitivity + 1) % 3) as Sensitivity;
        item.setSubLabel(sensitivityLabel());
    }

    function cycleDelay(item as WatchUi.MenuItem) as Void {
        _settings.delayMode = ((_settings.delayMode + 1) % 3) as DelayMode;
        item.setSubLabel(delayLabel());
    }

    function setParEnabled(enabled as Boolean) as Void {
        _settings.parEnabled = enabled;
    }

    function cycleParSeconds(item as WatchUi.MenuItem) as Void {
        var v = _settings.parSeconds + 0.5;
        if (v > 10.0) {
            v = 2.0;
        }
        _settings.parSeconds = v;
        item.setSubLabel(parSecondsLabel());
    }

    // ---- Labels ------------------------------------------------------------

    private function sensitivityLabel() as String {
        switch (_settings.sensitivity) {
            case SENS_HIGH:   return WatchUi.loadResource(Rez.Strings.SensHigh) as String;
            case SENS_LOW:    return WatchUi.loadResource(Rez.Strings.SensLow) as String;
            case SENS_MEDIUM:
            default:          return WatchUi.loadResource(Rez.Strings.SensMedium) as String;
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
}


class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _menu as SettingsMenu;

    function initialize(menu as SettingsMenu) {
        Menu2InputDelegate.initialize();
        _menu = menu;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :sensitivity) {
            _menu.cycleSensitivity(item);
        } else if (id == :delay) {
            _menu.cycleDelay(item);
        } else if (id == :parOn) {
            _menu.setParEnabled((item as WatchUi.ToggleMenuItem).isEnabled());
        } else if (id == :parSec) {
            _menu.cycleParSeconds(item);
        }
        WatchUi.requestUpdate();
    }

    function onBack() as Void {
        // Persist and close.
        _menu.getSettings().save();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
