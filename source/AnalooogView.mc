using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi;
using Toybox.ActivityMonitor;

class AnalooogView extends WatchUi.WatchFace {

    // Screen geometry
    private var _screenWidth;
    private var _centerX;
    private var _centerY;
    private var _radius;

    // State
    private var _isAwake = true;

    // Buffered bitmap for static dial elements
    private var _dialBuffer = null;

    // Colors
    private const COLOR_BG       = 0x000000;
    private const COLOR_WHITE    = 0xFFFFFF;
    private const COLOR_ACCENT   = 0xFFFF00;
    private const COLOR_DIM_GRAY = 0x888888;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc) {
        _screenWidth = dc.getWidth();
        _centerX = _screenWidth / 2;
        _centerY = dc.getHeight() / 2;
        _radius = _centerX;
        _dialBuffer = null; // force re-creation
    }

    //--------------------------------------------------------------
    // Static dial buffer (tick marks + minute numbers)
    //--------------------------------------------------------------

    private function ensureDialBuffer(dc) {
        if (_dialBuffer != null) {
            return;
        }

        var options = {
            :width => _screenWidth,
            :height => _screenWidth
        };

        _dialBuffer = Graphics has :createBufferedBitmap
            ? Graphics.createBufferedBitmap(options).get()
            : new Graphics.BufferedBitmap(options);

        var bufDc = _dialBuffer.getDc();
        bufDc.setColor(COLOR_BG, COLOR_BG);
        bufDc.clear();

        renderTickMarks(bufDc);
    }

    private function renderTickMarks(dc) {
        var outerR = _radius - 5;   // 135
        var hourLen = 15;
        var minLen = 7;

        for (var i = 0; i < 60; i++) {
            var angle = i * Math.PI * 2.0 / 60.0;
            var sinA = Math.sin(angle);
            var cosA = Math.cos(angle);

            var ox = _centerX + (outerR * sinA).toNumber();
            var oy = _centerY - (outerR * cosA).toNumber();

            if (i % 5 == 0) {
                // Hour tick - thick white
                var innerR = outerR - hourLen;
                var ix = _centerX + (innerR * sinA).toNumber();
                var iy = _centerY - (innerR * cosA).toNumber();
                dc.setColor(COLOR_WHITE, COLOR_BG);
                dc.setPenWidth(3);
                dc.drawLine(ix, iy, ox, oy);
            } else {
                // Minute tick - thin gray
                var innerR = outerR - minLen;
                var ix = _centerX + (innerR * sinA).toNumber();
                var iy = _centerY - (innerR * cosA).toNumber();
                dc.setColor(COLOR_DIM_GRAY, COLOR_BG);
                dc.setPenWidth(1);
                dc.drawLine(ix, iy, ox, oy);
            }
        }
        dc.setPenWidth(1);
    }

    //--------------------------------------------------------------
    // Clock hands
    //--------------------------------------------------------------

    private function drawHourHand(dc, hour, min) {
        var angle = ((hour % 12) + min / 60.0) * Math.PI * 2.0 / 12.0;
        var handLen = 56;  // 40% of radius
        var tailLen = 10;

        var sinA = Math.sin(angle);
        var cosA = Math.cos(angle);

        var tipX = _centerX + (handLen * sinA).toNumber();
        var tipY = _centerY - (handLen * cosA).toNumber();
        var tailX = _centerX - (tailLen * sinA).toNumber();
        var tailY = _centerY + (tailLen * cosA).toNumber();

        dc.setColor(COLOR_WHITE, COLOR_BG);
        dc.setPenWidth(3);
        dc.drawLine(tailX, tailY, tipX, tipY);
    }

    private function drawMinuteHand(dc, min, sec) {
        var angle = (min + sec / 60.0) * Math.PI * 2.0 / 60.0;
        var handLen = 91;  // 65% of radius
        var tailLen = 15;

        var sinA = Math.sin(angle);
        var cosA = Math.cos(angle);

        var tipX = _centerX + (handLen * sinA).toNumber();
        var tipY = _centerY - (handLen * cosA).toNumber();
        var tailX = _centerX - (tailLen * sinA).toNumber();
        var tailY = _centerY + (tailLen * cosA).toNumber();

        dc.setColor(COLOR_WHITE, COLOR_BG);
        dc.setPenWidth(2);
        dc.drawLine(tailX, tailY, tipX, tipY);
    }

    private function drawSecondHand(dc, sec) {
        var angle = sec * Math.PI * 2.0 / 60.0;
        var handLen = 98;  // 70% of radius
        var tailLen = 20;

        var sinA = Math.sin(angle);
        var cosA = Math.cos(angle);

        var tipX = _centerX + (handLen * sinA).toNumber();
        var tipY = _centerY - (handLen * cosA).toNumber();
        var tailX = _centerX - (tailLen * sinA).toNumber();
        var tailY = _centerY + (tailLen * cosA).toNumber();

        dc.setColor(COLOR_ACCENT, COLOR_BG);
        dc.setPenWidth(1);
        dc.drawLine(tailX, tailY, tipX, tipY);
    }

    private function drawCenterDot(dc) {
        dc.setColor(COLOR_WHITE, COLOR_WHITE);
        dc.fillCircle(_centerX, _centerY, 4);
        dc.setColor(COLOR_ACCENT, COLOR_ACCENT);
        dc.fillCircle(_centerX, _centerY, 2);
    }

    //--------------------------------------------------------------
    // Data overlays
    //--------------------------------------------------------------

    private function drawDayDate(dc) {
        var now = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var dayStr = now.day_of_week.toString();
        var dateStr = now.day.toString();

        // Day in white, date in yellow, positioned near 12 o'clock
        var y = 58;
        var spacing = 3;

        // Draw day right-justified just left of center, date left-justified just right
        dc.setColor(COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_centerX - spacing, y, Graphics.FONT_XTINY, dayStr,
                    Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_centerX + spacing, y, Graphics.FONT_XTINY, dateStr,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawStatusIcons(dc) {
        var settings = System.getDeviceSettings();
        var y = 78;
        var iconSpacing = 20;
        var icons = 4;
        var startX = _centerX - ((icons - 1) * iconSpacing) / 2;

        // Icon 1: Alarm
        var alarmActive = settings.alarmCount > 0;
        drawAlarmIcon(dc, startX, y, alarmActive);

        // Icon 2: Bluetooth
        var btActive = settings.phoneConnected;
        drawBluetoothIcon(dc, startX + iconSpacing, y, btActive);

        // Icon 3: DND
        var dndActive = false;
        if (settings has :doNotDisturb && settings.doNotDisturb != null) {
            dndActive = settings.doNotDisturb;
        }
        drawDndIcon(dc, startX + 2 * iconSpacing, y, dndActive);

        // Icon 4: Notifications
        var notifActive = settings.notificationCount > 0;
        drawNotificationIcon(dc, startX + 3 * iconSpacing, y, notifActive);
    }

    // Simple alarm bell icon (line art)
    private function drawAlarmIcon(dc, cx, cy, active) {
        dc.setColor(active ? COLOR_ACCENT : COLOR_DIM_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        // Bell body: arc-like shape
        dc.drawLine(cx - 4, cy + 2, cx - 4, cy - 2);
        dc.drawLine(cx - 4, cy - 2, cx - 2, cy - 5);
        dc.drawLine(cx - 2, cy - 5, cx + 2, cy - 5);
        dc.drawLine(cx + 2, cy - 5, cx + 4, cy - 2);
        dc.drawLine(cx + 4, cy - 2, cx + 4, cy + 2);
        dc.drawLine(cx - 5, cy + 2, cx + 5, cy + 2);
        // Clapper
        dc.drawLine(cx, cy + 2, cx, cy + 4);
    }

    // Bluetooth icon
    private function drawBluetoothIcon(dc, cx, cy, active) {
        dc.setColor(active ? COLOR_ACCENT : COLOR_DIM_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        // Vertical line
        dc.drawLine(cx, cy - 6, cx, cy + 6);
        // Upper arrow
        dc.drawLine(cx, cy - 6, cx + 4, cy - 2);
        dc.drawLine(cx + 4, cy - 2, cx - 3, cy + 3);
        // Lower arrow
        dc.drawLine(cx, cy + 6, cx + 4, cy + 2);
        dc.drawLine(cx + 4, cy + 2, cx - 3, cy - 3);
    }

    // DND (moon/circle) icon
    private function drawDndIcon(dc, cx, cy, active) {
        dc.setColor(active ? COLOR_ACCENT : COLOR_DIM_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawCircle(cx, cy, 5);
        dc.drawLine(cx - 3, cy, cx + 3, cy);
    }

    // Notification (envelope) icon
    private function drawNotificationIcon(dc, cx, cy, active) {
        dc.setColor(active ? COLOR_ACCENT : COLOR_DIM_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        // Rectangle
        dc.drawRectangle(cx - 5, cy - 3, 10, 7);
        // Flap lines
        dc.drawLine(cx - 5, cy - 3, cx, cy + 1);
        dc.drawLine(cx + 4, cy - 3, cx, cy + 1);
    }

    private function drawDataFields(dc) {
        // Left field: Battery
        var batteryLabel = "BATTERY";
        var battery = System.getSystemStats().battery;
        var batteryVal = battery.toNumber().toString() + "%";

        dc.setColor(COLOR_DIM_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(82, _centerY - 8, Graphics.FONT_SYSTEM_XTINY, batteryLabel,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(82, _centerY + 8, Graphics.FONT_XTINY, batteryVal,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Right field: Steps
        var stepsLabel = "STEPS";
        var stepsVal = "0";
        var info = ActivityMonitor.getInfo();
        if (info != null && info.steps != null) {
            stepsVal = info.steps.toString();
        }

        dc.setColor(COLOR_DIM_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(212, _centerY - 8, Graphics.FONT_SYSTEM_XTINY, stepsLabel,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(212, _centerY + 8, Graphics.FONT_XTINY, stepsVal,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawDigitalTime(dc) {
        var clockTime = System.getClockTime();
        var hour = clockTime.hour;
        var min = clockTime.min;

        var settings = System.getDeviceSettings();
        if (!settings.is24Hour) {
            hour = hour % 12;
            if (hour == 0) {
                hour = 12;
            }
        }

        var timeStr = hour.format("%d") + ":" + min.format("%02d");

        dc.setColor(COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_centerX, 210, Graphics.FONT_TINY, timeStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //--------------------------------------------------------------
    // Main update
    //--------------------------------------------------------------

    function onUpdate(dc) {
        // Ensure static buffer exists
        ensureDialBuffer(dc);

        // Clear screen
        dc.setColor(COLOR_BG, COLOR_BG);
        dc.clear();

        // Draw static dial from buffer
        dc.drawBitmap(0, 0, _dialBuffer);

        // Data overlays
        drawDayDate(dc);
        drawDataFields(dc);
        drawDigitalTime(dc);

        // Clock hands
        var clockTime = System.getClockTime();
        drawHourHand(dc, clockTime.hour, clockTime.min);
        drawMinuteHand(dc, clockTime.min, clockTime.sec);

        if (_isAwake) {
            drawSecondHand(dc, clockTime.sec);
        }

        drawCenterDot(dc);
    }

    //--------------------------------------------------------------
    // Power mode
    //--------------------------------------------------------------

    function onEnterSleep() {
        _isAwake = false;
        WatchUi.requestUpdate();
    }

    function onExitSleep() {
        _isAwake = true;
    }
}
