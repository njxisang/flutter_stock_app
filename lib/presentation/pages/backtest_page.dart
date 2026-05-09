import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_constants.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/stock_quote.dart';
import '../../domain/usecases/calculators/backtest_calculator.dart';
import '../blocs/stock/stock_bloc.dart';

class BacktestPage extends StatefulWidget {
  const BacktestPage({super.key});

  @override
  State<BacktestPage> createState() => _BacktestPageState();
}

class _BacktestPageState extends State<BacktestPage> {
  BacktestStrategy _selectedStrategy = BacktestStrategy.macd;
  final _initialCapitalController = TextEditingController(text: '100000');
  final _feeRateController = TextEditingController(text: '0.001');
  final _positionRatioController = TextEditingController(text: '1.0');

  BacktestResult? _result;
  bool _isRunning = false;
  bool _isLoadingData = false;

  // ─── 多参数批量回测 ───
  List<_ParamComboResult> _batchResults = [];
  bool _showBatchPanel = false;

  // ─── U-6: 批量比较排序 ───
  String _sortColumn = '收益率'; // 收益率/胜率/夏普/最大回撤/交易数
  bool _sortAsc = false;

  // ─── U-7: 交易记录筛选器 ───
  String _tradeFilter = '全部'; // 全部/盈利/亏损

  // ─── 参数编辑 ───
  bool _showAdvancedParams = false;
  StrategyParams _params = const StrategyParams();

  // ─── B-4 Fix: 统一管理 TextEditingController，避免内存泄漏 ───
  final Map<String, TextEditingController> _paramControllers = {};

  // ─── 日期 ───
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 365));
  DateTime _endDate = DateTime.now();
  final _dateFormat = DateFormat('yyyy-MM-dd');

  // ─── 预置参数组合（多参数比较用）───
  List<StrategyParams> _presetCombos = [];

  // ─── S-4: 止损止盈参数 ───
  double? _stopLossPercent;
  double? _takeProfitPercent;
  bool _enableTimeExit = false;
  int _maxHoldingDays = 20;
  double? _slippagePercent;

  // ─── S-4: 出场模板 ───
  List<ExitTemplate> _exitTemplates = [];
  String? _selectedTemplateName;

  // ─── S-4: 出场参数 TextEditingController（B-4 Fix: 预创建避免重建）───
  final _stopLossController = TextEditingController();
  final _takeProfitController = TextEditingController();
  final _maxHoldingDaysController = TextEditingController(text: '20');
  final _slippageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _buildDefaultPresets();
    // B-4 Fix: 初始化策略参数 TextEditingController
    _initParamControllers();
    // U-1: 从本地存储恢复上次参数
    _loadBacktestParams();
    // S-4: 加载出场模板列表
    _loadExitTemplates();
  }

  void _loadBacktestParams() {
    try {
      final bloc = context.read<StockBloc>();
      final saved = bloc.stockStorage.getBacktestParams();
      if (saved.isEmpty) return;
      setState(() {
        if (saved['strategy'] != null) {
          _selectedStrategy = BacktestStrategy.values.firstWhere(
            (e) => e.name == saved['strategy'],
            orElse: () => _selectedStrategy,
          );
        }
        if (saved['initialCapital'] != null) {
          _initialCapitalController.text = saved['initialCapital'].toString();
        }
        if (saved['feeRate'] != null) {
          _feeRateController.text = saved['feeRate'].toString();
        }
        if (saved['positionRatio'] != null) {
          _positionRatioController.text = saved['positionRatio'].toString();
        }
        if (saved['startDate'] != null) {
          _startDate = DateTime.tryParse(saved['startDate']) ?? _startDate;
        }
        if (saved['endDate'] != null) {
          _endDate = DateTime.tryParse(saved['endDate']) ?? _endDate;
        }
        if (saved['params'] != null) {
          _params = strategyParamsFromJson(saved['params']);
          // 同步更新 controller 显示值
          _syncControllersFromParams();
        }
        // S-4: 加载止损止盈参数
        if (saved['stopLossPercent'] != null) {
          _stopLossPercent = (saved['stopLossPercent'] as num).toDouble();
        }
        if (saved['takeProfitPercent'] != null) {
          _takeProfitPercent = (saved['takeProfitPercent'] as num).toDouble();
        }
        _enableTimeExit = saved['enableTimeExit'] as bool? ?? false;
        _maxHoldingDays = saved['maxHoldingDays'] as int? ?? 20;
        if (saved['slippagePercent'] != null) {
          _slippagePercent = (saved['slippagePercent'] as num).toDouble();
        }
        _syncExitControllersFromState();
      });
    } catch (_) {}
  }

  void _syncControllersFromParams() {
    _paramControllers['macdFastPeriod']?.text    = _params.macdFastPeriod.toString();
    _paramControllers['macdSlowPeriod']?.text    = _params.macdSlowPeriod.toString();
    _paramControllers['macdSignalPeriod']?.text  = _params.macdSignalPeriod.toString();
    _paramControllers['kdjPeriod']?.text        = _params.kdjPeriod.toString();
    _paramControllers['kdjKPeriod']?.text        = _params.kdjKPeriod.toString();
    _paramControllers['kdjDPeriod']?.text         = _params.kdjDPeriod.toString();
    _paramControllers['kdjOverbought']?.text    = _params.kdjOverbought.toString();
    _paramControllers['kdjOversold']?.text      = _params.kdjOversold.toString();
    _paramControllers['rsiPeriod']?.text         = _params.rsiPeriod.toString();
    _paramControllers['rsiOverbought']?.text     = _params.rsiOverbought.toString();
    _paramControllers['rsiOversold']?.text       = _params.rsiOversold.toString();
    _paramControllers['bollPeriod']?.text        = _params.bollPeriod.toString();
    _paramControllers['bollStdDev']?.text         = _params.bollStdDev.toString();
    _paramControllers['maShortPeriod']?.text      = _params.maShortPeriod.toString();
    _paramControllers['maMidPeriod']?.text        = _params.maMidPeriod.toString();
    _paramControllers['maLongPeriod']?.text       = _params.maLongPeriod.toString();
    _paramControllers['wrPeriod']?.text           = _params.wrPeriod.toString();
    _paramControllers['wrOverbought']?.text       = _params.wrOverbought.toString();
    _paramControllers['wrOversold']?.text         = _params.wrOversold.toString();
    _paramControllers['dmiPeriod']?.text           = _params.dmiPeriod.toString();
    _paramControllers['dmiAdxPeriod']?.text       = _params.dmiAdxPeriod.toString();
    _paramControllers['dmiTrendThreshold']?.text  = _params.dmiTrendThreshold.toString();
    _paramControllers['cciPeriod']?.text           = _params.cciPeriod.toString();
    _paramControllers['stochRsiPeriod']?.text    = _params.stochRsiPeriod.toString();
    _paramControllers['stochRsiKPeriod']?.text   = _params.stochRsiKPeriod.toString();
    _paramControllers['stochRsiDPeriod']?.text   = _params.stochRsiDPeriod.toString();
    _paramControllers['volumeMAperiod']?.text    = _params.volumeMAperiod.toString();
  }

  void _saveBacktestParams() {
    try {
      final bloc = context.read<StockBloc>();
      bloc.stockStorage.saveBacktestParams({
        'strategy': _selectedStrategy.name,
        'initialCapital': double.tryParse(_initialCapitalController.text) ?? 100000,
        'feeRate': double.tryParse(_feeRateController.text) ?? 0.001,
        'positionRatio': double.tryParse(_positionRatioController.text) ?? 1.0,
        'startDate': _startDate.toIso8601String(),
        'endDate': _endDate.toIso8601String(),
        'params': _params.toJson(),
        // S-4: 止损止盈参数
        'stopLossPercent': _stopLossPercent,
        'takeProfitPercent': _takeProfitPercent,
        'enableTimeExit': _enableTimeExit,
        'maxHoldingDays': _maxHoldingDays,
        'slippagePercent': _slippagePercent,
      });
    } catch (_) {}
  }

  // ─── U-2: 导出CSV ───
  Future<void> _exportCsv(BacktestResult r) async {
    try {
      final sb = StringBuffer();
      sb.writeln('入场日期,入场价格,出场日期,出场价格,方向,持仓天数,盈亏,盈亏%,费率,出场原因');
      for (final t in r.trades) {
        sb.writeln([
          t.entryDate,
          t.entryPrice.toStringAsFixed(3),
          t.exitDate,
          t.exitPrice.toStringAsFixed(3),
          t.isLong ? '多' : '空',
          t.holdingDays,
          t.profit.toStringAsFixed(2),
          t.profitPercent.toStringAsFixed(2),
          t.fee.toStringAsFixed(2),
          t.exitReason ?? '',
        ].join(','));
      }
      // 用 share_plus 分享文本
      await Share.share(
        sb.toString(),
        subject: '回测结果_${_selectedStrategy.name}_${_dateFormat.format(_startDate)}_${_dateFormat.format(_endDate)}.csv',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV已生成，点击分享给其他应用')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
      }
    }
  }

  // ─── U-3: 导出PDF报告 ───
  Future<void> _exportPdf(BacktestResult r) async {
    try {
      final pdf = pw.Document();
      final dateStr = '${_dateFormat.format(_startDate)} ~ ${_dateFormat.format(_endDate)}';
      final returnPct = (r.totalProfit / r.initialCapital * 100).toStringAsFixed(2);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('回测报告', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('策略: ${_selectedStrategy.name}  |  回测区间: $dateStr',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              pw.Divider(),
              pw.SizedBox(height: 8),
            ],
          ),
          build: (ctx) => [
            // 收益概览
            pw.Text('收益概览', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            _pdfTable([
              ['初始资金', '最终资金', '总收益', '收益率', '胜率'],
              [r.initialCapital.toStringAsFixed(2), r.finalCapital.toStringAsFixed(2),
               '${r.totalProfit >= 0 ? '+' : ''}${r.totalProfit.toStringAsFixed(2)}',
               '$returnPct%', '${r.winRate.toStringAsFixed(1)}%'],
            ]),
            pw.SizedBox(height: 16),

            // 关键指标
            pw.Text('关键指标', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            _pdfTable([
              ['夏普比率', 'Kelly仓位', '盈亏比', '最大回撤', '交易次数'],
              [r.sharpeRatio.toStringAsFixed(2), r.kellyFraction,
               r.profitFactor > 0 ? r.profitFactor.toStringAsFixed(2) : 'N/A',
               '${r.maxDrawdownPercent.toStringAsFixed(2)}%', '${r.totalTrades}'],
            ]),
            pw.SizedBox(height: 16),

            // 交易明细
            if (r.trades.isNotEmpty) ...[
              pw.Text('交易明细', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              _pdfTradeTable(r.trades),
            ],
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: '回测报告_${_selectedStrategy.name}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF导出失败: $e')));
      }
    }
  }

  pw.Widget _pdfTable(List<List<String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: rows.asMap().entries.map((entry) {
        final isHeader = entry.key == 0;
        return pw.TableRow(
          decoration: isHeader ? const pw.BoxDecoration(color: PdfColors.grey200) : null,
          children: entry.value.map((cell) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(cell, style: pw.TextStyle(
                fontSize: isHeader ? 9 : 9,
                fontWeight: isHeader ? pw.FontWeight.bold : null,
              )),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  pw.Widget _pdfTradeTable(List<Trade> trades) {
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1),
        5: const pw.FlexColumnWidth(1.5),
        6: const pw.FlexColumnWidth(1.5),
        7: const pw.FlexColumnWidth(2),
      },
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: ['入场日期','入场价','出场日期','出场价','方向','持仓','盈亏','出场原因']
              .map((h) => pw.Padding(padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))))
              .toList(),
        ),
        ...trades.take(50).map((t) => pw.TableRow(children: [
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(t.entryDate, style: const pw.TextStyle(fontSize: 8))),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(t.entryPrice.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 8))),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(t.exitDate, style: const pw.TextStyle(fontSize: 8))),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(t.exitPrice.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 8))),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(t.isLong ? '多' : '空', style: const pw.TextStyle(fontSize: 8))),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${t.holdingDays}天', style: const pw.TextStyle(fontSize: 8))),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${t.profit >= 0 ? '+' : ''}${t.profit.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8, color: t.profit >= 0 ? PdfColors.green : PdfColors.red))),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(t.exitReason ?? '', style: const pw.TextStyle(fontSize: 8))),
        ])),
      ],
    );
  }

  void _initParamControllers() {
    _paramControllers['macdFastPeriod']   = TextEditingController(text: _params.macdFastPeriod.toString());
    _paramControllers['macdSlowPeriod']   = TextEditingController(text: _params.macdSlowPeriod.toString());
    _paramControllers['macdSignalPeriod']  = TextEditingController(text: _params.macdSignalPeriod.toString());
    _paramControllers['kdjPeriod']        = TextEditingController(text: _params.kdjPeriod.toString());
    _paramControllers['kdjKPeriod']        = TextEditingController(text: _params.kdjKPeriod.toString());
    _paramControllers['kdjDPeriod']        = TextEditingController(text: _params.kdjDPeriod.toString());
    _paramControllers['kdjOverbought']    = TextEditingController(text: _params.kdjOverbought.toString());
    _paramControllers['kdjOversold']      = TextEditingController(text: _params.kdjOversold.toString());
    _paramControllers['rsiPeriod']         = TextEditingController(text: _params.rsiPeriod.toString());
    _paramControllers['rsiOverbought']     = TextEditingController(text: _params.rsiOverbought.toString());
    _paramControllers['rsiOversold']      = TextEditingController(text: _params.rsiOversold.toString());
    _paramControllers['bollPeriod']         = TextEditingController(text: _params.bollPeriod.toString());
    _paramControllers['bollStdDev']        = TextEditingController(text: _params.bollStdDev.toString());
    _paramControllers['maShortPeriod']     = TextEditingController(text: _params.maShortPeriod.toString());
    _paramControllers['maMidPeriod']       = TextEditingController(text: _params.maMidPeriod.toString());
    _paramControllers['maLongPeriod']      = TextEditingController(text: _params.maLongPeriod.toString());
    _paramControllers['wrPeriod']          = TextEditingController(text: _params.wrPeriod.toString());
    _paramControllers['wrOverbought']      = TextEditingController(text: _params.wrOverbought.toString());
    _paramControllers['wrOversold']        = TextEditingController(text: _params.wrOversold.toString());
    _paramControllers['dmiPeriod']          = TextEditingController(text: _params.dmiPeriod.toString());
    _paramControllers['dmiAdxPeriod']      = TextEditingController(text: _params.dmiAdxPeriod.toString());
    _paramControllers['dmiTrendThreshold'] = TextEditingController(text: _params.dmiTrendThreshold.toString());
    _paramControllers['cciPeriod']          = TextEditingController(text: _params.cciPeriod.toString());
    _paramControllers['stochRsiPeriod']    = TextEditingController(text: _params.stochRsiPeriod.toString());
    _paramControllers['stochRsiKPeriod']   = TextEditingController(text: _params.stochRsiKPeriod.toString());
    _paramControllers['stochRsiDPeriod']   = TextEditingController(text: _params.stochRsiDPeriod.toString());
    _paramControllers['volumeMAperiod']      = TextEditingController(text: _params.volumeMAperiod.toString());
  }

  void _buildDefaultPresets() {
    // 根据策略生成默认预置组合
    _presetCombos = _buildPresetsForStrategy(_selectedStrategy);
  }

  List<StrategyParams> _buildPresetsForStrategy(BacktestStrategy strategy) {
    switch (strategy) {
      case BacktestStrategy.macd:
        return [
          const StrategyParams(macdFastPeriod: 12, macdSlowPeriod: 26, macdSignalPeriod: 9),
          const StrategyParams(macdFastPeriod: 6,  macdSlowPeriod: 13, macdSignalPeriod: 5),
          const StrategyParams(macdFastPeriod: 19, macdSlowPeriod: 39, macdSignalPeriod: 9),
          const StrategyParams(macdFastPeriod: 8,  macdSlowPeriod: 17, macdSignalPeriod: 7),
        ];
      case BacktestStrategy.kdj:
        return [
          const StrategyParams(kdjPeriod: 9,  kdjOverbought: 80, kdjOversold: 20),
          const StrategyParams(kdjPeriod: 14, kdjOverbought: 80, kdjOversold: 20),
          const StrategyParams(kdjPeriod: 9,  kdjOverbought: 70, kdjOversold: 30),
          const StrategyParams(kdjPeriod: 18, kdjOverbought: 85, kdjOversold: 15),
        ];
      case BacktestStrategy.rsi:
        return [
          const StrategyParams(rsiPeriod: 14, rsiOverbought: 70, rsiOversold: 30),
          const StrategyParams(rsiPeriod: 6,  rsiOverbought: 65, rsiOversold: 35),
          const StrategyParams(rsiPeriod: 21, rsiOverbought: 75, rsiOversold: 25),
          const StrategyParams(rsiPeriod: 9,  rsiOverbought: 70, rsiOversold: 30),
        ];
      case BacktestStrategy.boll:
        return [
          const StrategyParams(bollPeriod: 20, bollStdDev: 2),
          const StrategyParams(bollPeriod: 20, bollStdDev: 3),
          const StrategyParams(bollPeriod: 14, bollStdDev: 2),
          const StrategyParams(bollPeriod: 30, bollStdDev: 2),
        ];
      case BacktestStrategy.ma:
        return [
          const StrategyParams(maShortPeriod: 5,  maMidPeriod: 10, maLongPeriod: 20),
          const StrategyParams(maShortPeriod: 5,  maMidPeriod: 20, maLongPeriod: 60),
          const StrategyParams(maShortPeriod: 10, maMidPeriod: 20, maLongPeriod: 60),
          const StrategyParams(maShortPeriod: 5,  maMidPeriod: 30, maLongPeriod: 120),
          const StrategyParams(maShortPeriod: 5,  maMidPeriod: 10, maLongPeriod: 20, volumeFilter: true, volumeMAperiod: 5),
          const StrategyParams(maShortPeriod: 5,  maMidPeriod: 20, maLongPeriod: 60, volumeFilter: true, volumeMAperiod: 5),
        ];
      case BacktestStrategy.wr:
        return [
          const StrategyParams(wrPeriod: 10, wrOverbought: 20, wrOversold: 80),
          const StrategyParams(wrPeriod: 6,  wrOverbought: 25, wrOversold: 75),
          const StrategyParams(wrPeriod: 20, wrOverbought: 20, wrOversold: 80),
          const StrategyParams(wrPeriod: 14, wrOverbought: 15, wrOversold: 85),
        ];
      case BacktestStrategy.dmi:
        return [
          const StrategyParams(dmiPeriod: 14, dmiAdxPeriod: 14, dmiTrendThreshold: 25),
          const StrategyParams(dmiPeriod: 14, dmiAdxPeriod: 14, dmiTrendThreshold: 20),
          const StrategyParams(dmiPeriod: 14, dmiAdxPeriod: 14, dmiTrendThreshold: 30),
          const StrategyParams(dmiPeriod: 20, dmiAdxPeriod: 20, dmiTrendThreshold: 25),
        ];
      case BacktestStrategy.multi:
        return [
          StrategyParams(
            macdFastPeriod: 12, macdSlowPeriod: 26, macdSignalPeriod: 9,
            rsiPeriod: 14, rsiOverbought: 70, rsiOversold: 30,
            kdjPeriod: 9, kdjOverbought: 80, kdjOversold: 20,
          ),
          StrategyParams(
            macdFastPeriod: 6, macdSlowPeriod: 13, macdSignalPeriod: 5,
            rsiPeriod: 6, rsiOverbought: 65, rsiOversold: 35,
            kdjPeriod: 14, kdjOverbought: 70, kdjOversold: 30,
          ),
        ];
      case BacktestStrategy.cci:
        return [
          const StrategyParams(cciPeriod: 14),
          const StrategyParams(cciPeriod: 20),
          const StrategyParams(cciPeriod: 8),
        ];
      case BacktestStrategy.stochRsi:
        return [
          const StrategyParams(stochRsiPeriod: 14, stochRsiKPeriod: 3, stochRsiDPeriod: 3),
          const StrategyParams(stochRsiPeriod: 20, stochRsiKPeriod: 5, stochRsiDPeriod: 3),
          const StrategyParams(stochRsiPeriod: 10, stochRsiKPeriod: 3, stochRsiDPeriod: 5),
        ];
    }
  }

  @override
  void dispose() {
    _initialCapitalController.dispose();
    _feeRateController.dispose();
    _positionRatioController.dispose();
    // S-4: 释放出场参数控制器
    _stopLossController.dispose();
    _takeProfitController.dispose();
    _maxHoldingDaysController.dispose();
    _slippageController.dispose();
    // B-4 Fix: 释放所有策略参数 TextEditingController
    for (final controller in _paramControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('回测'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => context.go('/backtest/help'),
            tooltip: '策略帮助',
          ),
        ],
      ),
      body: BlocBuilder<StockBloc, StockState>(
        builder: (context, state) {
          if (state is! StockLoaded) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.show_chart, size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  const Text('请先在图表页面加载股票数据',
                      style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/'),
                    child: const Text('返回图表'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStockInfoCard(state),
                const SizedBox(height: 12),
                _buildStrategyCard(),
                const SizedBox(height: 12),
                _buildParamsCard(),
                const SizedBox(height: 12),
                _buildActionRow(state),
                const SizedBox(height: 12),
                if (_showBatchPanel) _buildBatchResultsPanel(),
                if (_result != null && !_showBatchPanel) _buildResultCard(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStockInfoCard(StockLoaded state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.stockData.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(state.stockData.symbol,
                          style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Text('${state.stockData.quotes.length}个数据点'),
              ],
            ),
            const SizedBox(height: 12),
            // ─── 日期快捷按钮（U-10）───
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildDatePresetChip('近1月', 30),
                  const SizedBox(width: 4),
                  _buildDatePresetChip('近3月', 90),
                  const SizedBox(width: 4),
                  _buildDatePresetChip('近6月', 180),
                  const SizedBox(width: 4),
                  _buildDatePresetChip('近1年', 365),
                  const SizedBox(width: 4),
                  _buildDatePresetChip('近3年', 365 * 3),
                  const SizedBox(width: 8),
                  // 手动选择
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(_dateFormat.format(_startDate)),
                    onPressed: () => _selectDate(true),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('至', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(_dateFormat.format(_endDate)),
                    onPressed: () => _selectDate(false),
                  ),
                  const SizedBox(width: 8),
                  if (_isLoadingData)
                    const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: () => _ensureDataForRange(state),
                      tooltip: '补全该时间段数据',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrategyCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('策略选择', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  icon: Icon(_showBatchPanel ? Icons.table_rows : Icons.compare_arrows, size: 18),
                  label: Text(_showBatchPanel ? '单次回测' : '多参数比较'),
                  onPressed: () => setState(() {
                    _showBatchPanel = !_showBatchPanel;
                    if (_showBatchPanel) _batchResults = [];
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<BacktestStrategy>(
              value: _selectedStrategy,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: BacktestStrategy.values.map((s) {
                return DropdownMenuItem(value: s, child: Text(_getStrategyName(s)));
              }).toList(),
              onChanged: (v) {
                setState(() {
                  _selectedStrategy = v!;
                  _showBatchPanel = false;
                  _result = null;
                  _buildDefaultPresets();
                  _params = const StrategyParams();
                  _showAdvancedParams = false;
                });
                _syncControllersFromParams();
              },
            ),
            const SizedBox(height: 6),
            Text(
              _getStrategyDescription(_selectedStrategy),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParamsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 基本参数
            Row(
              children: [
                const Text('参数设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  icon: Icon(_showAdvancedParams ? Icons.expand_less : Icons.tune, size: 18),
                  label: Text(_showAdvancedParams ? '收起' : '策略参数'),
                  onPressed: () => setState(() => _showAdvancedParams = !_showAdvancedParams),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _initialCapitalController,
                    decoration: const InputDecoration(
                      labelText: '初始资金',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _feeRateController,
                    decoration: const InputDecoration(
                      labelText: '费率',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _positionRatioController,
                    decoration: const InputDecoration(
                      labelText: '仓位(0-1)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            // 策略参数（展开时显示）
            if (_showAdvancedParams) ...[
              const Divider(height: 24),
              _buildStrategyParamsSection(),
              const Divider(height: 24),
              _buildExitParamsSection(),
            ],
          ],
        ),
      ),
    );
  }

  // ─── B-4 Fix: 参数更新回调 ───
  void _onMacdFastPeriodChanged(int v) { setState(() { _params = _params.copyWith(macdFastPeriod: v); }); _paramControllers['macdFastPeriod']?.text = v.toString(); }
  void _onMacdSlowPeriodChanged(int v) { setState(() { _params = _params.copyWith(macdSlowPeriod: v); }); _paramControllers['macdSlowPeriod']?.text = v.toString(); }
  void _onMacdSignalPeriodChanged(int v) { setState(() { _params = _params.copyWith(macdSignalPeriod: v); }); _paramControllers['macdSignalPeriod']?.text = v.toString(); }
  void _onKdjPeriodChanged(int v) { setState(() { _params = _params.copyWith(kdjPeriod: v); }); _paramControllers['kdjPeriod']?.text = v.toString(); }
  void _onKdjOverboughtChanged(int v) { setState(() { _params = _params.copyWith(kdjOverbought: v); }); _paramControllers['kdjOverbought']?.text = v.toString(); }
  void _onKdjOversoldChanged(int v) { setState(() { _params = _params.copyWith(kdjOversold: v); }); _paramControllers['kdjOversold']?.text = v.toString(); }
  void _onRsiPeriodChanged(int v) { setState(() { _params = _params.copyWith(rsiPeriod: v); }); _paramControllers['rsiPeriod']?.text = v.toString(); }
  void _onRsiOverboughtChanged(int v) { setState(() { _params = _params.copyWith(rsiOverbought: v); }); _paramControllers['rsiOverbought']?.text = v.toString(); }
  void _onRsiOversoldChanged(int v) { setState(() { _params = _params.copyWith(rsiOversold: v); }); _paramControllers['rsiOversold']?.text = v.toString(); }
  void _onBollPeriodChanged(int v) { setState(() { _params = _params.copyWith(bollPeriod: v); }); _paramControllers['bollPeriod']?.text = v.toString(); }
  void _onBollStdDevChanged(int v) { setState(() { _params = _params.copyWith(bollStdDev: v); }); _paramControllers['bollStdDev']?.text = v.toString(); }
  void _onMaShortPeriodChanged(int v) { setState(() { _params = _params.copyWith(maShortPeriod: v); }); _paramControllers['maShortPeriod']?.text = v.toString(); }
  void _onMaMidPeriodChanged(int v) { setState(() { _params = _params.copyWith(maMidPeriod: v); }); _paramControllers['maMidPeriod']?.text = v.toString(); }
  void _onMaLongPeriodChanged(int v) { setState(() { _params = _params.copyWith(maLongPeriod: v); }); _paramControllers['maLongPeriod']?.text = v.toString(); }
  void _onWrPeriodChanged(int v) { setState(() { _params = _params.copyWith(wrPeriod: v); }); _paramControllers['wrPeriod']?.text = v.toString(); }
  void _onWrOverboughtChanged(int v) { setState(() { _params = _params.copyWith(wrOverbought: v); }); _paramControllers['wrOverbought']?.text = v.toString(); }
  void _onWrOversoldChanged(int v) { setState(() { _params = _params.copyWith(wrOversold: v); }); _paramControllers['wrOversold']?.text = v.toString(); }
  void _onDmiPeriodChanged(int v) { setState(() { _params = _params.copyWith(dmiPeriod: v); }); _paramControllers['dmiPeriod']?.text = v.toString(); }
  void _onDmiAdxPeriodChanged(int v) { setState(() { _params = _params.copyWith(dmiAdxPeriod: v); }); _paramControllers['dmiAdxPeriod']?.text = v.toString(); }
  void _onDmiTrendThresholdChanged(int v) { setState(() { _params = _params.copyWith(dmiTrendThreshold: v); }); _paramControllers['dmiTrendThreshold']?.text = v.toString(); }
  void _onCciPeriodChanged(int v) { setState(() { _params = _params.copyWith(cciPeriod: v); }); _paramControllers['cciPeriod']?.text = v.toString(); }
  void _onStochRsiPeriodChanged(int v) { setState(() { _params = _params.copyWith(stochRsiPeriod: v); }); _paramControllers['stochRsiPeriod']?.text = v.toString(); }
  void _onStochRsiKPeriodChanged(int v) { setState(() { _params = _params.copyWith(stochRsiKPeriod: v); }); _paramControllers['stochRsiKPeriod']?.text = v.toString(); }
  void _onStochRsiDPeriodChanged(int v) { setState(() { _params = _params.copyWith(stochRsiDPeriod: v); }); _paramControllers['stochRsiDPeriod']?.text = v.toString(); }
  void _onVolumeMAPeriodChanged(int v) { setState(() { _params = _params.copyWith(volumeMAperiod: v); }); _paramControllers['volumeMAperiod']?.text = v.toString(); }

  Widget _buildIntParamField(String label, String key, int value, ValueChanged<int> onChanged) {
    // B-4 Fix: 使用预创建的 controller，而非每次 build() 时 new
    final controller = _paramControllers[key] ??= TextEditingController(text: value.toString());
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      onSubmitted: (t) {
        final parsed = int.tryParse(t);
        if (parsed != null && parsed > 0) onChanged(parsed);
      },
    );
  }

  // ─── S-4: 出场参数区域 ───
  Widget _buildExitParamsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('出场参数', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (_exitTemplates.isNotEmpty)
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String?>(
                  value: _selectedTemplateName,
                  decoration: const InputDecoration(
                    labelText: '模板',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('不使用模板')),
                    ..._exitTemplates.map((t) => DropdownMenuItem(value: t.name, child: Text(t.name))),
                  ],
                  onChanged: (v) => _applyTemplate(v),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // 第一行：止损% + 止盈%
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: '止损%',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                controller: _stopLossController,
                onChanged: (t) => setState(() {
                  _stopLossPercent = double.tryParse(t);
                  _selectedTemplateName = null;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: '止盈%',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                controller: _takeProfitController,
                onChanged: (t) => setState(() {
                  _takeProfitPercent = double.tryParse(t);
                  _selectedTemplateName = null;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 第二行：时间止损开关 + 最大持仓天数 + 滑点‰
        Row(
          children: [
            const Text('时间止损'),
            Switch(
              value: _enableTimeExit,
              onChanged: (v) => setState(() {
                _enableTimeExit = v;
                _selectedTemplateName = null;
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: '最大持仓(天)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                controller: _maxHoldingDaysController,
                onChanged: (t) => setState(() {
                  _maxHoldingDays = int.tryParse(t) ?? 20;
                  _selectedTemplateName = null;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: '滑点‰',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                controller: _slippageController,
                onChanged: (t) => setState(() {
                  _slippagePercent = double.tryParse(t);
                  _selectedTemplateName = null;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 保存/删除模板按钮
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.save, size: 16),
              label: const Text('保存模板'),
              onPressed: () => _showSaveTemplateDialog(),
            ),
            if (_selectedTemplateName != null) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete, size: 16),
                label: const Text('删除模板'),
                onPressed: () => _deleteCurrentTemplate(),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _applyTemplate(String? v) {
    setState(() {
      _selectedTemplateName = v;
      if (v != null) {
        final t = _exitTemplates.firstWhere((e) => e.name == v);
        _stopLossPercent = t.stopLossPercent;
        _takeProfitPercent = t.takeProfitPercent;
        _enableTimeExit = t.enableTimeExit;
        _maxHoldingDays = t.maxHoldingDays;
        _slippagePercent = t.slippagePercent;
        _syncExitControllersFromState();
      }
    });
  }

  void _syncExitControllersFromState() {
    _stopLossController.text = _stopLossPercent?.toString() ?? '';
    _takeProfitController.text = _takeProfitPercent?.toString() ?? '';
    _maxHoldingDaysController.text = _maxHoldingDays.toString();
    _slippageController.text = _slippagePercent?.toString() ?? '';
  }

  void _showSaveTemplateDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('保存出场模板'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '模板名称',
            hintText: '如：保守型',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final template = ExitTemplate(
                name: name,
                stopLossPercent: _stopLossPercent,
                takeProfitPercent: _takeProfitPercent,
                enableTimeExit: _enableTimeExit,
                maxHoldingDays: _maxHoldingDays,
                slippagePercent: _slippagePercent,
              );
              await context.read<StockBloc>().stockStorage.saveExitTemplate(template);
              final templates = context.read<StockBloc>().stockStorage.getExitTemplates();
              if (mounted) {
                setState(() {
                  _exitTemplates = templates;
                  _selectedTemplateName = name;
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('模板"$name"已保存')));
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _deleteCurrentTemplate() async {
    final name = _selectedTemplateName;
    if (name == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除模板'),
        content: Text('确定删除模板"$name"吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<StockBloc>().stockStorage.deleteExitTemplate(name);
      final templates = context.read<StockBloc>().stockStorage.getExitTemplates();
      setState(() {
        _exitTemplates = templates;
        _selectedTemplateName = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('模板"$name"已删除')));
      }
    }
  }

  // ─── S-4 加载模板列表（在initState和设置页返回时调用）───
  void _loadExitTemplates() {
    try {
      final templates = context.read<StockBloc>().stockStorage.getExitTemplates();
      setState(() => _exitTemplates = templates);
    } catch (_) {}
  }

  Widget _buildStrategyParamsSection() {
    switch (_selectedStrategy) {
      case BacktestStrategy.macd:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('MACD 参数', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildIntParamField('快线周期', 'macdFastPeriod', _params.macdFastPeriod, _onMacdFastPeriodChanged)),
                const SizedBox(width: 8),
                Expanded(child: _buildIntParamField('慢线周期', 'macdSlowPeriod', _params.macdSlowPeriod, _onMacdSlowPeriodChanged)),
                const SizedBox(width: 8),
                Expanded(child: _buildIntParamField('信号周期', 'macdSignalPeriod', _params.macdSignalPeriod, _onMacdSignalPeriodChanged)),
              ],
            ),
          ],
        );
      case BacktestStrategy.kdj:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('KDJ 参数', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildIntParamField('周期', 'kdjPeriod', _params.kdjPeriod, _onKdjPeriodChanged)),
                const SizedBox(width: 8),
                Expanded(child: _buildIntParamField('超买区', 'kdjOverbought', _params.kdjOverbought, _onKdjOverboughtChanged)),
                const SizedBox(width: 8),
                Expanded(child: _buildIntParamField('超卖区', 'kdjOversold', _params.kdjOversold, _onKdjOversoldChanged)),
              ],
            ),
          ],
        );
      case BacktestStrategy.rsi:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('RSI 参数', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildIntParamField('周期', 'rsiPeriod', _params.rsiPeriod, _onRsiPeriodChanged)),
                const SizedBox(width: 8),
                Expanded(child: _buildIntParamField('超买阈值', 'rsiOverbought', _params.rsiOverbought, _onRsiOverboughtChanged)),
                const SizedBox(width: 8),
                Expanded(child: _buildIntParamField('超卖阈值', 'rsiOversold', _params.rsiOversold, _onRsiOversoldChanged)),
              ],
            ),
          ],
        );
      case BacktestStrategy.boll:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('BOLL 参数', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildIntParamField('周期', 'bollPeriod', _params.bollPeriod, _onBollPeriodChanged)),
                const SizedBox(width: 8),
                Expanded(child: _buildIntParamField('标准差倍数', 'bollStdDev', _params.bollStdDev, _onBollStdDevChanged)),
              ],
            ),
          ],
        );
      case BacktestStrategy.ma:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('MA 均线参数', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildIntParamField('短期', 'maShortPeriod', _params.maShortPeriod, _onMaShortPeriodChanged)),
                const SizedBox(width: 8),
                Expanded(child: _buildIntParamField('中期', 'maMidPeriod', _params.maMidPeriod, _onMaMidPeriodChanged)),
                const SizedBox(width: 8),
                Expanded(child: _buildIntParamField('长期', 'maLongPeriod', _params.maLongPeriod, _onMaLongPeriodChanged)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildIntParamField('均量周期', 'volumeMAperiod', _params.volumeMAperiod, _onVolumeMAPeriodChanged)),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      const Text('放量过滤'),
                      Switch(
                        value: _params.volumeFilter,
                        onChanged: (v) => setState(() { _params = _params.copyWith(volumeFilter: v); }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      case BacktestStrategy.wr:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('WR 威廉参数', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildIntParamField('周期', 'wrPeriod', _params.wrPeriod, _onWrPeriodChanged)),
                const SizedBox(width: 8),
                Expanded(child: _buildIntParamField('超买阈值', 'wrOverbought', _params.wrOverbought, _onWrOverboughtChanged)),
                const SizedBox(width: 8),
                Expanded(child: _buildIntParamField('超卖阈值', 'wrOversold', _params.wrOversold, _onWrOversoldChanged)),
              ],
            ),
          ],
        );
      case BacktestStrategy.dmi:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('DMI 参数', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildIntParamField('DI周期', 'dmiPeriod', _params.dmiPeriod, _onDmiPeriodChanged)),
                const SizedBox(width: 8),
                Expanded(child: _buildIntParamField('ADX周期', 'dmiAdxPeriod', _params.dmiAdxPeriod, _onDmiAdxPeriodChanged)),
                const SizedBox(width: 8),
                Expanded(child: _buildIntParamField('趋势阈值', 'dmiTrendThreshold', _params.dmiTrendThreshold, _onDmiTrendThresholdChanged)),
              ],
            ),
          ],
        );
      case BacktestStrategy.multi:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('综合指标参数（多策略共振）', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildIntParamField('MACD快', 'macdFastPeriod', _params.macdFastPeriod, _onMacdFastPeriodChanged)),
                const SizedBox(width: 4),
                Expanded(child: _buildIntParamField('MACD慢', 'macdSlowPeriod', _params.macdSlowPeriod, _onMacdSlowPeriodChanged)),
                const SizedBox(width: 4),
                Expanded(child: _buildIntParamField('MACD信', 'macdSignalPeriod', _params.macdSignalPeriod, _onMacdSignalPeriodChanged)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: _buildIntParamField('RSI周期', 'rsiPeriod', _params.rsiPeriod, _onRsiPeriodChanged)),
                const SizedBox(width: 4),
                Expanded(child: _buildIntParamField('RSI超买', 'rsiOverbought', _params.rsiOverbought, _onRsiOverboughtChanged)),
                const SizedBox(width: 4),
                Expanded(child: _buildIntParamField('RSI超卖', 'rsiOversold', _params.rsiOversold, _onRsiOversoldChanged)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: _buildIntParamField('KDJ周期', 'kdjPeriod', _params.kdjPeriod, _onKdjPeriodChanged)),
                const SizedBox(width: 4),
                Expanded(child: _buildIntParamField('KDJ超买', 'kdjOverbought', _params.kdjOverbought, _onKdjOverboughtChanged)),
                const SizedBox(width: 4),
                Expanded(child: _buildIntParamField('KDJ超卖', 'kdjOversold', _params.kdjOversold, _onKdjOversoldChanged)),
              ],
            ),
          ],
        );
      case BacktestStrategy.cci:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CCI 顺势指标参数', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildIntParamField('CCI周期', 'cciPeriod', _params.cciPeriod, _onCciPeriodChanged)),
              ],
            ),
          ],
        );
      case BacktestStrategy.stochRsi:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('StochRSI 参数（RSI的RSI）', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildIntParamField('StochRSI周期', 'stochRsiPeriod', _params.stochRsiPeriod, _onStochRsiPeriodChanged)),
                const SizedBox(width: 4),
                Expanded(child: _buildIntParamField('K周期', 'stochRsiKPeriod', _params.stochRsiKPeriod, _onStochRsiKPeriodChanged)),
                const SizedBox(width: 4),
                Expanded(child: _buildIntParamField('D周期', 'stochRsiDPeriod', _params.stochRsiDPeriod, _onStochRsiDPeriodChanged)),
              ],
            ),
          ],
        );
    }
  }



  // （已整合到 _syncControllersFromParams）

  Widget _buildActionRow(StockLoaded state) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isRunning ? null : () => _runBacktest(state),
              icon: _isRunning
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_arrow),
              label: Text(_showBatchPanel
                  ? '运行多参数比较（${_presetCombos.length}组）'
                  : '运行回测'),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: () => _showParamInfoSheet(context),
            child: const Icon(Icons.info_outline),
          ),
        ),
      ],
    );
  }

  Widget _buildBatchResultsPanel() {
    if (_batchResults.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.compare_arrows, size: 48, color: AppColors.textSecondary.withAlpha(128)),
                const SizedBox(height: 12),
                const Text('点击上方按钮运行多参数比较',
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text('将使用 ${_presetCombos.length} 组参数依次回测',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      );
    }

    // ─── U-6: 动态排序 ───
    final sorted = _getSortedBatchResults();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.leaderboard, size: 20),
                const SizedBox(width: 8),
                const Text('多参数比较结果', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${sorted.length}组参数',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            const Divider(),
            // 表头（U-6: 可点击排序）
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const SizedBox(width: 32, child: Text('#', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                  Expanded(flex: 3, child: const Text('参数', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                  _buildSortHeader('收益率', '收益率', width: 60),
                  _buildSortHeader('胜率', '胜率', width: 50),
                  _buildSortHeader('夏普', '夏普', width: 50),
                  _buildSortHeader('最大回撤', '最大回撤', width: 60),
                  _buildSortHeader('交易数', '交易数', width: 50),
                ],
              ),
            ),
            const Divider(),
            // 排序后的行
            ...sorted.asMap().entries.map((entry) {
              final idx = entry.key;
              final r = entry.value;
              final isTop = idx == 0;
              final isProfit = r.result.totalProfit >= 0;
              return InkWell(
                onTap: () => setState(() {
                  _result = r.result;
                  _showBatchPanel = false;
                  _params = r.params;
                  _showAdvancedParams = false;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isTop ? AppColors.success.withAlpha(13) : null,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: isTop
                            ? const Icon(Icons.emoji_events, color: Colors.amber, size: 16)
                            : Text('${idx + 1}', style: const TextStyle(fontSize: 12)),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          _formatParamsBrief(r.params),
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${isProfit ? '+' : ''}${(r.result.totalProfit / r.result.initialCapital * 100).toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 12, fontWeight: isTop ? FontWeight.bold : null,
                              color: isProfit ? AppColors.success : AppColors.error),
                        ),
                      ),
                      Expanded(
                        child: Text('${r.result.winRate.toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 12)),
                      ),
                      Expanded(
                        child: Text(r.result.sharpeRatio.toStringAsFixed(2),
                            style: const TextStyle(fontSize: 12)),
                      ),
                      Expanded(
                        child: Text('${r.result.maxDrawdownPercent.toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 12, color: AppColors.error)),
                      ),
                      Expanded(
                        child: Text('${r.result.totalTrades}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            Text(
              '💡 点击任意行查看该参数详细回测结果',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withAlpha(179)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatParamsBrief(StrategyParams p) {
    switch (_selectedStrategy) {
      case BacktestStrategy.macd:
        return 'MACD(${p.macdFastPeriod},${p.macdSlowPeriod},${p.macdSignalPeriod})';
      case BacktestStrategy.kdj:
        return 'KDJ(${p.kdjPeriod}) ${p.kdjOversold}/${p.kdjOverbought}';
      case BacktestStrategy.rsi:
        return 'RSI(${p.rsiPeriod}) ${p.rsiOversold}/${p.rsiOverbought}';
      case BacktestStrategy.boll:
        return 'BOLL(${p.bollPeriod}) ±${p.bollStdDev}σ';
      case BacktestStrategy.ma:
        return 'MA(${p.maShortPeriod},${p.maMidPeriod},${p.maLongPeriod})';
      case BacktestStrategy.wr:
        return 'WR(${p.wrPeriod}) ${p.wrOversold}/${p.wrOverbought}';
      case BacktestStrategy.dmi:
        return 'DMI(${p.dmiPeriod}) ADX>${p.dmiTrendThreshold}';
      case BacktestStrategy.multi:
        return 'MACD(${p.macdFastPeriod},${p.macdSlowPeriod}) RSI(${p.rsiPeriod}) KDJ(${p.kdjPeriod})';
      case BacktestStrategy.cci:
        return 'CCI(${p.cciPeriod})';
      case BacktestStrategy.stochRsi:
        return 'StochRSI(${p.stochRsiPeriod},K${p.stochRsiKPeriod},D${p.stochRsiDPeriod})';
    }
  }

  Widget _buildResultCard() {
    final r = _result!;
    final isProfit = r.totalProfit >= 0;
    final isHighDrawdown = r.maxDrawdownPercent > 20;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── U-9: 回撤警告横幅 ───
            if (isHighDrawdown)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(26),
                  border: Border.all(color: AppColors.error.withAlpha(77)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⚠️ 最大回撤 ${r.maxDrawdownPercent.toStringAsFixed(1)}% 超过20%，策略风险较高',
                        style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            // ─── U-2: 导出CSV按钮 ───
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.picture_as_pdf, size: 16),
                  label: const Text('PDF报告'),
                  onPressed: () => _exportPdf(r),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('导出CSV'),
                  onPressed: () => _exportCsv(r),
                ),
              ],
            ),
            // 汇总
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isProfit ? AppColors.success.withAlpha(26) : AppColors.error.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetric('总收益', '${r.totalProfit >= 0 ? '+' : ''}${r.totalProfit.toStringAsFixed(2)}', isProfit ? AppColors.success : AppColors.error),
                  _buildMetric('收益率', '${r.totalProfit >= 0 ? '+' : ''}${(r.totalProfit / r.initialCapital * 100).toStringAsFixed(2)}%', isProfit ? AppColors.success : AppColors.error),
                  _buildMetric('胜率', '${r.winRate.toStringAsFixed(1)}%', Colors.blue),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 关键指标
            const Text('关键指标', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            _buildRow('夏普比率', r.sharpeRatio.toStringAsFixed(2)),
            _buildRow('Kelly仓位', r.kellyFraction),
            _buildRow('盈亏比', r.profitFactor > 0 ? r.profitFactor.toStringAsFixed(2) : 'N/A'),
            _buildRow('最大回撤', '${r.maxDrawdownPercent.toStringAsFixed(2)}%'),
            _buildRow('平均盈利', r.avgWin.toStringAsFixed(2)),
            _buildRow('平均亏损', r.avgLoss.toStringAsFixed(2)),
            _buildRow('交易次数', '${r.totalTrades}'),
            _buildRow('盈利次数', '${r.winningTrades}'),
            _buildRow('亏损次数', '${r.losingTrades}'),
            _buildRow('初始资金', r.initialCapital.toStringAsFixed(2)),
            _buildRow('最终资金', r.finalCapital.toStringAsFixed(2)),
            // ─── U-4: 资金曲线 ───
            _buildCapitalCurveChart(r),
            // 交易记录（U-7 筛选器）
            if (r.trades.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('交易记录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  // ─── U-7: 筛选Chip ───
                  _buildFilterChip('全部'),
                  const SizedBox(width: 4),
                  _buildFilterChip('盈利'),
                  const SizedBox(width: 4),
                  _buildFilterChip('亏损'),
                ],
              ),
              const Divider(),
              ..._getFilteredTrades(r.trades).take(10).map((t) => ListTile(
                    dense: true,
                    leading: Icon(t.profit >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        color: t.profit >= 0 ? AppColors.success : AppColors.error),
                    title: Text('${t.isLong ? "多" : "空"} ${t.entryDate} → ${t.exitDate}'),
                    subtitle: Text('入场:${t.entryPrice.toStringAsFixed(2)} 出场:${t.exitPrice.toStringAsFixed(2)}'),
                    trailing: Text('${t.profit >= 0 ? "+" : ""}${t.profit.toStringAsFixed(2)}',
                        style: TextStyle(color: t.profit >= 0 ? AppColors.success : AppColors.error)),
                  )),
              if (_getFilteredTrades(r.trades).length > 10)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('还有 ${_getFilteredTrades(r.trades).length - 10} 条记录...',
                      style: const TextStyle(color: AppColors.textSecondary)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── U-4: 资金曲线图表 ───
  Widget _buildCapitalCurveChart(BacktestResult r) {
    if (r.capitalHistory.length < 2) return const SizedBox.shrink();

    final spots = <FlSpot>[];
    for (var i = 0; i < r.capitalHistory.length; i++) {
      spots.add(FlSpot(i.toDouble(), r.capitalHistory[i]));
    }

    // 取 capitalHistoryDates 的首尾（最多5个标签）
    final dates = r.capitalHistoryDates;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text('资金曲线', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: LineChart(
            LineChartData(
              backgroundColor: AppColors.chartBackground,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(color: AppColors.gridLine, strokeWidth: 0.5),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    getTitlesWidget: (value, meta) {
                      if (value == r.initialCapital) {
                        return Text('本金', style: TextStyle(fontSize: 8, color: AppColors.textSecondary));
                      }
                      return Text(
                        '${(value / 10000).toStringAsFixed(0)}w',
                        style: const TextStyle(fontSize: 8, color: AppColors.axisLabel),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 20,
                    interval: dates.length >= 5 ? (dates.length / 4).roundToDouble() : null,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx >= 0 && idx < dates.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(dates[idx].substring(5), style: const TextStyle(fontSize: 8, color: AppColors.axisLabel)),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  color: AppColors.primary,
                  barWidth: 1.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.primary.withAlpha(15),
                  ),
                ),
              ],
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: r.initialCapital,
                    color: AppColors.gridLineStrong,
                    strokeWidth: 0.8,
                    dashArray: [4, 4],
                  ),
                ],
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final idx = spot.spotIndex;
                      final date = idx < dates.length ? dates[idx] : '';
                      return LineTooltipItem(
                        '$date\n${spot.y.toStringAsFixed(0)}',
                        const TextStyle(color: Colors.white, fontSize: 11),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePresetChip(String label, int days) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      onPressed: () {
        final now = DateTime.now();
        setState(() {
          _endDate = now;
          _startDate = now.subtract(Duration(days: days));
          _result = null;
          _batchResults = [];
        });
      },
    );
  }

  // ─── U-6: 批量比较排序 ───
  Widget _buildSortHeader(String label, String column, {required double width}) {
    final isActive = _sortColumn == column;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () {
          setState(() {
            if (_sortColumn == column) {
              _sortAsc = !_sortAsc;
            } else {
              _sortColumn = column;
              _sortAsc = false;
            }
          });
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isActive ? FontWeight.bold : null,
              ),
            ),
            if (isActive)
              Icon(
                _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                size: 10,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }

  List<_ParamComboResult> _getSortedBatchResults() {
    final list = List<_ParamComboResult>.from(_batchResults);
    list.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case '胜率':
          cmp = a.result.winRate.compareTo(b.result.winRate);
          break;
        case '夏普':
          cmp = a.result.sharpeRatio.compareTo(b.result.sharpeRatio);
          break;
        case '最大回撤':
          cmp = a.result.maxDrawdownPercent.compareTo(b.result.maxDrawdownPercent);
          break;
        case '交易数':
          cmp = a.result.totalTrades.compareTo(b.result.totalTrades);
          break;
        default:
          cmp = (a.result.totalProfit / a.result.initialCapital)
              .compareTo(b.result.totalProfit / b.result.initialCapital);
      }
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  // ─── U-7: 筛选Chip ───
  Widget _buildFilterChip(String label) {
    final isSelected = _tradeFilter == label;
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
      selected: isSelected,
      selectedColor: AppColors.primary,
      checkmarkColor: Colors.white,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => setState(() => _tradeFilter = label),
    );
  }

  List<Trade> _getFilteredTrades(List<Trade> trades) {
    switch (_tradeFilter) {
      case '盈利':
        return trades.where((t) => t.profit >= 0).toList();
      case '亏损':
        return trades.where((t) => t.profit < 0).toList();
      default:
        return trades;
    }
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _runBacktest(StockLoaded state) async {
    final filteredQuotes = _getFilteredQuotes(state);
    if (filteredQuotes.isEmpty) {
      _ensureDataForRange(state);
      return;
    }

    if (_showBatchPanel) {
      await _runBatchBacktest(filteredQuotes);
    } else {
      await _runSingleBacktest(filteredQuotes);
    }
  }

  Future<void> _runSingleBacktest(List<StockQuote> filteredQuotes) async {
    setState(() => _isRunning = true);
    final initialCapital = double.tryParse(_initialCapitalController.text) ?? 100000;
    final feeRate = double.tryParse(_feeRateController.text) ?? 0.001;
    final positionRatio = double.tryParse(_positionRatioController.text) ?? 1.0;

    try {
      final result = await Future(() => BacktestCalculator.runBacktest(
        filteredQuotes,
        strategy: _selectedStrategy,
        initialCapital: initialCapital,
        feeRate: feeRate,
        positionRatio: positionRatio,
        params: _params,
        // S-4: 止损止盈参数
        stopLossPercent: _stopLossPercent,
        takeProfitPercent: _takeProfitPercent,
        enableTimeExit: _enableTimeExit,
        maxHoldingDays: _maxHoldingDays,
        slippagePercent: _slippagePercent ?? 0.0,
      ));
      if (mounted) {
        setState(() {
          _result = result;
          _isRunning = false;
        });
        _saveBacktestParams(); // U-1: 保存参数
      }
    } catch (e, st) {
      debugPrint('Backtest error: $e\n$st');
      if (mounted) {
        setState(() => _isRunning = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('回测出错: $e')));
      }
    }
  }

  Future<void> _runBatchBacktest(List<StockQuote> filteredQuotes) async {
    if (_presetCombos.isEmpty) {
      _buildDefaultPresets();
    }

    setState(() {
      _isRunning = true;
      _batchResults = [];
    });

    final initialCapital = double.tryParse(_initialCapitalController.text) ?? 100000;
    final feeRate = double.tryParse(_feeRateController.text) ?? 0.001;
    final positionRatio = double.tryParse(_positionRatioController.text) ?? 1.0;

    final results = await Future.wait(
      _presetCombos.map((params) => Future(() => BacktestCalculator.runBacktest(
        filteredQuotes,
        strategy: _selectedStrategy,
        initialCapital: initialCapital,
        feeRate: feeRate,
        positionRatio: positionRatio,
        params: params,
        // S-4: 止损止盈参数（批量回测共用）
        stopLossPercent: _stopLossPercent,
        takeProfitPercent: _takeProfitPercent,
        enableTimeExit: _enableTimeExit,
        maxHoldingDays: _maxHoldingDays,
        slippagePercent: _slippagePercent ?? 0.0,
      ))),
    );

    if (mounted) {
      setState(() {
        _batchResults = List.generate(_presetCombos.length, (i) => _ParamComboResult(_presetCombos[i], results[i]));
        _isRunning = false;
      });
      _saveBacktestParams(); // U-1: 保存参数
    }
  }

  List<StockQuote> _getFilteredQuotes(StockLoaded state) {
    return state.stockData.quotes.where((q) {
      final d = DateTime.parse(q.date);
      return !d.isBefore(_startDate) && !d.isAfter(_endDate);
    }).toList();
  }

  Future<void> _selectDate(bool isStart) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        if (picked.isAfter(_endDate)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('开始日期不能晚于结束日期')),
          );
          return;
        }
        _startDate = picked;
      } else {
        if (picked.isBefore(_startDate)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('结束日期不能早于开始日期')),
          );
          return;
        }
        _endDate = picked;
      }
      _result = null;
      _batchResults = [];
    });
  }

  Future<void> _ensureDataForRange(StockLoaded state) async {
    setState(() => _isLoadingData = true);
    final existingQuotes = state.stockData.quotes;
    DateTime? existingStart;
    DateTime? existingEnd;
    if (existingQuotes.isNotEmpty) {
      existingStart = DateTime.parse(existingQuotes.first.date);
      existingEnd = DateTime.parse(existingQuotes.last.date);
    }

    bool needFetch = existingQuotes.isEmpty;
    if (!needFetch && existingStart != null && _startDate.isBefore(existingStart)) needFetch = true;
    if (!needFetch && existingEnd != null && _endDate.isAfter(existingEnd)) needFetch = true;

    if (needFetch) {
      final start = _dateFormat.format(_startDate);
      final end = _dateFormat.format(_endDate);
      if (mounted) {
        context.read<StockBloc>().add(LoadStock(
          state.stockData.symbol,
          startDate: start,
          endDate: end,
        ));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('正在拉取 $start ~ $end 数据...')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('数据已覆盖所选时间段，直接回测')),
      );
    }
    setState(() => _isLoadingData = false);
  }

  void _showParamInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('参数说明', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('费率：买卖双向收取，一般为0.0005~0.001（万0.5~千1）', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            const Text('仓位：每次用于买入的比例，1.0=全仓，0.5=半仓', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            const Text('多参数比较：自动生成4组参数同时回测，点击结果行可查看详细', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            const Text('点击策略参数后，可自定义任意指标周期和阈值进行精细化回测', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('知道了'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStrategyName(BacktestStrategy s) {
    return switch (s) {
      BacktestStrategy.macd => 'MACD',
      BacktestStrategy.kdj => 'KDJ',
      BacktestStrategy.rsi => 'RSI',
      BacktestStrategy.boll => 'BOLL',
      BacktestStrategy.ma => 'MA均线',
      BacktestStrategy.wr => 'WR威廉',
      BacktestStrategy.dmi => 'DMI',
      BacktestStrategy.multi => '多指标综合',
      BacktestStrategy.cci => 'CCI顺势',
      BacktestStrategy.stochRsi => 'StochRSI',
    };
  }

  String _getStrategyDescription(BacktestStrategy s) {
    return switch (s) {
      BacktestStrategy.macd => 'MACD金叉买入，死叉卖出',
      BacktestStrategy.kdj => 'KDJ金叉买入，死叉卖出，可调超买超卖阈值',
      BacktestStrategy.rsi => 'RSI<超卖值买入，RSI>超买值卖出',
      BacktestStrategy.boll => '价格突破BOLL下轨买入，跌破上轨卖出',
      BacktestStrategy.ma => 'MA多头排列买入，空头排列卖出',
      BacktestStrategy.wr => 'WR威廉指标超卖区买入，超买区卖出',
      BacktestStrategy.dmi => 'DMI趋势跟随，ADX确认趋势强度',
      BacktestStrategy.multi => 'MACD + KDJ + RSI 三指标共振',
      BacktestStrategy.cci => 'CCI从-100以下上穿买入，从+100以上下穿卖出',
      BacktestStrategy.stochRsi => 'StochRSI金叉在超卖区买入，死叉在超买区卖出',
    };
  }
}

class _ParamComboResult {
  final StrategyParams params;
  final BacktestResult result;
  _ParamComboResult(this.params, this.result);
}
