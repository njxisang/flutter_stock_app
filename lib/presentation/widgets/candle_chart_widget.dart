import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:math' as math;
import '../../domain/entities/stock_quote.dart';
import '../../core/constants/app_constants.dart';
import 'charts/candle_painter.dart';

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

  // ── Quick range buttons ──────────────────────────────────────────────────
  static const _rangeOptions = [
    (label: '1月', days: 22),
    (label: '3月', days: 66),
    (label: '6月', days: 126),
    (label: '1年', days: 242),
  ];
  int _selectedRangeIdx = -1; // -1 = free scroll

  // ── Horizontal pan ────────────────────────────────────────────────────────
  double? _lastPanDx; // last horizontal drag offset in px
  int? _lastPanBaseIdx; // _startIdx at drag start

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
    _initRange();
  }

  void _initRange() {
    _endIdx = widget.quotes.length;
    _startIdx = math.max(0, _endIdx - _defaultVisible);
  }

  @override
  void didUpdateWidget(CandleChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quotes.length != widget.quotes.length) {
      _initRange();
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

  void _selectRange(int idx) {
    if (idx == _selectedRangeIdx) {
      // Deselect — return to full scroll
      setState(() { _selectedRangeIdx = -1; });
      _initRange();
      return;
    }
    setState(() => _selectedRangeIdx = idx);
    final days = _rangeOptions[idx].days;
    final n = days.clamp(20, widget.quotes.length);
    setState(() {
      _endIdx = widget.quotes.length;
      _startIdx = (widget.quotes.length - n).clamp(0, widget.quotes.length - 1);
    });
  }

  // ── Horizontal pan ────────────────────────────────────────────────────────
  void _onPanStart(DragStartDetails d, double chartW) {
    _lastPanDx = d.localPosition.dx;
    _lastPanBaseIdx = _startIdx;
  }

  void _onPanUpdate(DragUpdateDetails d, double chartW) {
    if (_lastPanDx == null) return;
    final dx = _lastPanDx! - d.localPosition.dx; // positive = drag right → earlier data
    final cw = chartW / _displayCount;
    final candlesShift = (dx / cw).round();
    if (candlesShift == 0) return;
    setState(() {
      _startIdx = (candlesShift + _startIdx).clamp(0, widget.quotes.length - _displayCount);
      _endIdx = (_startIdx + _displayCount).clamp(0, widget.quotes.length);
      _selectedRangeIdx = -1;
    });
    _lastPanDx = d.localPosition.dx;
  }

  void _onPanEnd(DragEndDetails d) {
    _lastPanDx = null;
    _lastPanBaseIdx = null;
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

        // Reserve ~28px at the top for the quick-range buttons bar
        const rangeBarH = 28.0;
        final rawChartH = h - rangeBarH;
        final chartH = rawChartH > 0 ? rawChartH : h;

        final alignedMa = _getAlignedMa();
        final theme = _themeColors();

        final leftPad  = w > 400 ? 58.0 : (w > 320 ? 50.0 : 44.0);
        final rightPad = w > 400 ? 52.0 : 44.0;
        const topPad = 8.0;
        const botPad = 24.0;
        final volH = _showVol ? (chartH > 280 ? 36.0 : 28.0) : 0.0;
        const volSep = 6.0;
        final chartW = w - leftPad - rightPad;

        return Column(
          children: [
            // ── Quick range buttons ─────────────────────────────────────────
            SizedBox(
              height: rangeBarH,
              child: Row(
                children: [
                  SizedBox(width: leftPad),
                  ...List.generate(_rangeOptions.length, (i) {
                    final selected = _selectedRangeIdx == i;
                    return GestureDetector(
                      onTap: () => _selectRange(i),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withAlpha(30)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: selected ? AppColors.primary : AppColors.border,
                            width: selected ? 1.2 : 0.8,
                          ),
                        ),
                        child: Text(
                          _rangeOptions[i].label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            color: selected ? AppColors.primary : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }),
                  const Spacer(),
                ],
              ),
            ),
            // ── Chart canvas ────────────────────────────────────────────────
            Expanded(
              child: Listener(
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
                  onHorizontalDragStart: (d) => _onPanStart(d, chartW),
                  onHorizontalDragUpdate: (d) => _onPanUpdate(d, chartW),
                  onHorizontalDragEnd: _onPanEnd,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.chartBackground,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: CustomPaint(
                      size: Size(w, chartH),
                      painter: CandlePainter(
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
              ),
            ),
          ],
        );
      },
    );
  }
}
