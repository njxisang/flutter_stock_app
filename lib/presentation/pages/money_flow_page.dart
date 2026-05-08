import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_constants.dart';
import '../../data/datasources/lhb_api_service.dart';
import '../../data/datasources/fund_flow_api_service.dart';
import '../../data/datasources/seat_history_service.dart';
import '../../domain/entities/stock_quote.dart';
import '../blocs/seat_tracker/seat_tracker_cubit.dart';

/// 资金/龙虎榜/席位追踪页面
class MoneyFlowPage extends StatefulWidget {
  const MoneyFlowPage({super.key});

  @override
  State<MoneyFlowPage> createState() => _MoneyFlowPageState();
}

class _MoneyFlowPageState extends State<MoneyFlowPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _seatSearchController = TextEditingController();
  final _lhbApi = LhbApiService();
  final _fundFlowApi = FundFlowApiService();

  // 龙虎榜数据
  List<LhbEntry> _lhbList = [];
  bool _lhbLoading = false;
  String _lhbDate = '';
  LhbSummaryModel? _lhbSummary; // 龙虎榜日报摘要

  // 资金流向数据
  MoneyFlowData? _moneyFlowData;
  Map<String, double> _realtimeFlow = {};
  bool _flowLoading = false;
  String _flowSymbol = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLhb();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _seatSearchController.dispose();
    super.dispose();
  }

  // ============ 龙虎榜 ============

  Future<void> _loadLhb({String? date}) async {
    setState(() {
      _lhbLoading = true;
      _lhbDate = date ?? _todayStr();
      _lhbSummary = null; // 清空旧摘要
    });

    try {
      // 列表数据和日报摘要并行拉取
      final results = await Future.wait([
        _lhbApi.getLhbData(date: _lhbDate),
        _lhbApi.getLhbSeatRaw(date: _lhbDate),
      ]);
      final list = results[0] as List<LhbEntry>;
      final rawEntries = results[1] as List<LhbSeatRawEntry>;

      // 构建日报摘要（新建仓判断依赖历史 last_seen，传入空map则不判断新建仓）
      final summary = LhbSummaryService.build(
        date: _lhbDate,
        entries: rawEntries,
        prevLastSeen: const {},
      );

      if (mounted) {
        setState(() {
          _lhbList = list;
          _lhbSummary = summary;
          _lhbLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _lhbLoading = false);
    }
  }

  // ============ 资金流向 ============

  Future<void> _loadFundFlow(String symbol) async {
    if (symbol.isEmpty) return;
    setState(() {
      _flowLoading = true;
      _flowSymbol = symbol;
    });

    try {
      final data = await _fundFlowApi.getStockFundFlow(symbol);
      final realtime = await _fundFlowApi.getFundFlowRealtime(symbol);
      if (mounted) {
        setState(() {
          _moneyFlowData = data;
          _realtimeFlow = realtime;
          _flowLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _flowLoading = false);
    }
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SeatTrackerCubit(
        historyService: context.read<SeatHistoryService>(),
        lhbApiService: _lhbApi,
      )..loadSeats(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          title: const Text('资金与龙虎榜', style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_today, color: AppColors.textSecondary, size: 20),
              onPressed: _showDatePicker,
            ),
          ],
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            _buildTabBar(),
            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: '输入股票代码查资金流向',
                  hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: AppColors.textSecondary, size: 18),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 9),
                ),
                style: const TextStyle(fontSize: 14),
                onSubmitted: (_) => _loadFundFlow(_searchController.text.trim()),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _loadFundFlow(_searchController.text.trim()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('查询', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(color: AppColors.surface,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 14),
        tabs: const [
          Tab(text: '龙虎榜'),
          Tab(text: '资金流向'),
          Tab(text: '席位追踪'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildLhbTab(),
        _buildFlowTab(),
        _buildSeatTab(),
      ],
    );
  }

  // ============ 龙虎榜 Tab ============

  Widget _buildLhbTab() {
    if (_lhbLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_lhbList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.list_alt, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 8),
            Text('龙虎榜暂无数据 (${_lhbDate})', style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextButton(onPressed: () => _loadLhb(), child: const Text('刷新')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadLhb(),
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8),
        itemCount: _lhbList.length + 1, // +1 for summary header
        itemBuilder: (context, index) {
          // 0: 日报摘要头
          if (index == 0) {
            return _buildLhbSummaryHeader(_lhbSummary, _lhbDate);
          }
          final item = _lhbList[index - 1];
          final changePct = double.tryParse(item.changePercent) ?? 0;
          final isUp = changePct >= 0;
          final pctColor = isUp ? AppColors.bullish : AppColors.bearish;

          return GestureDetector(
            onTap: () => _showLhbDetail(item),
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border.withAlpha(77)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                        ),
                      ),
                      Text(item.symbol, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: pctColor.withAlpha(25), borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          '${isUp ? '+' : ''}${changePct.toStringAsFixed(2)}%',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: pctColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(item.reason, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildLhbChip('买一', item.buyMaxSeat),
                      const SizedBox(width: 6),
                      _buildLhbChip('卖一', item.sellMaxSeat),
                      const Spacer(),
                      Text(
                        '买 ${(item.buyAmount / 10000).toStringAsFixed(1)}亿  卖 ${(item.sellAmount / 10000).toStringAsFixed(1)}亿',
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLhbChip(String label, String seat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: AppColors.primary.withAlpha(15), borderRadius: BorderRadius.circular(4)),
      child: Text('$label:${_shortSeat(seat)}', style: const TextStyle(fontSize: 10, color: AppColors.primary)),
    );
  }

  // ============ 龙虎榜日报摘要 ============

  Widget _buildLhbSummaryHeader(LhbSummaryModel? summary, String date) {
    if (summary == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                const Icon(Icons.assessment, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  '📊 龙虎榜日报 · $date',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${summary.totalStocks}只',
                    style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 概览行
                _buildSummaryOverview(summary),
                const SizedBox(height: 10),

                // 涨幅榜
                if (summary.topGainers.isNotEmpty) ...[
                  _buildSummarySectionHeader('🔥', '涨幅榜 TOP${summary.topGainers.length}'),
                  const SizedBox(height: 4),
                  ...summary.topGainers.map((s) => _buildRankRow(s, isUp: true)),
                  const SizedBox(height: 10),
                ],

                // 跌幅榜
                if (summary.topLosers.isNotEmpty) ...[
                  _buildSummarySectionHeader('📉', '跌幅榜 TOP${summary.topLosers.length}'),
                  const SizedBox(height: 4),
                  ...summary.topLosers.map((s) => _buildRankRow(s, isUp: false)),
                  const SizedBox(height: 10),
                ],

                // 席位类型流向
                if (summary.seatTypeSummary.isNotEmpty) ...[
                  _buildSummarySectionHeader('💰', '席位资金流向'),
                  const SizedBox(height: 4),
                  ...summary.seatTypeSummary.map((s) => _buildSeatTypeRow(s)),
                  const SizedBox(height: 10),
                ],

                // 新建仓
                if (summary.newPositions.isNotEmpty) ...[
                  _buildSummarySectionHeader('⭐', '重点关注 · ${summary.newPositions.length}只新建仓'),
                  const SizedBox(height: 4),
                  ...summary.newPositions.map((s) => _buildNewPositionRow(s)),
                ],

                if (summary.topGainers.isEmpty && summary.topLosers.isEmpty && summary.seatTypeSummary.isEmpty) ...[
                  const Center(child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('暂无龙虎榜席位数据', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryOverview(LhbSummaryModel summary) {
    return Row(
      children: [
        _buildOverviewChip('📈 涨', summary.upCount.toString(), AppColors.bullish),
        const SizedBox(width: 8),
        _buildOverviewChip('📉 跌', summary.downCount.toString(), AppColors.bearish),
        const SizedBox(width: 8),
        _buildOverviewChip('📋 席位记录', '${summary.totalEntries}条', AppColors.textSecondary),
      ],
    );
  }

  Widget _buildOverviewChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color)),
          const SizedBox(width: 3),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildSummarySectionHeader(String emoji, String title) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildRankRow(LhbStockRank s, {required bool isUp}) {
    final arrow = s.totalNet >= 0 ? '🟢' : '🔴';
    final color = isUp ? AppColors.bullish : AppColors.bearish;
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              s.changeDisplay,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          ),
          Expanded(
            child: Text(
              '${s.name}(${s.code})',
              style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$arrow ${s.netDisplay}',
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 6),
          if (s.topBuySeat.isNotEmpty)
            Text(
              '买一 ${_shortSeatName(s.topBuySeat)}',
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _buildSeatTypeRow(SeatTypeSummary s) {
    final isPositive = s.totalNet >= 0;
    final color = isPositive ? AppColors.bullish : AppColors.bearish;
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(
        children: [
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              s.typeName,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '买${s.buyDisplay} / 卖${s.sellDisplay}',
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ),
          Text(
            '净买${s.netDisplay}',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildNewPositionRow(LhbStockRank s) {
    final color = AppColors.bullish;
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        children: [
          const Text('🆕', style: TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${s.name}(${s.code}) ${s.changeDisplay}',
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '净买${s.netDisplay}  [${_shortSeatName(s.seat ?? s.topBuySeat)}]',
            style: TextStyle(fontSize: 10, color: color),
          ),
        ],
      ),
    );
  }

  String _shortSeat(String seat) {
    return seat.length <= 8 ? seat : '${seat.substring(0, 6)}...';
  }

  void _showLhbDetail(LhbEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(color: AppColors.cardBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(margin: const EdgeInsets.only(top: 12), width: 36, height: 4, decoration: BoxDecoration(color: AppColors.textTertiary, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(entry.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text(entry.symbol, style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _detailRow('上榜原因', entry.reason),
                    _detailRow('交易日期', entry.date),
                    _detailRow('收盘价', entry.closePrice),
                    _detailRow('涨跌幅', '${entry.changePercent}%'),
                    _detailRow('买入总额', '${(entry.buyAmount / 10000).toStringAsFixed(2)}亿'),
                    _detailRow('卖出总额', '${(entry.sellAmount / 10000).toStringAsFixed(2)}亿'),
                    const Divider(),
                    const Text('买入席位', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    _detailRow('买一', entry.buyMaxSeat),
                    const SizedBox(height: 12),
                    const Text('卖出席位', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    _detailRow('卖一', entry.sellMaxSeat),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  // ============ 资金流向 Tab ============

  Widget _buildFlowTab() {
    if (_flowLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_moneyFlowData == null || _moneyFlowData!.flows.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.show_chart, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 8),
            const Text('输入股票代码查询资金流向', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    final flows = _moneyFlowData!.flows;
    final netInflow = _realtimeFlow['netInflowMain'] ?? 0.0;
    final turnover = _realtimeFlow['turnoverRate'] ?? 0.0;
    final isPositive = netInflow >= 0;
    final pctColor = isPositive ? AppColors.bullish : AppColors.bearish;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 实时大单指标卡
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border.withAlpha(77)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(_moneyFlowData!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(_flowSymbol, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _flowMetricCard('主力净流入', '${isPositive ? '+' : ''}${(netInflow / 10000).toStringAsFixed(2)}亿', pctColor)),
                    const SizedBox(width: 10),
                    Expanded(child: _flowMetricCard('换手率', '${turnover.toStringAsFixed(2)}%', AppColors.primary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 净流入折线图
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('近30日净流入（万元）', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                SizedBox(height: 200, child: _buildFlowChart(flows.take(30).toList().reversed.toList())),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 最近10日明细
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border.withAlpha(77)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('近10日明细', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                ...flows.take(10).map((f) => _flowDetailRow(f)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _flowMetricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withAlpha(15), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildFlowChart(List<CapitalFlow> flows) {
    if (flows.isEmpty) return const SizedBox();
    final spots = flows.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.netInflow / 10000)).toList();

    // 分离正负数据用于渐变填充
    final belowSpots = spots.map((s) => FlSpot(s.x, s.y < 0 ? s.y : 0.0)).toList();
    final aboveSpots = spots.map((s) => FlSpot(s.x, s.y >= 0 ? s.y : 0.0)).toList();

    return LineChart(
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
              reservedSize: 48,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: const TextStyle(fontSize: 10, color: AppColors.axisLabel),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= flows.length) return const SizedBox();
                final parts = flows[idx].date.split('-');
                return Text(
                  '${parts[1]}/${parts[2]}',
                  style: const TextStyle(fontSize: 9, color: AppColors.axisLabel),
                );
              },
              interval: (flows.length / 5).ceilToDouble().clamp(1, 10),
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          // 负值区域（流出）
          LineChartBarData(
            spots: belowSpots,
            isCurved: true,
            color: AppColors.bearish,
            barWidth: 1.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.bearish.withAlpha(30),
              cutOffY: 0.0,
              applyCutOffY: true,
            ),
          ),
          // 正值区域（流入）
          LineChartBarData(
            spots: aboveSpots,
            isCurved: true,
            color: AppColors.bullish,
            barWidth: 1.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.bullish.withAlpha(30),
              cutOffY: 0.0,
              applyCutOffY: true,
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
              final isUp = s.y >= 0;
              return LineTooltipItem(
                '${isUp ? '+' : ''}${s.y.toStringAsFixed(2)}万',
                TextStyle(
                  color: isUp ? AppColors.bullish : AppColors.bearish,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList(),
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 0,
              color: AppColors.gridLineStrong,
              strokeWidth: 0.8,
            ),
          ],
        ),
      ),
    );
  }

  Widget _flowDetailRow(CapitalFlow f) {
    final isPositive = f.netInflow >= 0;
    final color = isPositive ? AppColors.bullish : AppColors.bearish;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(f.date, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '流入 ${(f.bigDealIn / 10000).toStringAsFixed(1)}万  流出 ${(f.bigDealOut / 10000).toStringAsFixed(1)}万',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
          Text(
            '${isPositive ? '+' : ''}${(f.netInflow / 10000).toStringAsFixed(1)}万',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  // ============ 席位追踪 Tab ============

  Widget _buildSeatTab() {
    return BlocBuilder<SeatTrackerCubit, SeatTrackerState>(
      builder: (context, state) {
        return Column(
          children: [
            // 席位选择 + 刷新行
            Container(color: AppColors.surface,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: state.trackedSeats.map((seat) {
                              final isSelected = seat == state.selectedSeat;
                              return GestureDetector(
                                onTap: () => context.read<SeatTrackerCubit>().selectSeat(seat),
                                onLongPress: () => _showSeatOptions(context, seat),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary : AppColors.background,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Text(
                                    _shortSeatName(seat),
                                    style: TextStyle(fontSize: 12, color: isSelected ? AppColors.textPrimary : AppColors.textSecondary),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 22, color: AppColors.primary),
                        onPressed: () => _showAddSeatDialog(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (state.lastUpdateTime != null)
                        Text('更新: ${state.lastUpdateTime!}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      const Spacer(),
                      SizedBox(
                        height: 32,
                        child: ElevatedButton.icon(
                          onPressed: state.isLoading
                              ? null
                              : () => context.read<SeatTrackerCubit>().refreshToday(),
                          icon: state.isLoading
                              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                              : const Icon(Icons.refresh, size: 14),
                          label: Text(state.isLoading ? '刷新中...' : '刷新今日', style: const TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 新建仓提醒
            if (state.selectedSeat != null && (state.newPositions[state.selectedSeat]?.isNotEmpty ?? false))
              _buildNewPositionAlert(context, state),

            // 选中席位的统计信息
            if (state.selectedSeat != null && state.seatStats[state.selectedSeat] != null)
              _buildStatsCards(state.seatStats[state.selectedSeat]!),

            // 操作历史列表
            Expanded(
              child: state.selectedSeat == null
                  ? const Center(child: Text('请选择要追踪的席位', style: TextStyle(color: AppColors.textSecondary)))
                  : _buildSeatHistoryList(context, state),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNewPositionAlert(BuildContext context, SeatTrackerState state) {
    final newPos = state.newPositions[state.selectedSeat]!;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bullish.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.bullish.withAlpha(77)),
      ),
      child: Row(
        children: [
          Icon(Icons.celebration, color: AppColors.bullish, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('今日新建仓 ${newPos.length} 只', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.bullish)),
                const SizedBox(height: 2),
                Text(newPos.map((p) => '${p.name}(${(p.netAmount / 10000).toStringAsFixed(2)}亿)').join(' / '),
                  style: TextStyle(fontSize: 11, color: AppColors.bullish.withAlpha(204)),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(SeatStats stats) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // 第一行统计卡
          Row(
            children: [
              Expanded(child: _statCard('累计交易', '${stats.totalTrades}只', Icons.bar_chart)),
              const SizedBox(width: 8),
              Expanded(child: _statCard('偏好板块', stats.favoriteSector, Icons.pie_chart)),
              const SizedBox(width: 8),
              Expanded(child: _statCard('平均持仓', '${stats.avgHoldingDays}天', Icons.schedule)),
            ],
          ),
          const SizedBox(height: 8),
          // 第二行统计卡
          Row(
            children: [
              Expanded(
                child: _statCard(
                  '历史净买入',
                  '${(stats.netAmount / 10000).toStringAsFixed(1)}亿',
                  stats.netAmount >= 0 ? Icons.trending_up : Icons.trending_down,
                  color: stats.netAmount >= 0 ? AppColors.bullish : AppColors.bearish,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                  '胜率估算',
                  '${(stats.winRate * 100).toStringAsFixed(0)}%',
                  Icons.check_circle_outline,
                  color: stats.winRate >= 0.5 ? AppColors.bullish : AppColors.bearish,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _statCard('历史买入', '${(stats.totalBuyAmount / 10000).toStringAsFixed(1)}亿', Icons.arrow_upward)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, {Color? color}) {
    final c = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: c),
              const SizedBox(width: 4),
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildSeatHistoryList(BuildContext context, SeatTrackerState state) {
    final history = state.seatHistory[state.selectedSeat] ?? [];
    final stats = state.seatStats[state.selectedSeat];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        // 持仓股票汇总
        if (stats != null && stats.stocks.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('持仓股票', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
          ),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: stats.stocks.length.clamp(0, 10),
              itemBuilder: (context, idx) {
                final s = stats.stocks[idx];
                final isPositive = s.totalNet >= 0;
                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border.withAlpha(77)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(s.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(s.symbol, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      Text(
                        '${isPositive ? '+' : ''}${(s.totalNet / 10000).toStringAsFixed(1)}亿',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isPositive ? AppColors.bullish : AppColors.bearish),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],

        // 操作历史
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('操作历史', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
        ),
        ...history.map((op) => _buildHistoryItem(op)),
        if (history.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: Text('暂无操作记录，点击刷新获取今日数据', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
          ),
      ],
    );
  }

  Widget _buildHistoryItem(SeatOperation op) {
    final isBuy = op.isBuy;
    final color = isBuy ? AppColors.bullish : AppColors.bearish;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withAlpha(77)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(op.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(op.symbol, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withAlpha(25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isBuy ? '买入' : '卖出',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('买 ${(op.buyAmount / 10000).toStringAsFixed(1)}亿', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(width: 12),
                    Text('卖 ${(op.sellAmount / 10000).toStringAsFixed(1)}亿', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const Spacer(),
                    Text(
                      '${isBuy ? '+' : ''}${(op.netAmount / 10000).toStringAsFixed(1)}亿',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(op.date, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  String _shortSeatName(String seat) {
    if (seat.contains('溧阳路')) return '溧阳路';
    if (seat.contains('太平南路')) return '太平南路';
    if (seat.contains('解放北路')) return '解放路';
    if (seat.contains('作手余哥')) return '余哥';
    if (seat.contains('小鳄鱼')) return '小鳄鱼';
    if (seat.contains('佛山')) return '佛山';
    if (seat.contains('成都')) return '成都';
    if (seat.contains('长江路')) return '长江路';
    if (seat.contains('机构专用')) return '机构';
    if (seat.contains('高盛')) return '高盛';
    if (seat.contains('摩根大通')) return '摩根';
    if (seat.contains('瑞银')) return '瑞银';
    if (seat.contains('中金上海')) return '中金上海';
    if (seat.contains('中金北京')) return '中金北京';
    if (seat.contains('沪股通')) return '沪股通';
    if (seat.contains('深股通')) return '深股通';
    if (seat.contains('国泰海通证券总部')) return '国泰总部';
    if (seat.contains('中信证券上海分公司')) return '中信上海';
    if (seat.contains('国盛证券宁波桑田')) return '桑田路';
    if (seat.contains('华泰证券深圳益田路荣超')) return '华泰益田';
    if (seat.contains('华鑫证券上海宛平')) return '华鑫宛平';
    if (seat.contains('华泰证券苏州吴中')) return '华泰吴中';
    if (seat.contains('开源证券西安太华')) return '开源太华';
    if (seat.contains('国信证券深圳红岭')) return '国信红岭';
    if (seat.contains('中信建投证券上海营口')) return '建投营口';
    if (seat.contains('招商证券深圳益田路')) return '招商益田';
    if (seat.contains('中国银河证券宜昌新世纪')) return '银河宜昌';
    if (seat.contains('平安证券杭州曙光')) return '平安曙光';
    if (seat.contains('东亚前海证券深圳')) return '东亚深圳';
    if (seat.contains('国泰海通证券上海')) return '国泰上海';
    if (seat.contains('国泰海通证券成都北一环路')) return '国泰成都';
    return seat.length > 6 ? '${seat.substring(0, 5)}...' : seat;
  }

  void _showAddSeatDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加追踪席位'),
        content: TextField(
          controller: _seatSearchController,
          decoration: const InputDecoration(
            hintText: '输入席位名称',
            hintStyle: TextStyle(fontSize: 13),
            border: OutlineInputBorder(),
          ),
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _seatSearchController.text.trim();
              if (name.isNotEmpty) {
                context.read<SeatTrackerCubit>().addSeat(name);
                _seatSearchController.clear();
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showSeatOptions(BuildContext context, String seat) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.bearish),
              title: const Text('移除席位'),
              onTap: () {
                context.read<SeatTrackerCubit>().removeSeat(seat);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============ 日期选择 ============

  void _showDatePicker() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: Colors.white,
        )),
        child: child!,
      ),
    );
    if (picked != null) {
      final dateStr = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      _loadLhb(date: dateStr);
    }
  }
}
