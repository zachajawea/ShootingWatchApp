//
// NumberFactory.mc
//
// PickerFactory that generates a wheel of consecutive numbers for use with
// WatchUi.Picker. Connect IQ has no built-in WatchUi.NumberFactory — this is
// the standard factory from the Garmin Picker sample, adapted for
// BallisticPicker's per-digit (0-9) columns.
//
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class NumberFactory extends WatchUi.PickerFactory {
    private var _start as Number;
    private var _stop as Number;
    private var _increment as Number;
    private var _formatString as String;
    private var _font as FontDefinition;

    public function initialize(start as Number, stop as Number, increment as Number, options as {
        :font as FontDefinition,
        :format as String
    }) {
        PickerFactory.initialize();

        _start = start;
        _stop = stop;
        _increment = increment;

        var format = options.get(:format);
        if (format != null) {
            _formatString = format;
        } else {
            _formatString = "%d";
        }

        var font = options.get(:font);
        if (font != null) {
            _font = font;
        } else {
            _font = Graphics.FONT_NUMBER_HOT;
        }
    }

    public function getIndex(value as Number) as Number {
        return (value / _increment) - _start;
    }

    public function getDrawable(index as Number, selected as Boolean) as Drawable? {
        var value = getValue(index);
        var text = "No item";
        if (value instanceof Number) {
            text = value.format(_formatString);
        }
        return new WatchUi.Text({:text=>text, :color=>Graphics.COLOR_WHITE, :font=>_font,
            :locX=>WatchUi.LAYOUT_HALIGN_CENTER, :locY=>WatchUi.LAYOUT_VALIGN_CENTER});
    }

    public function getValue(index as Number) as Object? {
        return _start + (index * _increment);
    }

    public function getSize() as Number {
        return (_stop - _start) / _increment + 1;
    }
}
