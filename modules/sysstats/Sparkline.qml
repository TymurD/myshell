import QtQuick
import qs.modules.sysstats
import qs.theme

// Tiny area chart of a history list (oldest first). `max` = value at the top edge.
Canvas {
    id: root

    property var values: []
    property real max: 100
    property int capacity: 30
    property color color: Theme.accent

    implicitHeight: 36
    onValuesChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const v = values ?? [];
        if (v.length < 2 || width <= 0 || height <= 0)
            return;
        const step = width / Math.max(1, capacity - 1);
        const x0 = width - (v.length - 1) * step;
        const y = val => height - 1 - Math.max(0, Math.min(1, val / (max || 1))) * (height - 2);

        ctx.beginPath();
        ctx.moveTo(x0, height);
        for (let i = 0; i < v.length; i++)
            ctx.lineTo(x0 + i * step, y(v[i]));
        ctx.lineTo(width, height);
        ctx.closePath();
        ctx.globalAlpha = 0.15;
        ctx.fillStyle = root.color;
        ctx.fill();

        ctx.globalAlpha = 1;
        ctx.beginPath();
        for (let i = 0; i < v.length; i++) {
            if (i === 0)
                ctx.moveTo(x0, y(v[0]));
            else
                ctx.lineTo(x0 + i * step, y(v[i]));
        }
        ctx.lineWidth = 1.5;
        ctx.strokeStyle = root.color;
        ctx.stroke();
    }
}
