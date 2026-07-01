//
// NumberEditor.mc
//
// A full-screen editor for entering a bounded integer one digit at a time.
// Used by the settings menu for the firearm/ammunition profile values
// (muzzle velocity, bullet weight, firearm weight) where cycling by a fixed
// step would be tedious over the wide ranges involved.
//
// Interaction:
//   * UP / DOWN  – change the currently selected digit (0-9, wrapping).
//   * START/SEL  – move to the next digit (thousands -> hundreds -> tens ->
//                  ones -> back to thousands).
//   * BACK       – clamp to [min, max], hand the value back via the callback,
//                  and close the editor.
//
// The value is always shown as four digits (thousands/hundreds/tens/ones) with
// leading zeros so the digit under edit is unambiguous.
//
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;

class NumberEditorView extends WatchUi.View {

    // Place value of each editable digit, indexed by _digitIndex (0..3).
    private const PLACES as Array<Number> = [1000, 100, 10, 1] as Array<Number>;
    private const DIGIT_COUNT as Number = 4;

    private var _title as String;
    private var _unit as String;
    private var _value as Number;
    private var _min as Number;
    private var _max as Number;
    private var _onDone as Method(value as Number) as Void;

    private var _digitIndex as Number = 0;  // 0 = thousands ... 3 = ones

    function initialize(
            title as String,
            unit as String,
            value as Number,
            minValue as Number,
            maxValue as Number,
            onDone as Method(value as Number) as Void) {
        View.initialize();
        _title = title;
        _unit = unit;
        _value = value;
        _min = minValue;
        _max = maxValue;
        _onDone = onDone;
    }

    // ---- Editing -----------------------------------------------------------

    // Change only the selected digit, wrapping 0-9, leaving the others intact.
    function bumpDigit(delta as Number) as Void {
        var place = PLACES[_digitIndex];
        var digit = (_value / place) % 10;
        var next = (digit + delta + 10) % 10;
        _value += (next - digit) * place;
        WatchUi.requestUpdate();
    }

    // Advance the cursor to the next digit (wraps ones -> thousands).
    function nextDigit() as Void {
        _digitIndex = (_digitIndex + 1) % DIGIT_COUNT;
        WatchUi.requestUpdate();
    }

    // Clamp and report the final value. Called on BACK.
    function commit() as Void {
        var v = _value;
        if (v < _min) { v = _min; }
        if (v > _max) { v = _max; }
        _onDone.invoke(v);
    }

    // ---- Rendering ---------------------------------------------------------

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();

        // Title.
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.14, Graphics.FONT_SMALL, _title,
            Graphics.TEXT_JUSTIFY_CENTER);

        // Four digits laid out in fixed-width cells so the carets line up.
        var font = Graphics.FONT_NUMBER_MEDIUM;
        var cellW = dc.getTextWidthInPixels("0", font) + 4;
        var totalW = cellW * DIGIT_COUNT;
        var startX = (w - totalW) / 2;
        var midY = (h * 0.46).toNumber();

        var digitHalf = dc.getFontHeight(font) / 2;
        var caretGap = 8;   // gap between digit edge and caret
        var caretW = 7;     // caret half-width
        var caretH = 9;     // caret height

        for (var i = 0; i < DIGIT_COUNT; i++) {
            var cx = startX + i * cellW + cellW / 2;
            var digit = (_value / PLACES[i]) % 10;
            var selected = (i == _digitIndex);

            dc.setColor(selected ? Graphics.COLOR_YELLOW : Graphics.COLOR_WHITE,
                Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, midY, font, digit.toString(),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

            if (selected) {
                // Up caret above the digit.
                var upBase = midY - digitHalf - caretGap;
                dc.fillPolygon([
                    [cx, upBase - caretH],
                    [cx - caretW, upBase],
                    [cx + caretW, upBase]
                ] as Array<Array<Number>>);
                // Down caret below the digit.
                var dnBase = midY + digitHalf + caretGap;
                dc.fillPolygon([
                    [cx, dnBase + caretH],
                    [cx - caretW, dnBase],
                    [cx + caretW, dnBase]
                ] as Array<Array<Number>>);
            }
        }

        // Unit label to the right of the digits.
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX + totalW + 6, midY, Graphics.FONT_XTINY, _unit,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Range hint.
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.74, Graphics.FONT_XTINY,
            _min.toString() + " - " + _max.toString(),
            Graphics.TEXT_JUSTIFY_CENTER);

        // Control hint.
        dc.drawText(w / 2, h * 0.86, Graphics.FONT_XTINY,
            "START: next  BACK: save", Graphics.TEXT_JUSTIFY_CENTER);
    }
}


class NumberEditorDelegate extends WatchUi.BehaviorDelegate {

    private var _view as NumberEditorView;

    function initialize(view as NumberEditorView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // START / SELECT: advance to the next digit.
    function onSelect() as Boolean {
        _view.nextDigit();
        return true;
    }

    // UP: increment the selected digit.
    function onPreviousPage() as Boolean {
        _view.bumpDigit(1);
        return true;
    }

    // DOWN: decrement the selected digit.
    function onNextPage() as Boolean {
        _view.bumpDigit(-1);
        return true;
    }

    // BACK: save the entered value and close.
    function onBack() as Boolean {
        _view.commit();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
