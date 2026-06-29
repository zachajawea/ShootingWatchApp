//
// ShotDetector.mc
//
// Detects firearm shots from wrist accelerometer data.
//
// Approach: a shot's recoil produces a brief, large spike in acceleration
// magnitude well above the ~1000 milli-G gravity baseline. We subscribe to
// high-frequency batched accelerometer samples via
// Sensor.registerSensorDataListener (the 1 Hz Sensor.getInfo / enableSensorEvents
// path is far too slow to catch a recoil impulse), compute each sample's
// vector magnitude, and fire a callback when the magnitude crosses a
// sensitivity threshold. A refractory window suppresses the recoil's
// oscillation tail so each shot is counted exactly once.
//
// Timing: each accelerometer sample carries a millisecond timestamp. We take
// the first sample of the first batch after start() as time 0, so every shot
// time and split is a pure difference of sample timestamps and therefore
// accurate regardless of how the batches are buffered/delivered. If a device
// does not provide timestamps, we synthesize sample times from the sample
// rate (uniform sampling), which the API guarantees.
//
// Precision note: wrist sampling is capped by getMaxSampleRateForSensorType()
// (commonly 25 Hz => 40 ms resolution). This is excellent for training and
// relative split tracking, but is not a millisecond-accurate acoustic match
// timer. The code requests the device's maximum supported rate.
//
import Toybox.Lang;
import Toybox.Sensor;
import Toybox.System;
import Toybox.Math;

class ShotDetector {

    // Skip spikes in the first few ms after start (button-release / settling).
    private const MIN_SHOT_MS as Number = 20;

    private var _callback as Method(timeMs as Number) as Void;
    private var _running as Boolean = false;

    private var _threshold as Number = 3000;     // milli-G
    private var _refractoryMs as Number = 110;
    private var _sampleRate as Number = 25;       // Hz, set in start()

    private var _startTs as Number?;              // timestamp of first sample
    private var _lastShotMs as Number?;           // last accepted shot time
    private var _sampleIndex as Number = 0;       // for timestamp fallback

    function initialize(callback as Method(timeMs as Number) as Void) {
        _callback = callback;
    }

    function isRunning() as Boolean {
        return _running;
    }

    // Begin listening. Returns false if the accelerometer cannot be used.
    function start(thresholdMilliG as Number, refractoryMs as Number) as Boolean {
        if (_running) {
            return true;
        }

        _threshold = thresholdMilliG;
        _refractoryMs = refractoryMs;
        _startTs = null;
        _lastShotMs = null;
        _sampleIndex = 0;

        _sampleRate = resolveSampleRate();

        var options = {
            :period => 1, // seconds of data per callback (min granularity)
            :accelerometer => {
                :enabled => true,
                :sampleRate => _sampleRate,
                :includeTimestamps => true
            }
        };

        try {
            Sensor.registerSensorDataListener(method(:onAccelData), options);
        } catch (e) {
            // Device lacks accelerometer support or the listener was rejected.
            return false;
        }

        _running = true;
        return true;
    }

    function stop() as Void {
        if (!_running) {
            return;
        }
        Sensor.unregisterSensorDataListener();
        _running = false;
    }

    // Query the device's max accelerometer rate, clamped to a sane default.
    private function resolveSampleRate() as Number {
        var rate = 25;
        if (Sensor has :getMaxSampleRateForSensorType) {
            try {
                var max = Sensor.getMaxSampleRateForSensorType(:accelerometer);
                if (max != null && max > 0) {
                    rate = max;
                }
            } catch (e) {
                // fall back to default
            }
        }
        return rate;
    }

    // Callback for each high-frequency accelerometer batch.
    function onAccelData(data as Sensor.SensorData) as Void {
        if (!_running) {
            return;
        }
        if (!(data has :accelerometerData) || data.accelerometerData == null) {
            return;
        }

        var accel = data.accelerometerData;
        var xs = accel.x;
        var ys = accel.y;
        var zs = accel.z;
        if (xs == null || ys == null || zs == null) {
            return;
        }

        var ts = (accel has :timestamp) ? accel.timestamp : null;
        var n = xs.size();

        for (var i = 0; i < n; i++) {
            // Vector magnitude in milli-G. Computed from x/y/z so behavior is
            // identical across devices (rather than relying on the optional
            // power field).
            var x = xs[i];
            var y = ys[i];
            var z = zs[i];
            var mag = Math.sqrt((x * x) + (y * y) + (z * z)).toNumber();

            // Resolve this sample's time (ms from start) using real timestamps
            // when available, otherwise a synthesized uniform clock.
            var sampleTimeMs;
            if (ts != null) {
                if (_startTs == null) {
                    _startTs = ts[i];
                }
                sampleTimeMs = ts[i] - _startTs;
            } else {
                sampleTimeMs = (_sampleIndex * 1000) / _sampleRate;
            }
            _sampleIndex++;

            // Threshold + debounce.
            if (mag >= _threshold && sampleTimeMs >= MIN_SHOT_MS) {
                if (_lastShotMs == null
                        || (sampleTimeMs - _lastShotMs) >= _refractoryMs) {
                    _lastShotMs = sampleTimeMs;
                    _callback.invoke(sampleTimeMs);
                }
            }
        }
    }
}
