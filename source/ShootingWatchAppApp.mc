import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class ShootingWatchAppApp extends Application.AppBase {

    private var _settings as Settings = new Settings();

    function initialize() {
        AppBase.initialize();
        _settings.load();
    }

    function getSettings() as Settings {
        return _settings;
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new ShootingWatchAppView(), new ShootingWatchAppDelegate() ];
    }

}

function getApp() as ShootingWatchAppApp {
    return Application.getApp() as ShootingWatchAppApp;
}