import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../domain/entities/stock_quote.dart';
import '../blocs/stock/stock_bloc.dart';

class SignalAnalysisPage extends StatelessWidget {
  const SignalAnalysisPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('信号分析')),
      body: BlocBuilder<StockBloc, StockState>(
        builder: (context, state) {
          if (state is! StockLoaded) {
            return const Center(child: Text('请先加载股票数据'));
          }

          final quotes = state.stockData.quotes;
          final currentPrice = quotes.last.close;

          // Compute signals
          final macdSignal = state.macdSignal;
          final rsi = state.rsiData.isNotEmpty ? state.rsiData.last.rsi : null;
          final kdj = state.kdjData.isNotEmpty ? state.kdjData.last : null;
          final boll = state.bollData.isNotEmpty ? state.bollData.last : null;
          final wr = state.wrData.isNotEmpty ? state.wrData.last : null;
          final dmi = state.dmiData.isNotEmpty ? state.dmiData.last : null;
          final ma = state.maData.isNotEmpty ? state.maData.last : null;

          int buyCount = 0, sellCount = 0, watchCount = 0;

          String getMacdSignal() {
            if (macdSignal == null) return '观望';
            if (macdSignal.signal == MacdSignal.goldenCross) { buyCount++; return '买入'; }
            if (macdSignal.signal == MacdSignal.deathCross) { sellCount++; return '卖出'; }
            watchCount++; return '观望';
          }

          String getRsiSignal() {
            if (rsi == null) return '观望';
            if (rsi < 30) { buyCount++; return '买入'; }
            if (rsi > 70) { sellCount++; return '卖出'; }
            watchCount++; return '观望';
          }

          String getKdjSignal() {
            if (kdj == null) return '观望';
            if (kdj.k < 20) { buyCount++; return '买入'; }
            if (kdj.k > 80) { sellCount++; return '卖出'; }
            watchCount++; return '观望';
          }

          String getBollSignal() {
            if (boll == null) return '观望';
            if (currentPrice < boll.lower) { buyCount++; return '买入'; }
            if (currentPrice > boll.upper) { sellCount++; return '卖出'; }
            watchCount++; return '观望';
          }

          String getWrSignal() {
            if (wr == null) return '观望';
            // WR: 0 to -100. >-20 means overbought (sell), <-80 means oversold (buy)
            if (wr.wr6 > -80) { buyCount++; return '买入'; }
            if (wr.wr6 < -20) { sellCount++; return '卖出'; }
            watchCount++; return '观望';
          }

          String getDmiSignal() {
            if (dmi == null) return '观望';
            if (dmi.pdi > dmi.mdi && dmi.adx > 25) { buyCount++; return '买入'; }
            if (dmi.mdi > dmi.pdi && dmi.adx > 25) { sellCount++; return '卖出'; }
            watchCount++; return '观望';
          }

          String getMaSignal() {
            if (ma == null) return '观望';
            if (currentPrice > ma.ma20) { buyCount++; return '买入'; }
            if (currentPrice < ma.ma20) { sellCount++; return '卖出'; }
            watchCount++; return '观望';
          }

          final signals = [
            _SignalItem('MACD', macdSignal != null ? 'DIF=${state.macdData.last.dif.toStringAsFixed(3)} DEA=${state.macdData.last.dea.toStringAsFixed(3)}' : 'N/A', getMacdSignal(),
              macdSignal != null && macdSignal.signal == MacdSignal.goldenCross ? 'DIF上穿DEA，形成金叉' : macdSignal != null && macdSignal.signal == MacdSignal.deathCross ? 'DIF下穿DEA，形成死叉' : 'DIF与DEA未形成交叉'),
            _SignalItem('RSI', rsi != null ? rsi.toStringAsFixed(2) : 'N/A', getRsiSignal(),
              rsi != null ? (rsi < 30 ? 'RSI低于30，超卖区域，可能反弹' : rsi > 70 ? 'RSI高于70，超买区域，注意回落风险' : 'RSI在正常区间') : '数据不足'),
            _SignalItem('KDJ', kdj != null ? 'K=${kdj.k.toStringAsFixed(1)} D=${kdj.d.toStringAsFixed(1)} J=${kdj.j.toStringAsFixed(1)}' : 'N/A', getKdjSignal(),
              kdj != null ? (kdj.k < 20 ? 'K值低于20，超卖信号' : kdj.k > 80 ? 'K值高于80，超买信号' : 'KDJ在正常区间') : '数据不足'),
            _SignalItem('BOLL', boll != null ? '上轨=${boll.upper.toStringAsFixed(2)} 下轨=${boll.lower.toStringAsFixed(2)}' : 'N/A', getBollSignal(),
              boll != null ? (currentPrice < boll.lower ? '价格跌破布林下轨，超卖反弹信号' : currentPrice > boll.upper ? '价格突破布林上轨，超买回调风险' : '价格在布林带内运行') : '数据不足'),
            _SignalItem('WR', wr != null ? 'WR6=${wr.wr6.toStringAsFixed(1)} WR10=${wr.wr10.toStringAsFixed(1)}' : 'N/A', getWrSignal(),
              wr != null ? (wr.wr6 > -80 ? 'WR在高位，超卖反弹信号' : wr.wr6 < -20 ? 'WR在低位，超买回落信号' : '威廉指标在正常区间') : '数据不足'),
            _SignalItem('DMI', dmi != null ? 'PDI=${dmi.pdi.toStringAsFixed(1)} MDI=${dmi.mdi.toStringAsFixed(1)} ADX=${dmi.adx.toStringAsFixed(1)}' : 'N/A', getDmiSignal(),
              dmi != null ? (dmi.adx > 25 ? (dmi.pdi > dmi.mdi ? 'ADX>25且PDI>MDI，趋势向上' : 'ADX>25且MDI>PDI，趋势向下') : 'ADX<25，趋势不明显') : '数据不足'),
            _SignalItem('MA', ma != null ? 'MA20=${ma.ma20.toStringAsFixed(2)}' : 'N/A', getMaSignal(),
              ma != null ? (currentPrice > ma.ma20 ? '价格位于MA20均线上方，多头趋势' : '价格位于MA20均线下方，空头趋势') : '数据不足'),
          ];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(state.stockData.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('当前价: ${currentPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Signal summary bar
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSignalCount('买入', buyCount, Colors.green),
                        _buildSignalCount('卖出', sellCount, Colors.red),
                        _buildSignalCount('观望', watchCount, Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Signal list
                const Text('指标信号详情', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...signals.map((s) => _buildSignalCard(s)),

                // E-Ratio
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('E-Ratio 分析', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          quotes.length < 60 ? 'E-Ratio分析需要至少60个交易日数据，当前数据不足。' : 'E-Ratio用于评估趋势策略的效率，基于入场信号与实际趋势偏离程度计算。',
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),

                // Trading suggestion
                const SizedBox(height: 16),
                Card(
                  color: buyCount > sellCount ? Colors.green.withAlpha(13) : sellCount > buyCount ? Colors.red.withAlpha(13) : Colors.grey.withAlpha(13),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          buyCount > sellCount ? Icons.thumb_up : sellCount > buyCount ? Icons.thumb_down : Icons.remove,
                          color: buyCount > sellCount ? Colors.green : sellCount > buyCount ? Colors.red : Colors.grey,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          buyCount > sellCount ? '综合信号偏多 ($buyCount买入 vs $sellCount卖出)' : sellCount > buyCount ? '综合信号偏空 ($sellCount卖出 vs $buyCount买入)' : '信号分歧，建议观望',
                          style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold,
                            color: buyCount > sellCount ? Colors.green : sellCount > buyCount ? Colors.red : Colors.grey,
                          ),
                        ),
                        if (buyCount >= 4) const SizedBox(height: 4),
                        if (buyCount >= 4) const Text('多指标共振，看涨信号较强', style: TextStyle(fontSize: 12, color: Colors.green)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSignalCount(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withAlpha(25), border: Border.all(color: color, width: 2)),
          child: Center(child: Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color))),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }

  Widget _buildSignalCard(_SignalItem s) {
    final badgeColor = s.signal == '买入' ? Colors.green : s.signal == '卖出' ? Colors.red : Colors.grey;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: badgeColor.withAlpha(25), borderRadius: BorderRadius.circular(8)),
              child: Text(s.signal, style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(s.value, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(s.reason, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalItem {
  final String name;
  final String value;
  final String signal;
  final String reason;
  _SignalItem(this.name, this.value, this.signal, this.reason);
}
