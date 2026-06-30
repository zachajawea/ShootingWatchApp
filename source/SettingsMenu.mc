//
// SettingsMenu.mc
//
// On-watch configuration via Menu2: course-of-fire drill, start-delay mode,
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
        }
        WatchUi.requestUpdate();
    }

    function onBack() as Void {
        // Persist and close.
        _menu.getSettings().save();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
