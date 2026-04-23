import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../widgets/candle_chart_widget.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/stock_quote.dart';
import '../blocs/stock/stock_bloc.dart';
import '../blocs/chart/chart_state.dart';
import '../blocs/watchlist/watchlist_cubit.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final _searchController = TextEditingController();

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
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
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
    );
  }

  Widget _buildSearchBar() {
    // Watch StockBloc so Autocomplete rebuilds when history changes
    context.watch<StockBloc>();
    final storage = context.read<StockBloc>().stockStorage;
    final history = storage.getSearchHistory();

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return history.take(5);
                }
                return history.where((s) =>
                    s.toLowerCase().contains(textEditingValue.text.toLowerCase()));
              },
              onSelected: (String symbol) {
                _searchController.text = symbol;
                _searchStock();
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                // Sync with our controller
                controller.text = _searchController.text;
                controller.addListener(() {
                  if (_searchController.text != controller.text) {
                    _searchController.text = controller.text;
                  }
                });
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: AppStrings.searchHint,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    suffixIcon: controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              controller.clear();
                              _searchController.clear();
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (_) => _searchStock(),
                );
              },
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

  static const _dateRanges = <Map<String, dynamic>>[
    {'label': '近1周',  'days': 7},
    {'label': '近1月',  'days': 30},
    {'label': '近3月',  'days': 90},
    {'label': '近6月',  'days': 180},
    {'label': '近1年',  'days': 365},
    {'label': '近5年',  'days': 1825},
  ];

  String _selectedRange = '近1月';

  String _daysToDateRange(int days) {
    final now = DateTime.now();
    final end = now;
    final start = end.subtract(Duration(days: days));
    return '${_fmtDate(start)} ~ ${_fmtDate(end)}';
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _onRangeSelected(String label, int days) {
    setState(() => _selectedRange = label);
    final range = _daysToDateRange(days);
    final parts = range.split(' ~ ');
    context.read<StockBloc>().add(ChangeDateRange(parts[0], parts[1]));
  }

  Widget _buildDateRange() {
    return BlocBuilder<StockBloc, StockState>(
      builder: (context, state) {
        final hasData = state is StockLoaded;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasData)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    '${(state as StockLoaded).startDate} ~ ${state.endDate}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _dateRanges.map((r) {
                    final selected = r['label'] == _selectedRange;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(r['label'], style: const TextStyle(fontSize: 12)),
                        selected: selected,
                        selectedColor: AppColors.primary.withAlpha(51),
                        onSelected: (_) => _onRangeSelected(r['label'], r['days'] as int),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBar() {
    return BlocBuilder<ChartCubit, ChartState>(
      buildWhen: (prev, curr) => prev.currentTab != curr.currentTab,
      builder: (context, chartState) {
        return SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _tabNames.length,
            itemBuilder: (context, index) {
              final isSelected = chartState.currentTab == index;
              return GestureDetector(
                onTap: () => context.read<ChartCubit>().changeTab(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _tabNames[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildChartContent() {
    return BlocConsumer<StockBloc, StockState>(
      listener: (context, state) {
        if (state is StockError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is StockLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is StockError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                const SizedBox(height: 8),
                Text(state.message, style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.read<StockBloc>().add(RefreshStock()),
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        if (state is StockLoaded) {
          // Listen to ChartCubit to rebuild chart when tab changes
          return BlocBuilder<ChartCubit, ChartState>(
            buildWhen: (prev, curr) => prev.currentTab != curr.currentTab,
            builder: (context, chartState) => Column(
              children: [
                _buildStockInfo(state.stockData),
                _buildSignalIndicator(state),
                Expanded(child: _buildChart(state)),
              ],
            ),
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
          IconButton(
            icon: const Icon(Icons.star_border),
            tooltip: '添加自选',
            onPressed: () {
              context.read<WatchlistCubit>().addToWatchlist(data.symbol, data.name);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${data.name} 已添加到自选'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: '多因子分析',
            onPressed: () => context.go('/analysis'),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalIndicator(StockLoaded state) {
    final chartTab = context.watch<ChartCubit>().state.currentTab;
    if (chartTab == 1 && state.macdSignal != null) {
      final signal = state.macdSignal!;
      final isGolden = signal.signal == MacdSignal.goldenCross;

      return Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: (isGolden ? AppColors.bullish : AppColors.bearish).withAlpha(25),
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
    final chartTab = context.watch<ChartCubit>().state.currentTab;
    switch (chartTab) {
      case 0:
        return _buildKLineChart(state.stockData.quotes, state.maData);
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
        return _buildKLineChart(state.stockData.quotes, state.maData);
    }
  }

  Widget _buildKLineChart(List<StockQuote> quotes, List<MaData> maData) {
    final displayQuotes = quotes.length > 100 ? quotes.sublist(quotes.length - 100) : quotes;
    if (displayQuotes.isEmpty) return const Center(child: Text('数据不足'));

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
        child: CandleChartWidget(
          quotes: displayQuotes,
          maData: maData,
        ),
      ),
    );
  }

  // Removed duplicate _computeMa method - now uses MaData from StockLoaded state

  Widget _buildMacdChart(List<MacdData> data) {
    if (data.isEmpty) return const Center(child: Text('数据不足'));

    final displayData = data.length > 100 ? data.sublist(data.length - 100) : data;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
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
            backgroundColor: AppColors.chartBackground,
            gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 1),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
          ),
        ),
      ),
    );
  }

  Widget _buildRsiChart(List<RsiData> data) {
    if (data.isEmpty) return const Center(child: Text('数据不足'));

    final displayData = data.length > 100 ? data.sublist(data.length - 100) : data;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
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
            backgroundColor: AppColors.chartBackground,
            gridData: FlGridData(show: true, drawVerticalLine: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
          ),
        ),
      ),
    );
  }

  Widget _buildKdjChart(List<KdjData> data) {
    if (data.isEmpty) return const Center(child: Text('数据不足'));

    final displayData = data.length > 100 ? data.sublist(data.length - 100) : data;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
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
            backgroundColor: AppColors.chartBackground,
            gridData: FlGridData(show: true, drawVerticalLine: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
          ),
        ),
      ),
    );
  }

  Widget _buildBollChart(List<BollData> data, List<StockQuote> quotes) {
    if (data.isEmpty) return const Center(child: Text('数据不足'));

    final displayData = data.length > 100 ? data.sublist(data.length - 100) : data;
    final displayQuotes = quotes.sublist(quotes.length - displayData.length);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
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
            backgroundColor: AppColors.chartBackground,
            gridData: FlGridData(show: true, drawVerticalLine: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
          ),
        ),
      ),
    );
  }

  Widget _buildMaChart(List<MaData> data) {
    if (data.isEmpty) return const Center(child: Text('数据不足'));

    final displayData = data.length > 100 ? data.sublist(data.length - 100) : data;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
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
            backgroundColor: AppColors.chartBackground,
            gridData: FlGridData(show: true, drawVerticalLine: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
          ),
        ),
      ),
    );
  }

  Widget _buildWrChart(List<WrData> data) {
    if (data.isEmpty) return const Center(child: Text('数据不足'));

    final displayData = data.length > 100 ? data.sublist(data.length - 100) : data;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
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
            backgroundColor: AppColors.chartBackground,
            gridData: FlGridData(show: true, drawVerticalLine: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
          ),
        ),
      ),
    );
  }

  Widget _buildDmiChart(List<DmiData> data) {
    if (data.isEmpty) return const Center(child: Text('数据不足'));

    final displayData = data.length > 100 ? data.sublist(data.length - 100) : data;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
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
            backgroundColor: AppColors.chartBackground,
            gridData: FlGridData(show: true, drawVerticalLine: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
          ),
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

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: BarChart(
          BarChartData(
            barGroups: bins.asMap().entries.map((e) {
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.toDouble(),
                    color: AppColors.primary,
                    width: 16,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              );
            }).toList(),
            backgroundColor: AppColors.chartBackground,
            gridData: FlGridData(show: true, drawVerticalLine: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
          ),
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

}
