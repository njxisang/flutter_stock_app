import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../domain/entities/stock_quote.dart';
import '../../core/constants/app_constants.dart';

/// Real OHLC candlestick chart with MA overlays using CustomPainter.
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

  int get _displayCount => (_endIdx - _startIdx).clamp(1, widget.quotes.length);

  /// Returns MA arrays aligned with displayQuotes.
  /// maData[i] corresponds to quotes[i + MA_DATA_START_OFFSET] in the full quotes list.
  /// Since displayQuotes is a sublist of the last N quotes, we need to map display indices
  /// to maData indices correctly.
  ({List<double?> ma5, List<double?> ma10, List<double?> ma20}) _getAlignedMa() {
    final ma5 = <double?>[];
    final ma10 = <double?>[];
    final ma20 = <double?>[];
    // maData starts from index 59 in the full quotes list (first point where MA60 is valid)
    const maDataStartOffset = 59;

    // Calculate the index in the full quotes list where displayQuotes starts
    final isTruncated = widget.quotes.length > _defaultVisible;
    final fullQuotesStartIdx = isTruncated ? widget.quotes.length - _defaultVisible : 0;

    for (var i = 0; i < _displayCount; i++) {
      // The actual index in the full quotes list for this display element
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

        return GestureDetector(
          onScaleUpdate: (details) {
            setState(() {
              if (details.scale != 1.0) {
                _scale = (_scale * details.scale).clamp(0.5, 4.0);
              } else {
                final dx = details.focalPointDelta.dx;
                final cw = w / _displayCount;
                final idxDelta = (-dx / cw * _scale).round().clamp(-_displayCount, widget.quotes.length - _displayCount);
                _startIdx = (_startIdx + idxDelta).clamp(0, widget.quotes.length - _displayCount);
                _endIdx = _startIdx + _displayCount;
              }
            });
          },
          onTapUp: (details) {
            final cw = w / _displayCount;
            final idx = ((details.localPosition.dx / cw) - 0.5).floor();
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
          onPanUpdate: (d) {
            if (_touchedIdx != null) setState(() => _touchPos = d.localPosition);
          },
          onPanEnd: (_) => setState(() { _touchedIdx = null; _touchPos = null; }),
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
              defaultVisible: _defaultVisible,
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
  final int defaultVisible;

  static const double _lp = 8.0;
  static const double _rp = 55.0;
  static const double _tp = 8.0;
  static const double _bp = 24.0;

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
    required this.defaultVisible,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (quotes.isEmpty || endIdx <= startIdx) return;

    final displayQuotes = quotes.sublist(startIdx, endIdx);
    final cw = (size.width - _lp - _rp) / (displayQuotes.length > 0 ? displayQuotes.length : 1);
    final bodyW = (cw * 0.70).clamp(3.0, 16.0);

    // Price range
    double minP = double.infinity, maxP = double.negativeInfinity;
    for (final q in displayQuotes) {
      if (q.low < minP) minP = q.low;
      if (q.high > maxP) maxP = q.high;
    }
    final pad = (maxP - minP) * 0.06;
    minP -= pad;
    maxP += pad;
    final priceRange = maxP - minP;
    final ch = size.height - _tp - _bp;

    double p2y(double p) => _tp + ch * (1 - (p - minP) / priceRange);

    // Grid
    _drawGrid(canvas, size, ch, minP, maxP);

    // Price labels
    _drawPriceLabels(canvas, size, ch, minP, maxP);

    // Date labels
    _drawDateLabels(canvas, size, displayQuotes, cw);

    // Candlesticks
    for (var i = 0; i < displayQuotes.length; i++) {
      final q = displayQuotes[i];
      final x = _lp + i * cw + cw / 2;
      final isUp = q.close >= q.open;
      final col = isUp ? AppColors.bullish : AppColors.bearish;

      // Wick
      canvas.drawLine(Offset(x, p2y(q.high)), Offset(x, p2y(q.low)),
          Paint()..color = col..strokeWidth = 1.0);

      // Body
      final bodyTop = math.min(p2y(q.open), p2y(q.close));
      final bodyBot = math.max(p2y(q.open), p2y(q.close));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - bodyW / 2, bodyTop, bodyW, math.max(1.0, bodyBot - bodyTop)),
          const Radius.circular(1),
        ),
        Paint()..color = col,
      );

      // Touched highlight
      if (touchedIdx == i) {
        canvas.drawRect(Rect.fromLTWH(_lp, _tp, size.width - _lp - _rp, ch),
            Paint()..color = Colors.amber.withAlpha(60));
        // Touched line
        canvas.drawLine(Offset(x, _tp), Offset(x, size.height - _bp),
            Paint()..color = Colors.amber.withAlpha(100)..strokeWidth = 1.0);
      }
    }

    // MA overlays
    _drawMa(canvas, displayQuotes, cw, ma5, startIdx, ch, minP, priceRange, AppColors.ma5Color, 'MA5');
    _drawMa(canvas, displayQuotes, cw, ma10, startIdx, ch, minP, priceRange, AppColors.ma10Color, 'MA10');
    _drawMa(canvas, displayQuotes, cw, ma20, startIdx, ch, minP, priceRange, AppColors.ma20Color, 'MA20');

    // Tooltip
    if (touchedIdx != null && touchPos != null && touchedIdx! < displayQuotes.length) {
      _drawTooltip(canvas, size, displayQuotes[touchedIdx!], touchPos!);
    }
  }

  void _drawGrid(Canvas canvas, Size size, double ch, double minP, double maxP) {
    final paint = Paint()..color = Colors.grey.withAlpha(40)..strokeWidth = 0.5;
    final step = _niceStep((maxP - minP) / 5);
    var p = (minP / step).ceil() * step;
    while (p < maxP) {
      final y = _tp + ch * (1 - (p - minP) / (maxP - minP));
      canvas.drawLine(Offset(_lp, y), Offset(size.width - _rp, y), paint);
      p += step;
    }
  }

  void _drawPriceLabels(Canvas canvas, Size size, double ch, double minP, double maxP) {
    final style = TextStyle(color: AppColors.textSecondary, fontSize: 9);
    final step = _niceStep((maxP - minP) / 5);
    var p = (minP / step).ceil() * step;
    while (p < maxP) {
      final y = _tp + ch * (1 - (p - minP) / (maxP - minP));
      final tp = TextPainter(text: TextSpan(text: p.toStringAsFixed(2), style: style), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(size.width - _rp + 4, y - tp.height / 2));
      p += step;
    }
  }

  void _drawDateLabels(Canvas canvas, Size size, List<StockQuote> qs, double cw) {
    if (qs.isEmpty) return;
    final step = (qs.length / 5).ceil().clamp(1, qs.length);
    final style = TextStyle(color: AppColors.textSecondary, fontSize: 8);
    for (var i = 0; i < qs.length; i += step) {
      final parts = qs[i].date.split('-');
      final label = parts.length >= 2 ? '${parts[1]}-${parts[2]}' : qs[i].date;
      final x = _lp + i * cw;
      final tp = TextPainter(text: TextSpan(text: label, style: style), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x, size.height - _bp + 4));
    }
  }

  void _drawMa(Canvas canvas, List<StockQuote> displayQuotes, double cw,
      List<double?> ma, int start, double ch, double minP, double priceRange,
      Color color, String label) {
    if (ma.isEmpty) return;

    final path = Path();
    var started = false;
    double lastX = 0, lastY = 0;

    // ma is now pre-aligned to displayQuotes indices, so use i directly (not start + i)
    for (var i = 0; i < displayQuotes.length; i++) {
      final v = ma[i];
      if (v == null) continue;
      final x = _lp + i * cw + cw / 2;
      final y = _tp + ch * (1 - (v - minP) / priceRange);
      if (!started) { path.moveTo(x, y); started = true; }
      else path.lineTo(x, y);
      lastX = x;
      lastY = y;
    }

    canvas.drawPath(path, Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke);

    // Label at end
    if (started) {
      final lb = TextPainter(
        text: TextSpan(text: label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      lb.paint(canvas, Offset((lastX + 4).clamp(0, canvas.getLocalClipBounds().width - 30), lastY - lb.height - 1));
    }
  }

  void _drawTooltip(Canvas canvas, Size size, StockQuote q, Offset pos) {
    final isUp = q.close >= q.open;
    final bg = (isUp ? AppColors.bullish : AppColors.bearish).withAlpha(235);
    final lines = <String>[
      '日期: ${q.date}',
      '开: ${q.open.toStringAsFixed(2)}',
      '高: ${q.high.toStringAsFixed(2)}',
      '低: ${q.low.toStringAsFixed(2)}',
      '收: ${q.close.toStringAsFixed(2)}',
      '涨跌: ${((q.close - q.open) / q.open * 100).toStringAsFixed(2)}%',
    ];
    final sty = const TextStyle(color: Colors.white, fontSize: 10);
    double mw = 0;
    for (final l in lines) {
      final tp = TextPainter(text: TextSpan(text: l, style: sty), textDirection: TextDirection.ltr)..layout();
      mw = math.max(mw, tp.width);
    }
    const pad = 8.0;
    final bw = mw + pad * 2;
    final bh = lines.length * 13.0 + pad * 2;
    var tx = pos.dx + 12;
    var ty = pos.dy - bh / 2;
    if (tx + bw > size.width - 4) tx = pos.dx - bw - 12;
    ty = ty.clamp(4.0, size.height - bh - 4.0);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(tx, ty, bw, bh), const Radius.circular(6)),
      Paint()..color = bg,
    );
    for (var i = 0; i < lines.length; i++) {
      final tp = TextPainter(text: TextSpan(text: lines[i], style: sty), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(tx + pad, ty + pad + i * 13));
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
        old.defaultVisible != defaultVisible ||
        old.ma5 != ma5 ||
        old.ma10 != ma10 ||
        old.ma20 != ma20;
  }
}
