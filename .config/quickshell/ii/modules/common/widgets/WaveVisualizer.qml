import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Effects

Canvas { // Visualizer
    id: root
    property list<var> points
    property list<var> smoothPoints
    property real maxVisualizerValue: 1000
    property int smoothing: 2
    property bool live: true
    property color color: Appearance.m3colors.m3primary
    // Extra controls for tight spaces (e.g., Dynamic Island)
    property real amplitude: 1.0    // Multiplies normalized height, useful for short containers
    property real fillAlpha: 0.15   // Alpha used for the fill color
    property real blurAmount: 1.0   // Blur intensity for the layer effect; set 0 to disable
    property real minFill: 0.0      // Minimum normalized fill (0..1) to keep a thin band visible
    property bool autoScale: false  // If true, determine max from current points
    property real heightRatio: 1.0  // Portion of height the wave can occupy (0..1)
    property real baseOffset: 0.0   // Bottom offset as portion of height (0..1), ensures headroom
    property real strokeOpacity: 0.2 // Outline opacity for definition in tight spaces

    onPointsChanged: () => {
        root.requestPaint()
    }
    onWidthChanged: () => root.requestPaint()
    onHeightChanged: () => root.requestPaint()
    onLiveChanged: () => root.requestPaint()

    anchors.fill: parent
    onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        var points = root.points || [];
        var maxVal = root.maxVisualizerValue || 1;
        var h = height;
        var w = width;
        var n = points.length;
        if (root.autoScale && n > 0) {
            maxVal = 1;
            for (var mi = 0; mi < n; ++mi) {
                var pv = points[mi];
                if (pv > maxVal) maxVal = pv;
            }
        }
        
        if (n < 2) {
            // Draw a minimal flat band so something is visible in tight spaces
            var floor = Math.max(0, Math.min(1, root.minFill || 0.0));
            var offset = Math.max(0, Math.min(1, root.baseOffset || 0.0));
            var usable = Math.max(0, Math.min(1, root.heightRatio || 1.0));
            if (offset + usable > 1) usable = 1 - offset;
            if (root.live || floor > 0) {
                ctx.beginPath();
                ctx.moveTo(0, h);
                var y = h - (floor * usable + offset) * h;
                ctx.lineTo(0, y);
                ctx.lineTo(w, y);
                ctx.lineTo(w, h);
                ctx.closePath();
                var alpha = (root.fillAlpha !== undefined) ? root.fillAlpha : 0.15;
                ctx.fillStyle = Qt.rgba(root.color.r, root.color.g, root.color.b, alpha);
                ctx.fill();
            }
            return;
        }

        // Smoothing: simple moving average (optional)
        var smoothWindow = root.smoothing; // adjust for more/less smoothing
        root.smoothPoints = [];
        for (var i = 0; i < n; ++i) {
            var sum = 0, count = 0;
            for (var j = -smoothWindow; j <= smoothWindow; ++j) {
                var idx = Math.max(0, Math.min(n - 1, i + j));
                sum += points[idx];
                count++;
            }
            root.smoothPoints.push(sum / count);
        }
        if (!root.live) root.smoothPoints.fill(0); // If not playing, show no points

        ctx.beginPath();
        ctx.moveTo(0, h);
        var offset = Math.max(0, Math.min(1, root.baseOffset || 0.0));
        var usable = Math.max(0, Math.min(1, root.heightRatio || 1.0));
        if (offset + usable > 1) usable = 1 - offset;

        for (var i = 0; i < n; ++i) {
            var x = i * w / (n - 1);
            var norm = 0;
            if (maxVal > 0) norm = root.smoothPoints[i] / maxVal;
            // Scale by amplitude and clamp to [0, 1]
            norm = Math.max(0, Math.min(1, norm * (root.amplitude || 1.0)));
            // Apply a minimum floor so very low energy remains visible
            var floor = Math.max(0, Math.min(1, root.minFill || 0.0));
            var y = h - (Math.max(floor, norm) * usable + offset) * h;
            ctx.lineTo(x, y);
        }
        ctx.lineTo(w, h);
        ctx.closePath();

        var alpha = (root.fillAlpha !== undefined) ? root.fillAlpha : 0.15;
        ctx.fillStyle = Qt.rgba(root.color.r, root.color.g, root.color.b, alpha);
        ctx.fill();

        // Optional stroke for definition in tight spaces
        ctx.beginPath();
        var h2 = h;
        for (var k = 0; k < n; ++k) {
            var x2 = k * w / (n - 1);
            var norm2 = 0;
            if (maxVal > 0) norm2 = root.smoothPoints[k] / maxVal;
            norm2 = Math.max(0, Math.min(1, norm2 * (root.amplitude || 1.0)));
            var floor2 = Math.max(0, Math.min(1, root.minFill || 0.0));
            var y2 = h2 - (Math.max(floor2, norm2) * usable + offset) * h2;
            if (k === 0) ctx.moveTo(x2, y2); else ctx.lineTo(x2, y2);
        }
        var sAlpha = Math.max(0, Math.min(1, root.strokeOpacity));
        ctx.strokeStyle = Qt.rgba(root.color.r, root.color.g, root.color.b, sAlpha);
        ctx.lineWidth = 0.8;
        ctx.stroke();
    }

    layer.enabled: true
    layer.effect: MultiEffect { // Blur a bit to obscure away the points
        source: root
        saturation: 0.2
        blurEnabled: root.blurAmount > 0
        blurMax: 7
        blur: Math.max(0, Math.min(7, root.blurAmount))
    }
}