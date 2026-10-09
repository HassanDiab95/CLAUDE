package com.rayy.app.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Line chart drawn with Canvas (no external library): smooth line, gradient fill,
 * dashed lines for the ideal range (low / high thresholds), min / max labels.
 */
@Composable
fun LineChart(
    values: List<Double>,
    color: Color = MaterialTheme.colorScheme.primary,
    modifier: Modifier = Modifier,
    low: Double? = null,
    high: Double? = null,
) {
    val grid = MaterialTheme.colorScheme.outlineVariant
    val labelColor = MaterialTheme.colorScheme.onSurfaceVariant
    val measurer = rememberTextMeasurer()
    if (values.size < 2) {
        Box(modifier.fillMaxWidth().height(200.dp), contentAlignment = Alignment.Center) { Text("📉  —") }
        return
    }
    // the visible range also includes the thresholds, so the ideal band is on screen
    val all = values + listOfNotNull(low, high)
    val min = all.min()
    val max = all.max()
    val pad = ((max - min) * 0.1).takeIf { it > 0 } ?: 1.0
    val lo = min - pad
    val range = (max + pad) - lo

    Canvas(modifier.fillMaxWidth().height(210.dp)) {
        val left = 40.dp.toPx()
        val w = size.width - left
        val h = size.height
        fun y(v: Double) = (h - (v - lo) / range * h).toFloat()
        fun x(i: Int) = left + w * i / (values.size - 1)

        for (i in 0..4) {
            val yy = h * i / 4f
            drawLine(grid, Offset(left, yy), Offset(size.width, yy), strokeWidth = 1f)
        }
        label(measurer, values.max().show(0), Offset(0f, y(values.max()) - 8.dp.toPx()), labelColor)
        label(measurer, values.min().show(0), Offset(0f, y(values.min()) - 8.dp.toPx()), labelColor)

        val dash = PathEffect.dashPathEffect(floatArrayOf(14f, 10f))
        listOfNotNull(low, high).forEach { t ->
            drawLine(color.copy(alpha = 0.7f), Offset(left, y(t)), Offset(size.width, y(t)), strokeWidth = 2.dp.toPx(), pathEffect = dash)
        }

        val line = Path()
        values.forEachIndexed { i, v ->
            if (i == 0) line.moveTo(x(i), y(v))
            else {
                val px = x(i - 1); val py = y(values[i - 1])
                val cx = (px + x(i)) / 2
                line.cubicTo(cx, py, cx, y(v), x(i), y(v))
            }
        }
        val fill = Path().apply {
            addPath(line)
            lineTo(x(values.lastIndex), h)
            lineTo(left, h)
            close()
        }
        drawPath(fill, Brush.verticalGradient(listOf(color.copy(alpha = 0.35f), color.copy(alpha = 0.02f))))
        drawPath(line, color, style = Stroke(width = 3.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
        drawCircle(color, 5.dp.toPx(), Offset(x(values.lastIndex), y(values.last())))
        drawCircle(Color.White, 2.5.dp.toPx(), Offset(x(values.lastIndex), y(values.last())))
    }
}

private fun androidx.compose.ui.graphics.drawscope.DrawScope.label(m: TextMeasurer, text: String, at: Offset, color: Color) {
    drawText(m, text, at, TextStyle(fontSize = 11.sp, color = color))
}
