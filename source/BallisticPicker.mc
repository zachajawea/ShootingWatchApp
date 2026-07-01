//
// BallisticPicker.mc
//
// A multi-digit number picker for the firearm/ammunition profile values
// (muzzle velocity, bullet weight, firearm weight). Built on the Connect IQ
// picker framework: WatchUi.Picker with one WatchUi.NumberFactory column per
// decimal digit.
//
// (WatchUi.NumberPicker itself only supports time/duration modes — days,
// hours:minutes, minutes:seconds, seconds — so it can't represent ranges like
// 600-3300 fps. WatchUi.Picker + NumberFactory is the general-purpose number
// picker the framework provides.)
//
// Interaction (button devices):
//   * UP / DOWN  – change the focused digit (0-9).
//   * START/SEL  – confirm the digit and advance to the next one; after the
//                  last digit this accepts the value.
//   * BACK       – step back a digit; on the first digit this cancels.
//
// The assembled value is clamped to [min, max] on accept before it is handed
// back through the callback.
//
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;

class BallisticPicker extends WatchUi.Picker {

    function initialize(
            title as String,
            unit as String,
            value as Number,
            minValue as Number,
            maxValue as Number) {

        var digits = numDigits(maxValue);

        var titleText = new WatchUi.Text({
            :text => title + " (" + unit + ")",
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_BOTTOM,
            :color => Graphics.COLOR_WHITE,
            :font => Graphics.FONT_TINY
        });

        // Clamp the starting value into range before decomposing it.
        var v = value;
        if (v < minValue) { v = minValue; }
        if (v > maxValue) { v = maxValue; }

        // One 0-9 wheel per digit, most-significant first. For a (0, 9, step 1)
        // NumberFactory the selection index equals the digit value, so the
        // per-column default is simply that digit.
        var factories = new [digits] as Array<WatchUi.PickerFactory>;
        var defaults = new [digits] as Array<Number>;
        for (var i = digits - 1; i >= 0; i--) {
            factories[i] = new WatchUi.NumberFactory(0, 9, 1, {});
            defaults[i] = v % 10;
            v = v / 10;
        }

        Picker.initialize({
            :title => titleText,
            :pattern => factories,
            :defaults => defaults
        });
    }

    // Number of decimal digits needed to represent n (min 1).
    private function numDigits(n as Number) as Number {
        var d = 1;
        var t = n;
        while (t >= 10) {
            t = t / 10;
            d++;
        }
        return d;
    }
}


class BallisticPickerDelegate extends WatchUi.PickerDelegate {

    private var _min as Number;
    private var _max as Number;
    private var _onDone as Method(value as Number) as Void;

    function initialize(
            minValue as Number,
            maxValue as Number,
            onDone as Method(value as Number) as Void) {
        PickerDelegate.initialize();
        _min = minValue;
        _max = maxValue;
        _onDone = onDone;
    }

    // Combine the per-digit column values into a single number, clamp it to the
    // allowed range, save it, and close the picker.
    function onAccept(values as Array) as Boolean {
        var value = 0;
        for (var i = 0; i < values.size(); i++) {
            value = value * 10 + (values[i] as Number);
        }
        if (value < _min) { value = _min; }
        if (value > _max) { value = _max; }
        _onDone.invoke(value);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onCancel() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
