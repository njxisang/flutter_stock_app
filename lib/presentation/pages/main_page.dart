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

class _MainPageState extends State<MainPage> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late TabController _tabController;

  final _tabNames = ['K线', '分时', '日K', '周K', '月K', '指数'];
  final _indicatorTabs = ['MACD', 'RSI', 'KDJ', 'BOLL', 'MA', 'WR', 'DMI'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabNames.length, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(child: _buildChartContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return BlocBuilder<StockBloc, StockState>(
      builder: (context, state) {
        if (state is StockLoaded) {
          final data = state.stockData;
          final change = data.quotes.length > 1
              ? data.quotes.last.close - data.quotes[data.quotes.length - 2].close
              : 0.0;
          final changePercent = data.quotes.length > 1
              ? (change / data.quotes[data.quotes.length - 2].close) * 100
              : 0.0;
          final isPositive = change >= 0;
          final changeColor = isPositive ? AppColors.bullish : AppColors.bearish;

          final watchlistState = context.watch<WatchlistCubit>().state;
          final isInWatchlist = watchlistState.items.any((item) => item.symbol == data.symbol);

          return Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                data.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(20),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  data.symbol,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                data.quotes.last.close.toStringAsFixed(2),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: changeColor.withAlpha(25),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${isPositive ? '+' : ''}${change.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: changeColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: changeColor.withAlpha(25),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${isPositive ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: changeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (isInWatchlist) {
                              context.read<WatchlistCubit>().removeFromWatchlist(data.symbol);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${data.name} 已从自选移除'),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } else {
                              context.read<WatchlistCubit>().addToWatchlist(data.symbol, data.name);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${data.name} 已添加自选'),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isInWatchlist ? Colors.amber.withAlpha(51) : Colors.grey.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isInWatchlist ? Icons.star : Icons.star_border,
                              color: isInWatchlist ? Colors.amber : Colors.grey,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => context.go('/analysis'),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.analytics_outlined,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        }
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                AppStrings.appName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.settings, color: AppColors.textSecondary),
                onPressed: () => context.go('/settings'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    context.watch<StockBloc>();
    final storage = context.read<StockBloc>().stockStorage;
    final history = storage.getSearchHistory();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: AppStrings.searchHint,
                  hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                style: const TextStyle(fontSize: 14),
                onSubmitted: (_) => _searchStock(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _searchStock,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '搜索',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
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
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (state is StockError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                const SizedBox(height: 8),
                Text(
                  state.message,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
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
          return Column(
            children: [
              _buildDateRangeBar(),
              _buildChartTabs(),
              _buildIndicatorTabs(),
              Expanded(child: _buildChart(state)),
              _buildStockDetails(state),
            ],
          );
        }

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text(
                AppStrings.pleaseSearchStock,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                '输入股票代码搜索，如：000001',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateRangeBar() {
    return BlocBuilder<StockBloc, StockState>(
      builder: (context, state) {
        final hasData = state is StockLoaded;
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (hasData)
                Text(
                  '${(state as StockLoaded).startDate} ~ ${state.endDate}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              const Spacer(),
              _buildDateChip('1月', 30),
              _buildDateChip('3月', 90),
              _buildDateChip('6月', 180),
              _buildDateChip('1年', 365),
              _buildDateChip('5年', 1825),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateChip(String label, int days) {
    return GestureDetector(
      onTap: () {
        final now = DateTime.now();
        final start = now.subtract(Duration(days: days));
        final startStr = '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
        final endStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        context.read<StockBloc>().add(ChangeDateRange(startStr, endStr));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        margin: const EdgeInsets.only(left: 6),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildChartTabs() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
        tabs: _tabNames.map((e) => Tab(text: e)).toList(),
      ),
    );
  }

  Widget _buildIndicatorTabs() {
    return BlocBuilder<ChartCubit, ChartState>(
      builder: (context, chartState) {
        return Container(
          color: AppColors.background,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _indicatorTabs.asMap().entries.map((entry) {
                final isSelected = chartState.currentTab == entry.key;
                return GestureDetector(
                  onTap: () => context.read<ChartCubit>().changeTab(entry.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
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
      default:
        return _buildKLineChart(state.stockData.quotes, state.maData);
    }
  }

  Widget _buildKLineChart(List<StockQuote> quotes, List<MaData> maData) {
    final displayQuotes = quotes.length > 100 ? quotes.sublist(quotes.length - 100) : quotes;
    if (displayQuotes.isEmpty) {
      return const Center(child: Text('数据不足', style: TextStyle(color: AppColors.textSecondary)));
    }

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.chartBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: CandleChartWidget(
        quotes: displayQuotes,
        maData: maData,
      ),
    );
  }

  Widget _buildMacdChart(List<MacdData> data) {
    if (data.isEmpty) return const Center(child: Text('数据不足'));
    final displayData = data.length > 100 ? data.sublist(data.length - 100) : data;

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.chartBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.dif)).toList(),
              color: AppColors.difColor,
              isCurved: true,
            ),
            LineChartBarData(
              spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.dea)).toList(),
              color: AppColors.deaColor,
              isCurved: true,
            ),
          ],
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildRsiChart(List<RsiData> data) {
    if (data.isEmpty) return const Center(child: Text('数据不足'));
    final displayData = data.length > 100 ? data.sublist(data.length - 100) : data;

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.chartBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.rsi)).toList(),
              color: AppColors.primary,
              isCurved: true,
            ),
          ],
          minY: 0,
          maxY: 100,
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildKdjChart(List<KdjData> data) {
    if (data.isEmpty) return const Center(child: Text('数据不足'));
    final displayData = data.length > 100 ? data.sublist(data.length - 100) : data;

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.chartBackground,
        borderRadius: BorderRadius.circular(8),
      ),
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
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildBollChart(List<BollData> data, List<StockQuote> quotes) {
    if (data.isEmpty) return const Center(child: Text('数据不足'));
    final displayData = data.length > 100 ? data.sublist(data.length - 100) : data;
    final displayQuotes = quotes.sublist(quotes.length - displayData.length);

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.chartBackground,
        borderRadius: BorderRadius.circular(8),
      ),
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
              color: AppColors.textLight,
            ),
          ],
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildMaChart(List<MaData> data) {
    if (data.isEmpty) return const Center(child: Text('数据不足'));
    final displayData = data.length > 100 ? data.sublist(data.length - 100) : data;

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.chartBackground,
        borderRadius: BorderRadius.circular(8),
      ),
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
          ],
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildWrChart(List<WrData> data) {
    if (data.isEmpty) return const Center(child: Text('数据不足'));
    final displayData = data.length > 100 ? data.sublist(data.length - 100) : data;

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.chartBackground,
        borderRadius: BorderRadius.circular(8),
      ),
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
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildStockDetails(StockLoaded state) {
    final q = state.stockData.quotes.last;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildDetailItem('开盘', q.open.toStringAsFixed(2)),
              _buildDetailItem('最高', q.high.toStringAsFixed(2)),
              _buildDetailItem('最低', q.low.toStringAsFixed(2)),
              _buildDetailItem('成交量', _formatVolume(q.volume)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  String _formatVolume(int volume) {
    if (volume >= 100000000) {
      return '${(volume / 100000000).toStringAsFixed(2)}亿';
    } else if (volume >= 10000) {
      return '${(volume / 10000).toStringAsFixed(2)}万';
    }
    return volume.toString();
  }

  void _searchStock() {
    final code = _searchController.text.trim().toUpperCase();
    if (code.isNotEmpty) {
      context.read<StockBloc>().add(LoadStock(code));
    }
  }
}
