//
// ShotTimerDelegate.mc
//
// Maps user input behaviors to actions on the main view. BehaviorDelegate
// methods return true when the input was consumed (so the lower-level
// InputDelegate / system default is not also invoked).
//
import Toybox.Lang;
import Toybox.WatchUi;

class ShotTimerDelegate extends WatchUi.BehaviorDelegate {

    private var _view as ShotTimerView;

    function initialize(view as ShotTimerView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // START / tap / select: drives the primary state transition.
    function onSelect() as Boolean {
        _view.onActionSelect();
        return true;
    }

    // BACK: cancels/stops; only exits the app when already on the READY screen.
    function onBack() as Boolean {
        return _view.onActionBack();
    }

    // MENU: open settings, but only from the READY screen so a run can't be
    // interrupted accidentally.
    function onMenu() as Boolean {
        if (_view.getState() == STATE_READY) {
            var menu = new SettingsMenu(getApp().getSettings());
            WatchUi.pushView(menu, new SettingsMenuDelegate(menu),
                WatchUi.SLIDE_UP);
        }
        return true;
    }

    // Page down / up: scroll the review list.
    function onNextPage() as Boolean {
        _view.onActionScroll(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.onActionScroll(-1);
        return true;
    }
}
