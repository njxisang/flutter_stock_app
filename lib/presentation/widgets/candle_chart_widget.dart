import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../domain/entities/stock_quote.dart';
import '../../core/constants/app_constants.dart';

/// Professional OHLC candlestick chart with MA overlays and volume.
class CandleChartWidget extends StatefulWidget {
  final List<StockQuote> quotes;
  final List<MaData> maData;

  const CandleChartWidget({
    super.key,
    required this.quotes,
    required this.maData,
  });

  @override
  State<CandleChartWidget> createState() => _CandleChartWidgetState();
}

class _CandleChartWidgetState extends State<CandleChartWidget> {
  int _startIdx = 0;
  int _endIdx = 0;
  final int _defaultVisible = 60;
  double _scale = 1.0;
  int? _touchedIdx;
  Offset? _touchPos;

  @override
  void initState() {
    super.initState();
    _endIdx = widget.quotes.length;
    _startIdx = math.max(0, _endIdx - _defaultVisible);
  }

  @override
  void didUpdateWidget(CandleChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quotes.length != widget.quotes.length) {
      _endIdx = widget.quotes.length;
      _startIdx = math.max(0, _endIdx - _defaultVisible);
    }
  }

  int get _displayCount => (_endIdx - _startIdx).clamp(1, widget.quotes.length);

  ({List<double?> ma5, List<double?> ma10, List<double?> ma20}) _getAlignedMa() {
    final ma5 = <double?>[];
    final ma10 = <double?>[];
    final ma20 = <double?>[];
    const maDataStartOffset = 59;

    final isTruncated = widget.quotes.length > _defaultVisible;
    final fullQuotesStartIdx = isTruncated ? widget.quotes.length - _defaultVisible : 0;

    for (var i = 0; i < _displayCount; i++) {
      final actualQuoteIdx = fullQuotesStartIdx + i;
      final maIdx = actualQuoteIdx - maDataStartOffset;
      if (maIdx < 0 || maIdx >= widget.maData.length) {
        ma5.add(null);
        ma10.add(null);
        ma20.add(null);
      } else {
        final md = widget.maData[maIdx];
        ma5.add(md.ma5);
        ma10.add(md.ma10);
        ma20.add(md.ma20);
      }
    }
    return (ma5: ma5, ma10: ma10, ma20: ma20);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final alignedMa = _getAlignedMa();

        // Responsive padding based on screen width
        final leftPadding = w > 400 ? 56.0 : (w > 300 ? 48.0 : 40.0);
        final rightPadding = w > 400 ? 50.0 : 40.0;
        final topPadding = 8.0;
        final bottomPadding = h > 300 ? 40.0 : 30.0;
        final volumeHeight = h > 300 ? 50.0 : 35.0;

        return GestureDetector(
          onScaleUpdate: (details) {
            setState(() {
              if (details.scale != 1.0) {
                _scale = (_scale * details.scale).clamp(0.5, 4.0);
              } else {
                final dx = details.focalPointDelta.dx;
                final chartWidth = w - leftPadding - rightPadding;
                final cw = chartWidth / _displayCount;
                final idxDelta = (-dx / cw * _scale).round()
                    .clamp(-_displayCount, widget.quotes.length - _displayCount);
                _startIdx = (_startIdx + idxDelta).clamp(0, widget.quotes.length - _displayCount);
                _endIdx = _startIdx + _displayCount;
              }
            });
          },
          onTapUp: (details) {
            final chartWidth = w - leftPadding - rightPadding;
            final cw = chartWidth / _displayCount;
            final idx = ((details.localPosition.dx - leftPadding) / cw).floor();
            setState(() {
              if (idx >= 0 && idx < _displayCount) {
                _touchedIdx = idx;
                _touchPos = details.localPosition;
              } else {
                _touchedIdx = null;
                _touchPos = null;
              }
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.chartBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: CustomPaint(
              size: Size(w, h),
              painter: _CandlePainter(
                quotes: widget.quotes,
                ma5: alignedMa.ma5,
                ma10: alignedMa.ma10,
                ma20: alignedMa.ma20,
                startIdx: _startIdx,
                endIdx: _endIdx,
                scale: _scale,
                touchedIdx: _touchedIdx,
                touchPos: _touchPos,
                leftPadding: leftPadding,
                rightPadding: rightPadding,
                topPadding: topPadding,
                bottomPadding: bottomPadding,
                volumeHeight: volumeHeight,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CandlePainter extends CustomPainter {
  final List<StockQuote> quotes;
  final List<double?> ma5;
  final List<double?> ma10;
  final List<double?> ma20;
  final int startIdx;
  final int endIdx;
  final double scale;
  final int? touchedIdx;
  final Offset? touchPos;
  final double leftPadding;
  final double rightPadding;
  final double topPadding;
  final double bottomPadding;
  final double volumeHeight;

  _CandlePainter({
    required this.quotes,
    required this.ma5,
    required this.ma10,
    required this.ma20,
    required this.startIdx,
    required this.endIdx,
    required this.scale,
    this.touchedIdx,
    this.touchPos,
    required this.leftPadding,
    required this.rightPadding,
    required this.topPadding,
    required this.bottomPadding,
    required this.volumeHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (quotes.isEmpty || endIdx <= startIdx) return;

    final displayQuotes = quotes.sublist(startIdx, endIdx);
    final chartWidth = size.width - leftPadding - rightPadding;
    final priceChartHeight = size.height - topPadding - bottomPadding - volumeHeight - 10;
    final cw = chartWidth / displayQuotes.length;
    final bodyW = (cw * 0.65).clamp(2.0, 12.0);

    // Price range - ensure candles stay within bounds
    double minP = double.infinity, maxP = double.negativeInfinity;
    for (final q in displayQuotes) {
      if (q.low < minP) minP = q.low;
      if (q.high > maxP) maxP = q.high;
    }
    // Include MA values in range
    for (var i = 0; i < displayQuotes.length && i < ma5.length; i++) {
      if (ma5[i] != null) {
        if (ma5[i]! < minP) minP = ma5[i]!;
        if (ma5[i]! > maxP) maxP = ma5[i]!;
      }
      if (ma10[i] != null) {
        if (ma10[i]! < minP) minP = ma10[i]!;
        if (ma10[i]! > maxP) maxP = ma10[i]!;
      }
      if (ma20[i] != null) {
        if (ma20[i]! < minP) minP = ma20[i]!;
        if (ma20[i]! > maxP) maxP = ma20[i]!;
      }
    }

    // Add padding
    final pad = (maxP - minP) * 0.1;
    minP -= pad;
    maxP += pad;
    if (maxP <= minP) maxP = minP + 1;
    final priceRange = maxP - minP;

    // Helper function to convert price to y position (clamped)
    double p2y(double p) {
      final clampedP = p.clamp(minP, maxP);
      return topPadding + priceChartHeight * (1 - (clampedP - minP) / priceRange);
    }

    // Draw components
    _drawGrid(canvas, size, priceChartHeight, minP, maxP, p2y);
    _drawPriceLabels(canvas, size, priceChartHeight, minP, maxP, p2y);
    _drawDateLabels(canvas, size, displayQuotes, cw);
    _drawCandlesticks(canvas, size, displayQuotes, cw, bodyW, p2y, minP, maxP, chartWidth);
    _drawVolume(canvas, size, displayQuotes, cw, bodyW);
    _drawMaLines(canvas, size, displayQuotes, cw, priceChartHeight, minP, maxP, priceRange);
    _drawCrosshair(canvas, size, displayQuotes, cw, p2y);
    _drawTooltip(canvas, size, displayQuotes);
  }

  void _drawGrid(Canvas canvas, Size size, double priceChartHeight, double minP, double maxP, double Function(double) p2y) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(13)
      ..strokeWidth = 0.5;

    final step = _niceStep((maxP - minP) / 5);
    var p = (minP / step).ceil() * step;
    while (p < maxP) {
      final y = p2y(p);
      canvas.drawLine(Offset(leftPadding, y), Offset(size.width - rightPadding, y), paint);
      p += step;
    }

    // Volume separator line
    final volPaint = Paint()
      ..color = Colors.white.withAlpha(20)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(leftPadding, size.height - bottomPadding - volumeHeight - 5),
      Offset(size.width - rightPadding, size.height - bottomPadding - volumeHeight - 5),
      volPaint,
    );
  }

  void _drawPriceLabels(Canvas canvas, Size size, double priceChartHeight, double minP, double maxP, double Function(double) p2y) {
    final style = TextStyle(color: Colors.white.withAlpha(153), fontSize: 9);
    final step = _niceStep((maxP - minP) / 5);
    var p = (minP / step).ceil() * step;
    while (p < maxP) {
      final y = p2y(p);
      final tp = TextPainter(
        text: TextSpan(text: p.toStringAsFixed(2), style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPadding - tp.width - 6, y - tp.height / 2));
      p += step;
    }
  }

  void _drawDateLabels(Canvas canvas, Size size, List<StockQuote> qs, double cw) {
    if (qs.isEmpty) return;
    final step = (qs.length / 6).ceil().clamp(1, qs.length);
    final style = TextStyle(color: Colors.white.withAlpha(128), fontSize: 8);
    for (var i = 0; i < qs.length; i += step) {
      final parts = qs[i].date.split('-');
      final label = parts.length >= 2 ? '${parts[1]}/${parts[2]}' : qs[i].date;
      final x = leftPadding + i * cw;
      final tp = TextPainter(text: TextSpan(text: label, style: style), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x, size.height - bottomPadding + 8));
    }
  }

  void _drawCandlesticks(Canvas canvas, Size size, List<StockQuote> displayQuotes, double cw, double bodyW,
      double Function(double) p2y, double minP, double maxP, double chartWidth) {
    final priceAreaBottom = size.height - bottomPadding - volumeHeight - 10;

    for (var i = 0; i < displayQuotes.length; i++) {
      final q = displayQuotes[i];
      final x = leftPadding + i * cw + cw / 2;
      final isUp = q.close >= q.open;

      final bullColor = Color(0xFFDC3535);  // Red for up (Chinese convention)
      final bearColor = Color(0xFF2E8B57);  // Green for down (Chinese convention)
      final col = isUp ? bullColor : bearColor;

      // Clamp values to ensure they stay within price area
      final highY = p2y(q.high).clamp(topPadding, priceAreaBottom);
      final lowY = p2y(q.low).clamp(topPadding, priceAreaBottom);
      final openY = p2y(q.open).clamp(topPadding, priceAreaBottom);
      final closeY = p2y(q.close).clamp(topPadding, priceAreaBottom);

      // Wick
      canvas.drawLine(
        Offset(x, highY),
        Offset(x, lowY),
        Paint()..color = col..strokeWidth = 1.0,
      );

      // Body
      final bodyTop = math.min(openY, closeY);
      final bodyBot = math.max(openY, closeY);
      final bodyHeight = math.max(1.0, bodyBot - bodyTop);

      if (isUp) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - bodyW / 2, bodyTop, bodyW, bodyHeight),
            Radius.circular(1),
          ),
          Paint()..color = col,
        );
        if (bodyW > 4 && bodyHeight > 2) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x - bodyW / 2 + 1, bodyTop + 1, bodyW - 2, bodyHeight - 2),
              Radius.circular(1),
            ),
            Paint()..color = Color(0xFF1A1A2E),
          );
        }
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - bodyW / 2, bodyTop, bodyW, bodyHeight),
            Radius.circular(1),
          ),
          Paint()..color = col,
        );
      }

      // Touched highlight
      if (touchedIdx == i) {
        final highlightPaint = Paint()..color = Colors.white.withAlpha(25);
        canvas.drawRect(
          Rect.fromLTWH(leftPadding, topPadding, chartWidth, priceAreaBottom - topPadding),
          highlightPaint,
        );
      }
    }
  }

  void _drawVolume(Canvas canvas, Size size, List<StockQuote> displayQuotes, double cw, double bodyW) {
    final volTop = size.height - bottomPadding - volumeHeight;

    double maxVol = 0;
    for (final q in displayQuotes) {
      final vol = (q.close - q.open).abs();
      if (vol > maxVol) maxVol = vol;
    }
    if (maxVol == 0) maxVol = 1;

    for (var i = 0; i < displayQuotes.length; i++) {
      final q = displayQuotes[i];
      final x = leftPadding + i * cw + cw / 2;
      final isUp = q.close >= q.open;
      final col = isUp ? Color(0xFFDC3535).withAlpha(80) : Color(0xFF2E8B57).withAlpha(80);

      final volHeight = (volumeHeight * 0.9 * ((q.close - q.open).abs() / maxVol)).clamp(1.0, volumeHeight * 0.9);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - bodyW / 2, volTop + volumeHeight - volHeight, bodyW, volHeight),
          Radius.circular(1),
        ),
        Paint()..color = col,
      );
    }
  }

  void _drawMaLines(Canvas canvas, Size size, List<StockQuote> displayQuotes, double cw,
      double priceChartHeight, double minP, double maxP, double priceRange) {
    final ma5Paint = Paint()..color = Color(0xFFFF6B6B)..strokeWidth = 1.5..style = PaintingStyle.stroke;
    final ma10Paint = Paint()..color = Color(0xFF4ECDC4)..strokeWidth = 1.5..style = PaintingStyle.stroke;
    final ma20Paint = Paint()..color = Color(0xFFFFE66D)..strokeWidth = 1.5..style = PaintingStyle.stroke;

    _drawSingleMa(canvas, size, displayQuotes, cw, ma5, minP, maxP, priceChartHeight, priceRange, ma5Paint, 'MA5');
    _drawSingleMa(canvas, size, displayQuotes, cw, ma10, minP, maxP, priceChartHeight, priceRange, ma10Paint, 'MA10');
    _drawSingleMa(canvas, size, displayQuotes, cw, ma20, minP, maxP, priceChartHeight, priceRange, ma20Paint, 'MA20');
  }

  void _drawSingleMa(Canvas canvas, Size size, List<StockQuote> displayQuotes, double cw,
      List<double?> ma, double minP, double maxP, double priceChartHeight, double priceRange,
      Paint paint, String label) {
    if (ma.isEmpty) return;

    final path = Path();
    var started = false;
    double lastX = 0, lastY = 0;

    // ma is now pre-aligned to displayQuotes indices, so use i directly (not start + i)
    for (var i = 0; i < displayQuotes.length; i++) {
      final v = ma[i];
      if (v == null) continue;
      final x = leftPadding + i * cw + cw / 2;
      final clampedV = v.clamp(minP, maxP);
      final y = topPadding + priceChartHeight * (1 - (clampedV - minP) / priceRange);
      if (!started) { path.moveTo(x, y); started = true; }
      else path.lineTo(x, y);
      lastX = x;
      lastY = y;
    }

    canvas.drawPath(path, paint);

    // Label at end
    if (started) {
      final lb = TextPainter(
        text: TextSpan(text: label, style: TextStyle(color: paint.color, fontSize: 9, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelX = (lastX + 4).clamp(0.0, size.width - rightPadding - 30).toDouble();
      final labelY = lastY - lb.height - 2;
      lb.paint(canvas, Offset(labelX, labelY));
    }
  }

  void _drawCrosshair(Canvas canvas, Size size, List<StockQuote> displayQuotes, double cw,
      double Function(double) p2y) {
    if (touchedIdx == null || touchPos == null) return;

    final x = leftPadding + touchedIdx! * cw + cw / 2;
    final priceAreaBottom = size.height - bottomPadding - volumeHeight - 10;

    // Vertical line
    canvas.drawLine(
      Offset(x, topPadding),
      Offset(x, priceAreaBottom),
      Paint()..color = Colors.white.withAlpha(60)..strokeWidth = 0.5,
    );

    // Horizontal line
    final q = displayQuotes[touchedIdx!];
    final y = p2y(q.close).clamp(topPadding, priceAreaBottom);
    canvas.drawLine(
      Offset(leftPadding, y),
      Offset(size.width - rightPadding, y),
      Paint()..color = Colors.white.withAlpha(60)..strokeWidth = 0.5,
    );

    // Price tag on left
    final priceTag = TextPainter(
      text: TextSpan(text: q.close.toStringAsFixed(2), style: TextStyle(color: Colors.white, fontSize: 9)),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(leftPadding - priceTag.width - 8, y - priceTag.height / 2, priceTag.width + 8, priceTag.height),
        Radius.circular(3),
      ),
      Paint()..color = Color(0xFFDC3535),
    );
    priceTag.paint(canvas, Offset(leftPadding - priceTag.width - 4, y - priceTag.height / 2));
  }

  void _drawTooltip(Canvas canvas, Size size, List<StockQuote> displayQuotes) {
    if (touchedIdx == null || touchPos == null || touchedIdx! >= displayQuotes.length) return;

    final q = displayQuotes[touchedIdx!];
    final isUp = q.close >= q.open;
    final col = isUp ? Color(0xFFDC3535) : Color(0xFF2E8B57);
    final change = ((q.close - q.open) / q.open * 100);

    final lines = <String>[
      q.date,
      '开 ${q.open.toStringAsFixed(2)}',
      '高 ${q.high.toStringAsFixed(2)}',
      '低 ${q.low.toStringAsFixed(2)}',
      '收 ${q.close.toStringAsFixed(2)}',
      '${isUp ? '+' : ''}${change.toStringAsFixed(2)}%',
    ];

    final sty = TextStyle(color: Colors.white, fontSize: 10);
    double mw = 0;
    for (final l in lines) {
      final tp = TextPainter(text: TextSpan(text: l, style: sty), textDirection: TextDirection.ltr)..layout();
      mw = math.max(mw, tp.width);
    }

    const pad = 8.0;
    final bw = mw + pad * 2;
    final bh = lines.length * 14.0 + pad * 2;
    var tx = touchPos!.dx + 12;
    var ty = touchPos!.dy - bh / 2;

    if (tx + bw > size.width - 4) tx = touchPos!.dx - bw - 12;
    if (ty < 4) ty = 4;
    if (ty + bh > size.height - 4) ty = size.height - bh - 4;

    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(tx, ty, bw, bh), Radius.circular(8));
    canvas.drawRRect(
      rect,
      Paint()..color = Color(0xCC1A1A2E),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = col.withAlpha(30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    for (var i = 0; i < lines.length; i++) {
      final tp = TextPainter(text: TextSpan(text: lines[i], style: sty), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(tx + pad, ty + pad + i * 14));
    }
  }

  double _niceStep(double rough) {
    final e = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
    final f = rough / e;
    if (f < 1.5) return e;
    if (f < 3) return 2 * e;
    if (f < 7) return 5 * e;
    return 10 * e;
  }

  @override
  bool shouldRepaint(covariant _CandlePainter old) {
    return old.startIdx != startIdx ||
        old.endIdx != endIdx ||
        old.scale != scale ||
        old.touchedIdx != touchedIdx ||
        old.leftPadding != leftPadding ||
        old.ma5 != ma5 ||
        old.ma10 != ma10 ||
        old.ma20 != ma20;
  }
}
