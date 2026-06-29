import Toybox.Lang;
import Toybox.WatchUi;

class ShootingWatchAppDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        var view = new ShotTimerView(getApp().getSettings());
        WatchUi.pushView(view, new ShotTimerDelegate(view), WatchUi.SLIDE_LEFT);
        return true;
    }

    function onMenu() as Boolean {
        WatchUi.pushView(new Rez.Menus.MainMenu(), new ShootingWatchAppMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

}