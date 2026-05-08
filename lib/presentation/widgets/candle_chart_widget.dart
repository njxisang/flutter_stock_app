import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:math' as math;
import '../../domain/entities/stock_quote.dart';
import '../../core/constants/app_constants.dart';

/// Professional OHLC candlestick chart — deep dark theme, eye-care colors.
/// Supports: hollow/solid candles, multiple MAs, crosshair tooltip,
/// pinch-to-zoom, pan, and fully configurable via settings.
class CandleChartWidget extends StatefulWidget {
  final List<StockQuote> quotes;
  final List<MaData> maData;

  final bool? hollowCandle;
  final int? candleWidth;
  final double? wickWidth;
  final double? maLineWidth;
  final bool? showMa5;
  final bool? showMa10;
  final bool? showMa20;
  final bool? showMa60;
  final bool? showVolume;
  final String? colorTheme; // 'classic' | 'green_red' | 'purple'

  const CandleChartWidget({
    super.key,
    required this.quotes,
    required this.maData,
    this.hollowCandle,
    this.candleWidth,
    this.wickWidth,
    this.maLineWidth,
    this.showMa5,
    this.showMa10,
    this.showMa20,
    this.showMa60,
    this.showVolume,
    this.colorTheme,
  });

  @override
  State<CandleChartWidget> createState() => _CandleChartWidgetState();
}

class _CandleChartWidgetState extends State<CandleChartWidget> {
  int _startIdx = 0;
  int _endIdx = 0;
  final int _defaultVisible = 80;
  double _scale = 1.0;
  int? _touchedIdx;
  Offset? _touchPos;

  bool get _hollow    => widget.hollowCandle   ?? ChartConstants.defaultHollowCandle;
  int  get _candleW   => widget.candleWidth    ?? ChartConstants.defaultCandleWidth;
  double get _wickW   => widget.wickWidth      ?? ChartConstants.defaultWickWidth;
  double get _maW      => widget.maLineWidth    ?? ChartConstants.defaultMaWidth;
  bool get _showMa5   => widget.showMa5        ?? ChartConstants.defaultShowMa5;
  bool get _showMa10  => widget.showMa10       ?? ChartConstants.defaultShowMa10;
  bool get _showMa20  => widget.showMa20        ?? ChartConstants.defaultShowMa20;
  bool get _showMa60  => widget.showMa60       ?? ChartConstants.defaultShowMa60;
  bool get _showVol   => widget.showVolume      ?? ChartConstants.defaultShowVolume;
  String get _theme   => widget.colorTheme      ?? 'classic';

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

  // maData[i] corresponds to quotes[i+59]
  static const _maDataOffset = 59;

  ({List<double?> ma5, List<double?> ma10, List<double?> ma20, List<double?> ma60})
  _getAlignedMa() {
    final isTruncated = widget.quotes.length > _defaultVisible;
    final fullStart = isTruncated ? widget.quotes.length - _defaultVisible : 0;

    List<double?> align(List<double?> src) {
      return List.generate(_displayCount, (i) {
        final qIdx = fullStart + i;
        final mIdx = qIdx - _maDataOffset;
        return (mIdx >= 0 && mIdx < src.length) ? src[mIdx] : null;
      });
    }

    return (
      ma5:  align(widget.maData.map((e) => e.ma5).toList()),
      ma10: align(widget.maData.map((e) => e.ma10).toList()),
      ma20: align(widget.maData.map((e) => e.ma20).toList()),
      ma60: List<double?>.filled(_displayCount, null),
    );
  }

  ({Color bull, Color bear, Color bullWick, Color bearWick,
    Color bullVol, Color bearVol, Color bullVolA, Color bearVolA})
  _themeColors() {
    switch (_theme) {
      case 'green_red':
        return (
          bull: const Color(0xFF3A8A5A), bear: const Color(0xFFCE4040),
          bullWick: const Color(0xFF2D6E48), bearWick: const Color(0xFFB03030),
          bullVol: const Color(0xFF3A8A5A), bearVol: const Color(0xFFCE4040),
          bullVolA: const Color(0x333A8A5A), bearVolA: const Color(0x33CE4040),
        );
      case 'purple':
        return (
          bull: const Color(0xFFBA79E6), bear: const Color(0xFF6AB8FF),
          bullWick: const Color(0xFF9A5DC8), bearWick: const Color(0xFF4A98E0),
          bullVol: const Color(0xFFBA79E6), bearVol: const Color(0xFF6AB8FF),
          bullVolA: const Color(0x33BA79E6), bearVolA: const Color(0x336AB8FF),
        );
      default:
        return (
          bull: AppColors.bullBody, bear: AppColors.bearBody,
          bullWick: AppColors.bullWick, bearWick: AppColors.bearWick,
          bullVol: AppColors.volUp, bearVol: AppColors.volDown,
          bullVolA: AppColors.volUpA, bearVolA: AppColors.volDownA,
        );
    }
  }

  void _handleScale(ScaleUpdateDetails d, double chartWidth) {
    setState(() {
      if (d.scale != 1.0) {
        _scale = (_scale * d.scale).clamp(0.4, 5.0);
      } else {
        final dx = d.focalPointDelta.dx;
        final cw = chartWidth / _displayCount;
        final delta = (-dx / cw).round().clamp(-_displayCount, widget.quotes.length - _displayCount);
        _startIdx = (_startIdx + delta).clamp(0, widget.quotes.length - _displayCount);
        _endIdx = _startIdx + _displayCount;
      }
    });
  }

  void _onTapUp(TapUpDetails d, double chartW, double leftPad) {
    final cw = chartW / _displayCount;
    final idx = ((d.localPosition.dx - leftPad) / cw).floor();
    if (idx >= 0 && idx < _displayCount) {
      setState(() { _touchedIdx = idx; _touchPos = d.localPosition; });
    } else {
      setState(() { _touchedIdx = null; _touchPos = null; });
    }
  }

  void _onLongPressStart(LongPressStartDetails d, double chartW, double leftPad) {
    final cw = chartW / _displayCount;
    final idx = ((d.localPosition.dx - leftPad) / cw).floor();
    if (idx >= 0 && idx < _displayCount) {
      setState(() { _touchedIdx = idx; _touchPos = d.localPosition; });
    }
  }

  void _onLongPressMove(LongPressMoveUpdateDetails d, double chartW, double leftPad) {
    final cw = chartW / _displayCount;
    final idx = ((d.localPosition.dx - leftPad) / cw).floor();
    if (idx >= 0 && idx < _displayCount) {
      setState(() { _touchedIdx = idx; _touchPos = d.localPosition; });
    }
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    setState(() { _touchedIdx = null; _touchPos = null; });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final alignedMa = _getAlignedMa();
        final theme = _themeColors();

        final leftPad  = w > 400 ? 58.0 : (w > 320 ? 50.0 : 44.0);
        final rightPad = w > 400 ? 52.0 : 44.0;
        const topPad = 8.0;
        const botPad = 24.0;
        final volH = _showVol ? (h > 280 ? 48.0 : 36.0) : 0.0;
        const volSep = 6.0;
        final chartW = w - leftPad - rightPad;

        return Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              setState(() {
                final newVis = (_displayCount * (1 + event.scrollDelta.dy * 0.001))
                    .round().clamp(20, widget.quotes.length);
                final center = _startIdx + _displayCount ~/ 2;
                _startIdx = (center - newVis ~/ 2).clamp(0, widget.quotes.length - newVis);
                _endIdx = _startIdx + newVis;
                _scale = 1.0;
              });
            }
          },
          child: GestureDetector(
            onScaleUpdate: (d) => _handleScale(d, chartW),
            onTapUp: (d) => _onTapUp(d, chartW, leftPad),
            onLongPressStart: (d) => _onLongPressStart(d, chartW, leftPad),
            onLongPressMoveUpdate: (d) => _onLongPressMove(d, chartW, leftPad),
            onLongPressEnd: _onLongPressEnd,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.chartBackground,
                borderRadius: BorderRadius.circular(6),
              ),
              child: CustomPaint(
                size: Size(w, h),
                painter: _CandlePainter(
                  quotes: widget.quotes,
                  ma5: alignedMa.ma5,
                  ma10: alignedMa.ma10,
                  ma20: alignedMa.ma20,
                  ma60: alignedMa.ma60,
                  startIdx: _startIdx,
                  endIdx: _endIdx,
                  scale: _scale,
                  touchedIdx: _touchedIdx,
                  touchPos: _touchPos,
                  leftPad: leftPad, rightPad: rightPad,
                  topPad: topPad, botPad: botPad,
                  volH: volH, volSep: volSep,
                  hollow: _hollow,
                  candleBodyW: _candleW.toDouble(),
                  wickWidth: _wickW,
                  maLineWidth: _maW,
                  showMa5: _showMa5, showMa10: _showMa10,
                  showMa20: _showMa20, showMa60: _showMa60,
                  showVolume: _showVol,
                  bull: theme.bull, bear: theme.bear,
                  bullWick: theme.bullWick, bearWick: theme.bearWick,
                  bullVol: theme.bullVol, bearVol: theme.bearVol,
                  bullVolA: theme.bullVolA, bearVolA: theme.bearVolA,
                ),
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
  final List<double?> ma5, ma10, ma20, ma60;
  final int startIdx, endIdx;
  final double scale;
  final int? touchedIdx;
  final Offset? touchPos;
  final double leftPad, rightPad, topPad, botPad, volH, volSep;
  final bool hollow, showMa5, showMa10, showMa20, showMa60, showVolume;
  final double candleBodyW, wickWidth, maLineWidth;
  final Color bull, bear, bullWick, bearWick;
  final Color bullVol, bearVol, bullVolA, bearVolA;

  _CandlePainter({
    required this.quotes,
    required this.ma5, required this.ma10, required this.ma20, required this.ma60,
    required this.startIdx, required this.endIdx,
    required this.scale, this.touchedIdx, this.touchPos,
    required this.leftPad, required this.rightPad,
    required this.topPad, required this.botPad,
    required this.volH, required this.volSep,
    required this.hollow,
    required this.candleBodyW, required this.wickWidth, required this.maLineWidth,
    required this.showMa5, required this.showMa10,
    required this.showMa20, required this.showMa60, required this.showVolume,
    required this.bull, required this.bear,
    required this.bullWick, required this.bearWick,
    required this.bullVol, required this.bearVol,
    required this.bullVolA, required this.bearVolA,
  });

  // ── Compute visible price range (including MA lines) ──────────────────────
  double get _minP {
    double m = double.infinity;
    for (final q in quotes.sublist(startIdx, endIdx)) { if (q.low < m) m = q.low; }
    void consider(double? v) { if (v != null && v < m) m = v; }
    for (final v in ma5)  consider(v);
    for (final v in ma10) consider(v);
    for (final v in ma20) consider(v);
    for (final v in ma60) consider(v);
    return m == double.infinity ? 0 : m;
  }

  double get _maxP {
    double m = double.negativeInfinity;
    for (final q in quotes.sublist(startIdx, endIdx)) { if (q.high > m) m = q.high; }
    void consider(double? v) { if (v != null && v > m) m = v; }
    for (final v in ma5)  consider(v);
    for (final v in ma10) consider(v);
    for (final v in ma20) consider(v);
    for (final v in ma60) consider(v);
    return m == double.negativeInfinity ? 1 : m;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (quotes.isEmpty || endIdx <= startIdx) return;

    final displayQuotes = quotes.sublist(startIdx, endIdx);
    final chartW = size.width - leftPad - rightPad;
    final mainChartH = size.height - topPad - botPad - (showVolume ? volH + volSep : 0);
    final cw = chartW / displayQuotes.length;
    final bodyW = candleBodyW.clamp(3.0, 16.0);

    final pricePad = (_maxP - _minP) * 0.08;
    final minP = _minP - pricePad;
    final maxP = _maxP + pricePad;
    final priceRange = maxP - minP;
    if (priceRange <= 0) return;

    double p2y(double p) => topPad + mainChartH * (1 - (p.clamp(minP, maxP) - minP) / priceRange);
    final priceAreaBottom = topPad + mainChartH;

    _drawGrid(canvas, size, p2y, minP, maxP);
    _drawPriceLabels(canvas, p2y, minP, maxP);
    _drawDateLabels(canvas, size, displayQuotes, cw);
    _drawCandlesticks(canvas, displayQuotes, cw, bodyW, p2y, priceAreaBottom);
    _drawVolume(canvas, size, displayQuotes, cw, bodyW);
    _drawMaLines(canvas, displayQuotes, cw, p2y, minP, maxP, mainChartH);
    _drawCrosshair(canvas, size, displayQuotes, cw, p2y, priceAreaBottom);
    _drawTooltip(canvas, size, displayQuotes, cw, priceAreaBottom);
  }

  // ── Grid ──────────────────────────────────────────────────────────────────
  void _drawGrid(Canvas canvas, Size size, double Function(double) p2y,
      double minP, double maxP) {
    final paint = Paint()
      ..color = AppColors.gridLine
      ..strokeWidth = 0.4;

    final step = _niceStep((maxP - minP) / 5);
    var p = (minP / step).ceil() * step;
    while (p < maxP) {
      canvas.drawLine(Offset(leftPad, p2y(p)), Offset(size.width - rightPad, p2y(p)), paint);
      p += step;
    }

    if (showVolume) {
      final sepY = size.height - botPad - volH;
      canvas.drawLine(
        Offset(leftPad, sepY),
        Offset(size.width - rightPad, sepY),
        Paint()..color = AppColors.gridLine..strokeWidth = 0.6,
      );
    }
  }

  // ── Price Labels ────────────────────────────────────────────────────────────
  void _drawPriceLabels(Canvas canvas, double Function(double) p2y, double minP, double maxP) {
    final style = TextStyle(color: AppColors.axisLabel, fontSize: 8.5);
    final step = _niceStep((maxP - minP) / 5);
    var p = (minP / step).ceil() * step;
    while (p < maxP) {
      final y = p2y(p);
      final tp = TextPainter(
        text: TextSpan(text: _fmtPrice(p), style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 5, y - tp.height / 2));
      p += step;
    }
  }

  String _fmtPrice(double p) {
    if (p >= 10000) return '${(p / 1000).toStringAsFixed(1)}k';
    if (p >= 100)   return p.toStringAsFixed(1);
    return p.toStringAsFixed(2);
  }

  // ── Date Labels ────────────────────────────────────────────────────────────
  void _drawDateLabels(Canvas canvas, Size size,
      List<StockQuote> qs, double cw) {
    if (qs.isEmpty) return;
    final step = (qs.length / 6).ceil().clamp(1, qs.length);
    final style = TextStyle(color: AppColors.axisLabel, fontSize: 8);
    final y = size.height - botPad + 6;
    for (var i = 0; i < qs.length; i += step) {
      final parts = qs[i].date.split('-');
      final label = parts.length >= 3 ? '${parts[1]}/${parts[2]}' : qs[i].date;
      final tp = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad + i * cw, y));
    }
  }

  // ── Candlesticks ──────────────────────────────────────────────────────────
  void _drawCandlesticks(Canvas canvas, List<StockQuote> qs, double cw,
      double bodyW, double Function(double) p2y, double priceAreaBottom) {
    for (var i = 0; i < qs.length; i++) {
      final q = qs[i];
      final x = leftPad + i * cw + cw / 2;
      final isUp  = q.close >= q.open;
      final isFlat = (q.close - q.open).abs() < 0.001;

      final highY  = p2y(q.high).clamp(topPad, priceAreaBottom);
      final lowY    = p2y(q.low).clamp(topPad, priceAreaBottom);
      final openY   = p2y(q.open).clamp(topPad, priceAreaBottom);
      final closeY  = p2y(q.close).clamp(topPad, priceAreaBottom);

      // Wick — thin for elegance
      canvas.drawLine(
        Offset(x, highY), Offset(x, lowY),
        Paint()..color = isUp ? bullWick : bearWick ..strokeWidth = wickWidth,
      );

      // Body
      final bodyTop = math.min(openY, closeY);
      final bodyBot = math.max(openY, closeY);
      final bodyH   = math.max(1.0, bodyBot - bodyTop);
      final bodyRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - bodyW / 2, bodyTop, bodyW, bodyH),
        Radius.circular(1.2),
      );

      if (isUp) {
        if (hollow && bodyW > 4 && bodyH > 3) {
          canvas.drawRRect(
            bodyRect,
            Paint()
              ..color = bull
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.3,
          );
        } else {
          canvas.drawRRect(bodyRect, Paint()..color = bull);
        }
      } else {
        canvas.drawRRect(bodyRect, Paint()..color = bear);
      }
    }
  }

  // ── Volume ────────────────────────────────────────────────────────────────
  void _drawVolume(Canvas canvas, Size size, List<StockQuote> qs,
      double cw, double bodyW) {
    if (!showVolume) return;
    final volTop = size.height - botPad - volH;

    double maxVol = 1;
    for (final q in qs) {
      final v = (q.close - q.open).abs();
      if (v > maxVol) maxVol = v;
    }

    for (var i = 0; i < qs.length; i++) {
      final q = qs[i];
      final x = leftPad + i * cw + cw / 2;
      final isUp = q.close >= q.open;
      final col  = isUp ? bullVol  : bearVol;
      final colA = isUp ? bullVolA : bearVolA;
      final vH   = (volH * 0.85 * ((q.close - q.open).abs() / maxVol)).clamp(1.0, volH * 0.85);

      // Background
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - bodyW / 2, volTop, bodyW, volH),
          Radius.circular(1.0),
        ),
        Paint()..color = colA,
      );
      // Filled
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - bodyW / 2, volTop + volH - vH, bodyW, vH),
          Radius.circular(1.0),
        ),
        Paint()..color = col,
      );
    }
  }

  // ── MA Lines ─────────────────────────────────────────────────────────────
  void _drawMaLines(Canvas canvas, List<StockQuote> qs, double cw,
      double Function(double) p2y, double minP, double maxP, double mainChartH) {
    final priceRange = maxP - minP;

    void drawMa(List<double?> ma, Color color, String label) {
      if (ma.isEmpty || ma.every((v) => v == null)) return;
      final path = Path();
      var started = false;
      double lastX = 0, lastY = 0;

      for (var i = 0; i < qs.length; i++) {
        final v = ma[i];
        if (v == null) continue;
        final x = leftPad + i * cw + cw / 2;
        final y = p2y(v.clamp(minP, maxP));
        if (!started) { path.moveTo(x, y); started = true; }
        else path.lineTo(x, y);
        lastX = x; lastY = y;
      }

      if (!started) return;

      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = maLineWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      // MA label near last point
      final lb = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: color.withAlpha(200), fontSize: 8.5, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final lx = lastX + 3;
      final ly = (lastY - lb.height - 1).clamp(topPad, topPad + mainChartH - lb.height);
      lb.paint(canvas, Offset(lx, ly));
    }

    if (showMa5)  drawMa(ma5,  AppColors.ma5Color,  'MA5');
    if (showMa10) drawMa(ma10, AppColors.ma10Color, 'MA10');
    if (showMa20) drawMa(ma20, AppColors.ma20Color, 'MA20');
    if (showMa60) drawMa(ma60, AppColors.ma60Color, 'MA60');
  }

  // ── Crosshair ─────────────────────────────────────────────────────────────
  void _drawCrosshair(Canvas canvas, Size size, List<StockQuote> qs,
      double cw, double Function(double) p2y, double priceAreaBottom) {
    if (touchedIdx == null || touchPos == null) return;
    if (touchedIdx! < 0 || touchedIdx! >= qs.length) return;

    final i = touchedIdx!;
    final x = leftPad + i * cw + cw / 2;
    final q = qs[i];
    final y = p2y(q.close).clamp(topPad, priceAreaBottom);
    final isUp = q.close >= q.open;
    final tagCol = isUp ? bull : bear;

    // Vertical
    canvas.drawLine(
      Offset(x, topPad), Offset(x, priceAreaBottom),
      Paint()..color = AppColors.crosshairLine..strokeWidth = 0.6,
    );
    // Horizontal
    canvas.drawLine(
      Offset(leftPad, y), Offset(size.width - rightPad, y),
      Paint()..color = AppColors.crosshairLine..strokeWidth = 0.6,
    );

    // Price tag (right of dot, coloured pill)
    const tagPad = 4.0;
    final priceTp = TextPainter(
      text: TextSpan(
        text: q.close.toStringAsFixed(2),
        style: TextStyle(color: AppColors.crosshairTagText, fontSize: 9, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final tagW = priceTp.width + tagPad * 2;
    final tagH = priceTp.height + tagPad * 1.5;
    var tagX = (x + 4).clamp(0.0, size.width - rightPad - tagW);
    var tagY = (y - tagH / 2).clamp(topPad, priceAreaBottom - tagH);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(tagX, tagY, tagW, tagH), Radius.circular(4)),
      Paint()..color = tagCol,
    );
    priceTp.paint(canvas, Offset(tagX + tagPad, tagY + tagPad / 2));

    // Date tag at bottom
    final parts = q.date.split('-');
    final dateStr = parts.length >= 3 ? '${parts[0]}-${parts[1]}-${parts[2]}' : q.date;
    final dtp = TextPainter(
      text: TextSpan(
        text: dateStr,
        style: TextStyle(color: AppColors.crosshairTagText, fontSize: 9, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dtpW = dtp.width + tagPad * 2;
    final dtpH = dtp.height + tagPad * 1.5;
    final dtpX = (x - dtpW / 2).clamp(leftPad, size.width - rightPad - dtpW);
    final dtpY = size.height - botPad;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(dtpX, dtpY, dtpW, dtpH), Radius.circular(4)),
      Paint()..color = AppColors.crosshairTagBg,
    );
    dtp.paint(canvas, Offset(dtpX + tagPad, dtpY + tagPad / 2));
  }

  // ── Tooltip ──────────────────────────────────────────────────────────────
  void _drawTooltip(Canvas canvas, Size size, List<StockQuote> qs,
      double cw, double priceAreaBottom) {
    if (touchedIdx == null || touchPos == null) return;
    if (touchedIdx! < 0 || touchedIdx! >= qs.length) return;

    final q = qs[touchedIdx!];
    final isUp  = q.close >= q.open;
    final isFlat = (q.close - q.open).abs() < 0.001;
    final col    = isUp ? bull : bear;
    final change = ((q.close - q.open) / q.open * 100);

    final rows = <String, String>{
      '日期': q.date,
      '开': q.open.toStringAsFixed(2),
      '高': q.high.toStringAsFixed(2),
      '低': q.low.toStringAsFixed(2),
      '收': q.close.toStringAsFixed(2),
      '涨跌': '${isFlat ? '' : (isUp ? '+' : '')}${change.toStringAsFixed(2)}%',
      '量': _fmtVol(q.volume),
    };

    const pad = 8.0;
    const rowH = 15.0;
    const labelW = 28.0;
    final sty = TextStyle(color: AppColors.textPrimary, fontSize: 10);

    double maxW = 0;
    for (final e in rows.entries) {
      final lp = TextPainter(text: TextSpan(text: e.key, style: TextStyle(color: AppColors.textSecondary, fontSize: 10)), textDirection: TextDirection.ltr)..layout();
      final vp = TextPainter(text: TextSpan(text: e.value, style: sty), textDirection: TextDirection.ltr)..layout();
      maxW = math.max(maxW, labelW + lp.width + 4 + vp.width);
    }

    final bw = maxW + pad * 2;
    final bh = rows.length * rowH + pad * 2;
    var tx = touchPos!.dx + 14;
    var ty = (touchPos!.dy - bh / 2).clamp(4.0, size.height - bh - 4);
    if (tx + bw > size.width - 4) tx = touchPos!.dx - bw - 14;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(tx, ty, bw, bh), Radius.circular(8),
    );
    canvas.drawRRect(rect, Paint()..color = AppColors.tooltipBg);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = col.withAlpha(40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    var row = 0;
    for (final e in rows.entries) {
      final lp = TextPainter(
        text: TextSpan(text: e.key, style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      final vp = TextPainter(
        text: TextSpan(text: e.value, style: sty),
        textDirection: TextDirection.ltr,
      )..layout();
      lp.paint(canvas, Offset(tx + pad, ty + pad + row * rowH));
      vp.paint(canvas, Offset(tx + pad + labelW + 2, ty + pad + row * rowH));
      row++;
    }
  }

  String _fmtVol(num v) {
    if (v >= 1e8) return '${(v / 1e8).toStringAsFixed(2)}亿';
    if (v >= 1e4) return '${(v / 1e4).toStringAsFixed(0)}万';
    return '$v';
  }

  double _niceStep(double rough) {
    if (rough <= 0) return 1;
    final e = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
    final f = rough / e;
    if (f < 1.5) return e;
    if (f < 3)   return 2 * e;
    if (f < 7)   return 5 * e;
    return 10 * e;
  }

  @override
  bool shouldRepaint(covariant _CandlePainter old) {
    return old.startIdx != startIdx ||
        old.endIdx != endIdx ||
        old.scale != scale ||
        old.touchedIdx != touchedIdx ||
        old.hollow != hollow ||
        old.candleBodyW != candleBodyW ||
        old.maLineWidth != maLineWidth ||
        old.showMa5 != showMa5 ||
        old.showMa10 != showMa10 ||
        old.showMa20 != showMa20 ||
        old.showMa60 != showMa60 ||
        old.showVolume != showVolume ||
        old.ma5 != ma5 ||
        old.ma10 != ma10 ||
        old.ma20 != ma20 ||
        old.ma60 != ma60;
  }
}
