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

  final _tabNames = ['K线', '分时', '日K', '周K', '月K', '指数'];
  final _indicatorTabs = ['MACD', 'RSI', 'KDJ', 'BOLL', 'MA', 'WR', 'DMI'];

  @override
  void dispose() {
    _searchController.dispose();
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
            color: AppColors.surface,
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
          color: AppColors.surface,
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

    return Container(
      color: AppColors.surface,
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
                decoration: InputDecoration(
                  hintText: AppStrings.searchHint,
                  hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: AppColors.textSecondary, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                style: const TextStyle(fontSize: 14),
                onChanged: (_) => setState(() {}),
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
              Icon(Icons.search, size: 64, color: AppColors.textTertiary),
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
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (hasData)
                Text(
                  '${state.startDate} ~ ${state.endDate}',
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
    final chartCubit = context.watch<ChartCubit>();
    final currentTab = chartCubit.state.currentTab;
    return Container(
      color: AppColors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _tabNames.asMap().entries.map((entry) {
            final isSelected = currentTab == entry.key;
            return GestureDetector(
              onTap: () => chartCubit.changeTab(entry.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
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
                final isSelected = chartState.indicatorTab == entry.key;
                return GestureDetector(
                  onTap: () => context.read<ChartCubit>().changeIndicatorTab(entry.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.cardBackground,
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
                        color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
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
    final indicatorTab = context.watch<ChartCubit>().state.indicatorTab;

    final mainChart = _buildMainChart(chartTab, state);
    final indicatorChart = _buildIndicatorChart(indicatorTab, state);

    // indicatorTab == 0 (MACD): 保持 K线 + MACD 上下分区布局
    // indicatorTab >= 1 (RSI/KDJ/BOLL/MA/WR/DMI): 全高 K线 + 全高指标图
    final isMacdMode = indicatorTab == 0;

    return Column(
      children: [
        Expanded(flex: isMacdMode ? 10 : 10, child: mainChart),
        if (!isMacdMode) ...[
          const Divider(height: 1, color: AppColors.border),
          Expanded(flex: 6, child: indicatorChart),
        ],
      ],
    );
  }

  Widget _buildMainChart(int chartTab, StockLoaded state) {
    // ⚠️ 限制说明：免费A股行情API（东方财富/新浪）不提供日K/周K/月K分时间周期数据接口，
    // 当前所有Tab均渲染日K线。后续可接入付费数据源（如Tushare Pro）实现真正的周期切换。
    // 6个Tab[K线/分时/日K/周K/月K/指数]在数据源具备条件后可分别渲染：
    //   Tab 0 K线 — 日K柱状图（当前）
    //   Tab 1 分时 — 分时图（需1分钟数据）
    //   Tab 2 日K — 日K柱状图
    //   Tab 3 周K — 周K柱状图（需周线数据）
    //   Tab 4 月K — 月K柱状图（需月线数据）
    //   Tab 5 指数 — 专属指数（如查看上证指数时）
    return _buildKLineChart(state.stockData.quotes, state.maData);
  }

  Widget _buildIndicatorChart(int indicatorTab, StockLoaded state) {
    switch (indicatorTab) {
      case 0:
        return _buildMacdChart(state.macdData);
      case 1:
        return _buildRsiChart(state.rsiData);
      case 2:
        return _buildKdjChart(state.kdjData);
      case 3:
        return _buildBollChart(state.bollData, state.stockData.quotes);
      case 4:
        return _buildMaChart(state.maData);
      case 5:
        return _buildWrChart(state.wrData);
      case 6:
        return _buildDmiChart(state.dmiData);
      default:
        return _buildMacdChart(state.macdData);
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
      child: SizedBox.expand(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: CandleChartWidget(
            quotes: displayQuotes,
            maData: maData,
          ),
        ),
      ),
    );
  }

  Widget _buildMacdChart(List<MacdData> data) {
    if (data.isEmpty) return const Center(child: Text('数据不足'));
    final displayData = data.length > 100 ? data.sublist(data.length - 100) : data;

    // 动态计算范围
    double minY = double.infinity, maxY = double.negativeInfinity;
    for (final d in displayData) {
      if (d.dif < minY) minY = d.dif;
      if (d.dif > maxY) maxY = d.dif;
      if (d.dea < minY) minY = d.dea;
      if (d.dea > maxY) maxY = d.dea;
      if (d.macd < minY) minY = d.macd;
      if (d.macd > maxY) maxY = d.macd;
    }
    final pad = (maxY - minY) * 0.15;
    minY = minY - pad;
    maxY = maxY + pad;

    return Container(
      margin: const EdgeInsets.only(left: 36, right: 8, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.chartBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: constraints.maxHeight,
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.dif)).toList(),
                    color: AppColors.difColor,
                    isCurved: true,
                    barWidth: 1.5,
                  ),
                  LineChartBarData(
                    spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.dea)).toList(),
                    color: AppColors.deaColor,
                    isCurved: true,
                    barWidth: 1.5,
                  ),
                ],
                minY: minY,
                maxY: maxY,
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(y: 0, color: AppColors.gridLine, strokeWidth: 0.8, dashArray: [4, 4]),
                  ],
                ),
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRsiChart(List<RsiData> data) {
    if (data.isEmpty) return const Center(child: Text('数据不足'));
    final displayData = data.length > 100 ? data.sublist(data.length - 100) : data;

    // 动态计算范围，留出上下边距
    double minY = 0, maxY = 100;
    for (final d in displayData) {
      if (d.rsi < minY) minY = d.rsi;
      if (d.rsi > maxY) maxY = d.rsi;
    }
    final pad = (maxY - minY) * 0.15;
    minY = (minY - pad).clamp(0, 100);
    maxY = (maxY + pad).clamp(0, 100);

    return Container(
      margin: const EdgeInsets.only(left: 36, right: 8, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.chartBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: constraints.maxHeight,
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.rsi)).toList(),
                    color: AppColors.primary,
                    isCurved: true,
                    barWidth: 1.5,
                  ),
                ],
                minY: minY,
                maxY: maxY,
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(y: 50, color: AppColors.gridLine, strokeWidth: 0.8, dashArray: [4, 4]),
                    HorizontalLine(y: 30, color: AppColors.gridLine, strokeWidth: 0.5, dashArray: [2, 4]),
                    HorizontalLine(y: 70, color: AppColors.gridLine, strokeWidth: 0.5, dashArray: [2, 4]),
                  ],
                ),
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKdjChart(List<KdjData> data) {
    if (data.isEmpty) return const Center(child: Text('数据不足'));
    final displayData = data.length > 100 ? data.sublist(data.length - 100) : data;

    // 动态计算范围，留出上下边距
    double minY = double.infinity, maxY = double.negativeInfinity;
    for (final d in displayData) {
      if (d.k < minY) minY = d.k;
      if (d.k > maxY) maxY = d.k;
      if (d.d < minY) minY = d.d;
      if (d.d > maxY) maxY = d.d;
      if (d.j < minY) minY = d.j;
      if (d.j > maxY) maxY = d.j;
    }
    final pad = (maxY - minY) * 0.15;
    minY = minY - pad;
    maxY = maxY + pad;

    return Container(
      margin: const EdgeInsets.only(left: 36, right: 8, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.chartBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: constraints.maxHeight,
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.k)).toList(),
                    color: AppColors.kColor,
                    barWidth: 1.5,
                  ),
                  LineChartBarData(
                    spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.d)).toList(),
                    color: AppColors.dColor,
                    barWidth: 1.5,
                  ),
                  LineChartBarData(
                    spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.j)).toList(),
                    color: AppColors.jColor,
                    barWidth: 1.5,
                  ),
                ],
                minY: minY,
                maxY: maxY,
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(y: 80, color: AppColors.gridLine, strokeWidth: 0.8, dashArray: [4, 4]),
                    HorizontalLine(y: 20, color: AppColors.gridLine, strokeWidth: 0.8, dashArray: [4, 4]),
                  ],
                ),
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBollChart(List<BollData> data, List<StockQuote> quotes) {
    if (data.isEmpty) return const Center(child: Text('数据不足'));
    final displayData = data.length > 100 ? data.sublist(data.length - 100) : data;
    final displayQuotes = quotes.sublist(quotes.length - displayData.length);

    // 动态计算范围
    double minY = double.infinity, maxY = double.negativeInfinity;
    for (final d in displayData) {
      if (d.upper < minY) minY = d.upper;
      if (d.upper > maxY) maxY = d.upper;
      if (d.middle < minY) minY = d.middle;
      if (d.middle > maxY) maxY = d.middle;
      if (d.lower < minY) minY = d.lower;
      if (d.lower > maxY) maxY = d.lower;
    }
    for (final q in displayQuotes) {
      if (q.close < minY) minY = q.close;
      if (q.close > maxY) maxY = q.close;
    }
    final pad = (maxY - minY) * 0.1;
    minY = minY - pad;
    maxY = maxY + pad;

    return Container(
      margin: const EdgeInsets.only(left: 36, right: 8, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.chartBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: constraints.maxHeight,
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.upper)).toList(),
                    color: AppColors.bollUpper,
                    isCurved: true,
                    barWidth: 1.5,
                  ),
                  LineChartBarData(
                    spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.middle)).toList(),
                    color: AppColors.bollMiddle,
                    isCurved: true,
                    barWidth: 1.5,
                  ),
                  LineChartBarData(
                    spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.lower)).toList(),
                    color: AppColors.bollLower,
                    isCurved: true,
                    barWidth: 1.5,
                  ),
                  LineChartBarData(
                    spots: displayQuotes.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.close)).toList(),
                    color: AppColors.textPrimary,
                    barWidth: 1.2,
                  ),
                ],
                betweenBarsData: [
                  BetweenBarsData(
                    fromIndex: 0,
                    toIndex: 2,
                    color: AppColors.bollUpper.withOpacity(0.08),
                  ),
                ],
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMaChart(List<MaData> data) {
    if (data.isEmpty) return const Center(child: Text('数据不足'));
    final displayData = data.length > 100 ? data.sublist(data.length - 100) : data;

    double minY = double.infinity, maxY = double.negativeInfinity;
    for (final d in displayData) {
      if (d.ma5 < minY) minY = d.ma5;
      if (d.ma5 > maxY) maxY = d.ma5;
      if (d.ma10 < minY) minY = d.ma10;
      if (d.ma10 > maxY) maxY = d.ma10;
      if (d.ma20 < minY) minY = d.ma20;
      if (d.ma20 > maxY) maxY = d.ma20;
    }
    final pad = (maxY - minY) * 0.15;
    minY = minY - pad;
    maxY = maxY + pad;

    return Container(
      margin: const EdgeInsets.only(left: 36, right: 8, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.chartBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: constraints.maxHeight,
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.ma5)).toList(),
                    color: AppColors.ma5Color,
                    barWidth: 1.5,
                  ),
                  LineChartBarData(
                    spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.ma10)).toList(),
                    color: AppColors.ma10Color,
                    barWidth: 1.5,
                  ),
                  LineChartBarData(
                    spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.ma20)).toList(),
                    color: AppColors.ma20Color,
                    barWidth: 1.5,
                  ),
                ],
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWrChart(List<WrData> data) {
    if (data.isEmpty) return const Center(child: Text('数据不足'));
    final displayData = data.length > 100 ? data.sublist(data.length - 100) : data;

    // 动态计算范围，防止数据超出固定边界
    double minY = double.infinity, maxY = double.negativeInfinity;
    for (final d in displayData) {
      if (d.wr6 < minY) minY = d.wr6;
      if (d.wr6 > maxY) maxY = d.wr6;
      if (d.wr10 < minY) minY = d.wr10;
      if (d.wr10 > maxY) maxY = d.wr10;
    }
    final pad = (maxY - minY) * 0.15;
    minY = minY - pad;
    maxY = maxY + pad;

    return Container(
      margin: const EdgeInsets.only(left: 36, right: 8, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.chartBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: constraints.maxHeight,
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.wr6)).toList(),
                    color: AppColors.wr6Color,
                    barWidth: 1.5,
                  ),
                  LineChartBarData(
                    spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.wr10)).toList(),
                    color: AppColors.wr10Color,
                    barWidth: 1.5,
                  ),
                ],
                minY: minY,
                maxY: maxY,
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(y: -20, color: AppColors.gridLine, strokeWidth: 0.8, dashArray: [4, 4]),
                    HorizontalLine(y: -80, color: AppColors.gridLine, strokeWidth: 0.8, dashArray: [4, 4]),
                  ],
                ),
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDmiChart(List<DmiData> data) {
    if (data.isEmpty) return const Center(child: Text('数据不足'));
    final displayData = data.length > 100 ? data.sublist(data.length - 100) : data;

    // 动态计算范围
    double minY = double.infinity, maxY = double.negativeInfinity;
    for (final d in displayData) {
      if (d.pdi < minY) minY = d.pdi;
      if (d.pdi > maxY) maxY = d.pdi;
      if (d.mdi < minY) minY = d.mdi;
      if (d.mdi > maxY) maxY = d.mdi;
      if (d.adx < minY) minY = d.adx;
      if (d.adx > maxY) maxY = d.adx;
    }
    final pad = (maxY - minY) * 0.15;
    minY = minY - pad;
    maxY = maxY + pad;

    return Container(
      margin: const EdgeInsets.only(left: 36, right: 8, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.chartBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: constraints.maxHeight,
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.pdi)).toList(),
                    color: AppColors.pdiColor ?? AppColors.primary,
                    barWidth: 1.5,
                  ),
                  LineChartBarData(
                    spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.mdi)).toList(),
                    color: AppColors.mdiColor ?? AppColors.bearish,
                    barWidth: 1.5,
                  ),
                  LineChartBarData(
                    spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.adx)).toList(),
                    color: AppColors.adxColor ?? AppColors.textSecondary,
                    barWidth: 1.5,
                  ),
                ],
                minY: minY,
                maxY: maxY,
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(y: 0, color: AppColors.gridLine, strokeWidth: 0.8, dashArray: [4, 4]),
                  ],
                ),
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStockDetails(StockLoaded state) {
    final quotes = state.stockData.quotes;
    if (quotes.length < 2) return const SizedBox.shrink();
    final q = quotes.last;
    final prevQ = quotes[quotes.length - 2];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
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
          const SizedBox(height: 8),
          Row(
            children: [
              _buildDetailItem('收盘', q.close.toStringAsFixed(2)),
              _buildDetailItem('成交额', _formatTurnover(q)),
              _buildDetailItem('昨收', prevQ.close.toStringAsFixed(2)),
              _buildDetailItem('涨跌额', '${q.close >= prevQ.close ? '+' : ''}${(q.close - prevQ.close).toStringAsFixed(2)}'),
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

  String _formatTurnover(StockQuote q) {
    final turnover = q.close * q.volume;
    if (turnover >= 100000000) {
      return '${(turnover / 100000000).toStringAsFixed(2)}亿';
    } else if (turnover >= 10000) {
      return '${(turnover / 10000).toStringAsFixed(2)}万';
    }
    return turnover.toStringAsFixed(0);
  }

  void _searchStock() {
    final code = _searchController.text.trim().toUpperCase();
    if (code.isNotEmpty) {
      context.read<StockBloc>().add(LoadStock(code));
    }
  }
}
