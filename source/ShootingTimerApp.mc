//
// ShootingTimerApp.mc
//
// Entry point for the Shooting Watch App. A "watch-app" type Connect IQ
// application: it owns the shared Settings object and hands the initial
// View + input Delegate to the runtime.
//
import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class ShootingTimerApp extends Application.AppBase {

    private var _settings as Settings;

    function initialize() {
        AppBase.initialize();
        _settings = new Settings();
    }

    // Called once on app start-up. Load persisted user settings here so the
    // first view already reflects the shooter's last-used configuration.
    function onStart(state as Dictionary?) as Void {
        _settings.load();
    }

    // Called when the app is exiting. Persist anything not already saved.
    function onStop(state as Dictionary?) as Void {
        _settings.save();
    }

    // Provide the initial View and its BehaviorDelegate. The runtime pushes
    // this view automatically.
    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new ShotTimerView(_settings);
        var delegate = new ShotTimerDelegate(view);
        return [view, delegate];
    }

    // Shared accessor so views/menus can read and mutate the same Settings.
    function getSettings() as Settings {
        return _settings;
    }
}

// Convenience: typed handle to the running app instance.
function getApp() as ShootingTimerApp {
    return Application.getApp() as ShootingTimerApp;
}
