import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/stock_quote.dart';
import '../../domain/usecases/calculators/macd_calculator.dart';
import '../blocs/stock/stock_bloc.dart';
import '../blocs/chart/chart_state.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final _searchController = TextEditingController();
  int _currentTabIndex = 0;

  final _tabNames = ['K线', 'MACD', 'RSI', 'KDJ', 'BOLL', 'MA', 'WR', 'DMI', '分布'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showSettingsDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildDateRange(),
          _buildTabBar(),
          Expanded(child: _buildChartContent()),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: '图表'),
          BottomNavigationBarItem(icon: Icon(Icons.star), label: '自选'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: '历史'),
          BottomNavigationBarItem(icon: Icon(Icons.play_arrow), label: '回测'),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: AppStrings.searchHint,
                border: OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _searchStock,
            child: const Text(AppStrings.search),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRange() {
    return BlocBuilder<StockBloc, StockState>(
      builder: (context, state) {
        if (state is StockLoaded) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${state.startDate} ~ ${state.endDate}', style: const TextStyle(fontSize: 12)),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildTabBar() {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _tabNames.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              setState(() => _currentTabIndex = index);
              context.read<ChartCubit>().changeTab(index);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _currentTabIndex == index ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _tabNames[index],
                style: TextStyle(
                  color: _currentTabIndex == index ? Colors.white : AppColors.textPrimary,
                  fontWeight: _currentTabIndex == index ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChartContent() {
    return BlocBuilder<StockBloc, StockState>(
      builder: (context, state) {
        if (state is StockLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is StockError) {
          return Center(child: Text(state.message));
        }

        if (state is StockLoaded) {
          return Column(
            children: [
              _buildStockInfo(state.stockData),
              _buildSignalIndicator(state),
              Expanded(child: _buildChart(state)),
            ],
          );
        }

        return const Center(child: Text('搜索股票查看数据'));
      },
    );
  }

  Widget _buildStockInfo(StockData data) {
    final change = data.quotes.length > 1
        ? data.quotes.last.close - data.quotes[data.quotes.length - 2].close
        : 0.0;
    final changePercent = data.quotes.length > 1
        ? (change / data.quotes[data.quotes.length - 2].close) * 100
        : 0.0;
    final isPositive = change >= 0;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(data.symbol, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                data.quotes.last.close.toStringAsFixed(2),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                '${isPositive ? '+' : ''}${change.toStringAsFixed(2)} (${changePercent.toStringAsFixed(2)}%)',
                style: TextStyle(color: isPositive ? AppColors.bullish : AppColors.bearish),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignalIndicator(StockLoaded state) {
    if (_currentTabIndex == 1 && state.macdSignal != null) {
      final signal = state.macdSignal!;
      final isGolden = signal.signal == MacdSignal.goldenCross;

      return Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: (isGolden ? AppColors.bullish : AppColors.bearish).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isGolden ? Icons.trending_up : Icons.trending_down,
              color: isGolden ? AppColors.bullish : AppColors.bearish,
            ),
            const SizedBox(width: 8),
            Text(
              isGolden ? AppStrings.goldenCross : AppStrings.deathCross,
              style: TextStyle(
                color: isGolden ? AppColors.bullish : AppColors.bearish,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildChart(StockLoaded state) {
    switch (_currentTabIndex) {
      case 0:
        return _buildKLineChart(state.stockData.quotes);
      case 1:
        return _buildMacdChart(state.macdData);
      case 2:
        return _buildRsiChart(state.rsiData);
      case 3:
        return _buildKdjChart(state.kdjData);
      case 4:
        return _buildBollChart(state.bollData, state.stockData.quotes);
      case 5:
        return _buildMaChart(state.maData);
      case 6:
        return _buildWrChart(state.wrData);
      case 7:
        return _buildDmiChart(state.dmiData);
      case 8:
        return _buildDistributionChart(state.stockData.quotes);
      default:
        return _buildKLineChart(state.stockData.quotes);
    }
  }

  Widget _buildKLineChart(List<StockQuote> quotes) {
    final displayQuotes = quotes.length > 100 ? quotes.sublist(quotes.length - 100) : quotes;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: BarChart(
        BarChartData(
          barGroups: displayQuotes.asMap().entries.map((entry) {
            final quote = entry.value;
            final isUp = quote.close >= quote.open;
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: quote.high,
                  fromY: quote.low,
                  color: isUp ? AppColors.bullish : AppColors.bearish,
                  width: 8,
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMacdChart(List<MacdData> data) {
    if (data.isEmpty) return const Center(child: Text('数据不足'));

    final displayData = data.length > 100 ? data.sublist(data.length - 100) : data;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.dif)).toList(),
              color: AppColors.difColor,
            ),
            LineChartBarData(
              spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.dea)).toList(),
              color: AppColors.deaColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRsiChart(List<RsiData> data) {
    if (data.isEmpty) return const Center(child: Text('数据不足'));

    final displayData = data.length > 100 ? data.sublist(data.length - 100) : data;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.rsi)).toList(),
              color: AppColors.primary,
            ),
          ],
          minY: 0,
          maxY: 100,
        ),
      ),
    );
  }

  Widget _buildKdjChart(List<KdjData> data) {
    if (data.isEmpty) return const Center(child: Text('数据不足'));

    final displayData = data.length > 100 ? data.sublist(data.length - 100) : data;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.k)).toList(),
              color: AppColors.kColor,
            ),
            LineChartBarData(
              spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.d)).toList(),
              color: AppColors.dColor,
            ),
            LineChartBarData(
              spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.j)).toList(),
              color: AppColors.jColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBollChart(List<BollData> data, List<StockQuote> quotes) {
    if (data.isEmpty) return const Center(child: Text('数据不足'));

    final displayData = data.length > 100 ? data.sublist(data.length - 100) : data;
    final displayQuotes = quotes.sublist(quotes.length - displayData.length);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.upper)).toList(),
              color: AppColors.bollUpper,
            ),
            LineChartBarData(
              spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.middle)).toList(),
              color: AppColors.bollMiddle,
            ),
            LineChartBarData(
              spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.lower)).toList(),
              color: AppColors.bollLower,
            ),
            LineChartBarData(
              spots: displayQuotes.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.close)).toList(),
              color: AppColors.textPrimary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaChart(List<MaData> data) {
    if (data.isEmpty) return const Center(child: Text('数据不足'));

    final displayData = data.length > 100 ? data.sublist(data.length - 100) : data;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.ma5)).toList(),
              color: AppColors.ma5Color,
            ),
            LineChartBarData(
              spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.ma10)).toList(),
              color: AppColors.ma10Color,
            ),
            LineChartBarData(
              spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.ma20)).toList(),
              color: AppColors.ma20Color,
            ),
            LineChartBarData(
              spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.ma60)).toList(),
              color: AppColors.ma60Color,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWrChart(List<WrData> data) {
    if (data.isEmpty) return const Center(child: Text('数据不足'));

    final displayData = data.length > 100 ? data.sublist(data.length - 100) : data;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.wr6)).toList(),
              color: AppColors.wr6Color,
            ),
            LineChartBarData(
              spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.wr10)).toList(),
              color: AppColors.wr10Color,
            ),
          ],
          minY: -100,
          maxY: 0,
        ),
      ),
    );
  }

  Widget _buildDmiChart(List<DmiData> data) {
    if (data.isEmpty) return const Center(child: Text('数据不足'));

    final displayData = data.length > 100 ? data.sublist(data.length - 100) : data;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.pdi)).toList(),
              color: AppColors.pdiColor,
            ),
            LineChartBarData(
              spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.mdi)).toList(),
              color: AppColors.mdiColor,
            ),
            LineChartBarData(
              spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.adx)).toList(),
              color: AppColors.adxColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionChart(List<StockQuote> quotes) {
    if (quotes.isEmpty) return const Center(child: Text('数据不足'));

    final prices = quotes.map((q) => q.close).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);

    const binCount = 10;
    final binSize = (maxPrice - minPrice) / binCount;
    final bins = List.filled(binCount, 0);

    for (final price in prices) {
      final binIndex = ((price - minPrice) / binSize).toInt().clamp(0, binCount - 1);
      bins[binIndex]++;
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: BarChart(
        BarChartData(
          barGroups: bins.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.toDouble(),
                  color: AppColors.primary,
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _searchStock() {
    final code = _searchController.text.trim().toUpperCase();
    if (code.isNotEmpty) {
      context.read<StockBloc>().add(LoadStock(code));
    }
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.settings),
        content: const Text('设置功能开发中...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
