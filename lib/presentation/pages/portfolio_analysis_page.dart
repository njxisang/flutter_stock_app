import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../data/datasources/stock_api_service.dart';
import '../../domain/entities/stock_quote.dart';
import '../blocs/watchlist/watchlist_cubit.dart';

class PortfolioAnalysisPage extends StatefulWidget {
  const PortfolioAnalysisPage({super.key});

  @override
  State<PortfolioAnalysisPage> createState() => _PortfolioAnalysisPageState();
}

class _SearchResult {
  final String symbol;
  final String name;
  final String market;

  const _SearchResult({required this.symbol, required this.name, required this.market});
}

class _PortfolioAnalysisPageState extends State<PortfolioAnalysisPage> {
  Map<String, StockData> _stockDataMap = {};
  bool _loading = false;
  final _searchController = TextEditingController();
  List<_SearchResult> _searchResults = [];
  bool _searchLoading = false;
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('组合分析'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: BlocBuilder<WatchlistCubit, WatchlistState>(
        builder: (context, state) {
          // 搜索栏（始终显示）
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索股票代码或名称添加...',
                    hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: AppColors.textSecondary, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchResults = [];
                                _isSearching = false;
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 14),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _searchStocks(),
                ),
              ),
              // 搜索结果列表
              if (_isSearching)
                _searchLoading
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: SizedBox(height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : _searchResults.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('未找到相关股票', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          )
                        : ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final r = _searchResults[index];
                                final alreadyAdded = state.items.any((item) => item.symbol == r.symbol);
                                return ListTile(
                                  dense: true,
                                  title: Text(r.name, style: const TextStyle(fontSize: 13)),
                                  subtitle: Text('${r.symbol} · ${r.market}', style: const TextStyle(fontSize: 11)),
                                  trailing: alreadyAdded
                                      ? const Icon(Icons.check, color: AppColors.success, size: 18)
                                      : IconButton(
                                          icon: const Icon(Icons.add_circle_outline, size: 20),
                                          color: AppColors.primary,
                                          onPressed: () => _addStock(r.symbol, r.name),
                                        ),
                                );
                              },
                            ),
                          ),
              // 主内容区
              Expanded(
                child: state.items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.pie_chart_outline, size: 64, color: AppColors.textSecondary),
                            const SizedBox(height: 16),
                            const Text('自选股为空', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            const Text('至少需要2只股票进行组合分析', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            Text('在上方搜索框添加股票', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : state.items.length < 2
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.pie_chart_outline, size: 64, color: AppColors.textSecondary),
                                const SizedBox(height: 16),
                                const Text('至少需要2只股票', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () => context.go('/'),
                                  child: const Text('去添加'),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_stockDataMap.isEmpty && !_loading)
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _loadAllStockData(context, state),
                                      icon: const Icon(Icons.refresh),
                                      label: Text('加载${state.items.length}只股票数据'),
                                    ),
                                  ),
                                if (_loading) const Center(child: CircularProgressIndicator()),
                                const SizedBox(height: 12),
                                if (_stockDataMap.isNotEmpty) ...[
                                  _buildSummaryCard(state),
                                  const SizedBox(height: 12),
                                  _buildPerformanceCard(state),
                                  const SizedBox(height: 12),
                                  if (_stockDataMap.length >= 2) ...[
                                    _buildCorrelationMatrix(state),
                                    const SizedBox(height: 12),
                                    _buildPortfolioMetrics(state),
                                    const SizedBox(height: 12),
                                    _buildSuggestions(state),
                                  ],
                                ],
                              ],
                            ),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(WatchlistState state) {
    final count = state.items.length;
    // Simple diversification score based on count
    final divScore = count >= 5 ? 85 : count >= 3 ? 65 : 50;
    final divColor = divScore >= 70 ? AppColors.success : divScore >= 50 ? AppColors.warning : AppColors.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryItem('股票数量', '$count', Colors.blue),
            _buildSummaryItem('多样化评分', '$divScore', divColor),
            _buildSummaryItem('风险等级', divScore >= 70 ? '低' : divScore >= 50 ? '中' : '高',
                divScore >= 70 ? AppColors.success : divScore >= 50 ? AppColors.warning : AppColors.error),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildPerformanceCard(WatchlistState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('个股表现', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            ...state.items.map((item) {
              final data = _stockDataMap[item.symbol];
              if (data == null || data.quotes.length < 2) {
                return ListTile(
                  dense: true,
                  title: Text(item.name),
                  subtitle: Text(item.symbol),
                  trailing: const Text('加载中...', style: TextStyle(color: AppColors.textSecondary)),
                );
              }
              final quotes = data.quotes;
              final first = quotes.first.close;
              final last = quotes.last.close;
              final change = (last - first) / first * 100;
              final color = change >= 0 ? AppColors.success : AppColors.error;
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withAlpha(25),
                  child: Text(item.symbol.substring(0, item.symbol.length > 2 ? 2 : item.symbol.length), style: TextStyle(fontSize: 11, color: color)),
                ),
                title: Text(item.name, style: const TextStyle(fontSize: 13)),
                subtitle: Text(item.symbol, style: const TextStyle(fontSize: 11)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(last.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%', style: TextStyle(color: color, fontSize: 12)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCorrelationMatrix(WatchlistState state) {
    final symbols = state.items.map((i) => i.symbol).toList();
    final n = symbols.length;
    final matrix = List.generate(n, (i) => List.generate(n, (j) => 0.0));

    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        if (i == j) {
          matrix[i][j] = 1.0;
        } else {
          matrix[i][j] = _computeCorrelation(
            _stockDataMap[symbols[i]]?.quotes ?? [],
            _stockDataMap[symbols[j]]?.quotes ?? [],
          );
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('相关性矩阵', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 60),
                ...symbols.map((s) => Expanded(child: Center(child: Text(s.substring(0, min(4, s.length)), style: const TextStyle(fontSize: 10))))),
              ],
            ),
            ...List.generate(n, (i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(width: 60, child: Text(symbols[i].substring(0, min(4, symbols[i].length)), style: const TextStyle(fontSize: 10))),
                  ...List.generate(n, (j) => Expanded(child: _buildCorrelationCell(matrix[i][j]))),
                ],
              ),
            )),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendBox(AppColors.error, '正相关'),
                const SizedBox(width: 16),
                _legendBox(Colors.blue, '负相关'),
                const SizedBox(width: 16),
                _legendBox(AppColors.textPrimary, '无相关'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorrelationCell(double corr) {
    final color = corr > 0.3 ? AppColors.error.withAlpha((corr * 80).toInt().clamp(20, 200))
        : corr < -0.3 ? Colors.blue.withAlpha((corr.abs() * 80).toInt().clamp(20, 200))
        : AppColors.textSecondary.withAlpha(50);
    return Container(
      height: 36,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(child: Text(corr.toStringAsFixed(2), style: const TextStyle(fontSize: 10, color: AppColors.textPrimary))),
    );
  }

  Widget _legendBox(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildPortfolioMetrics(WatchlistState state) {
    // Compute portfolio expected return and risk
    final symbols = state.items.map((i) => i.symbol).toList();
    final returns = <double>[];
    for (final sym in symbols) {
      final quotes = _stockDataMap[sym]?.quotes;
      if (quotes != null && quotes.length >= 2) {
        final r = (quotes.last.close - quotes.first.close) / quotes.first.close;
        returns.add(r);
      }
    }
    if (returns.isEmpty) return const SizedBox.shrink();

    final avgReturn = returns.reduce((a, b) => a + b) / returns.length * 100;
    final variance = returns.map((r) => pow(r - avgReturn / 100, 2)).reduce((a, b) => a + b) / returns.length;
    final stdDev = sqrt(variance) * 100;
    final sharpe = stdDev > 0 ? (avgReturn - 4) / stdDev : 0.0; // 4% risk-free

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('组合预期指标', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricCard('预期收益', '${avgReturn >= 0 ? '+' : ''}${avgReturn.toStringAsFixed(1)}%', avgReturn >= 0 ? AppColors.success : AppColors.error),
                _buildMetricCard('预期风险', '${stdDev.toStringAsFixed(1)}%', AppColors.warning),
                _buildMetricCard('夏普比率', sharpe.toStringAsFixed(2), sharpe >= 0 ? AppColors.success : AppColors.error),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildSuggestions(WatchlistState state) {
    final symbols = state.items.map((i) => i.symbol).toList();
    final suggestions = <String>[];

    // Check correlation
    for (var i = 0; i < symbols.length; i++) {
      for (var j = i + 1; j < symbols.length; j++) {
        final corr = _computeCorrelation(
          _stockDataMap[symbols[i]]?.quotes ?? [],
          _stockDataMap[symbols[j]]?.quotes ?? [],
        );
        if (corr > 0.8) {
          suggestions.add('${state.items[i].name}和${state.items[j].name}相关性过高(${corr.toStringAsFixed(2)})，建议保留其一');
        }
      }
    }

    if (symbols.length < 5) {
      suggestions.add('组合股票数量较少，建议增加至5只以上以分散非系统性风险');
    }

    if (suggestions.isEmpty) {
      suggestions.add('组合整体相关性适中，风险分散效果良好');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('优化建议', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            ...suggestions.map((s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s, style: const TextStyle(fontSize: 13))),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  double _computeCorrelation(List<StockQuote> a, List<StockQuote> b) {
    if (a.length < 5 || b.length < 5) return 0.0;
    final minLen = a.length < b.length ? a.length : b.length;
    final returnsA = <double>[];
    final returnsB = <double>[];
    for (var i = 1; i < minLen; i++) {
      returnsA.add((a[i].close - a[i - 1].close) / a[i - 1].close);
      returnsB.add((b[i].close - b[i - 1].close) / b[i - 1].close);
    }
    if (returnsA.length < 3) return 0.0;
    final meanA = returnsA.reduce((x, y) => x + y) / returnsA.length;
    final meanB = returnsB.reduce((x, y) => x + y) / returnsB.length;
    var num = 0.0, denA = 0.0, denB = 0.0;
    for (var i = 0; i < returnsA.length; i++) {
      num += (returnsA[i] - meanA) * (returnsB[i] - meanB);
      denA += pow(returnsA[i] - meanA, 2);
      denB += pow(returnsB[i] - meanB, 2);
    }
    final den = sqrt(denA * denB);
    return den > 0 ? (num / den).clamp(-1.0, 1.0) : 0.0;
  }

  Future<void> _loadAllStockData(BuildContext context, WatchlistState state) async {
    setState(() => _loading = true);
    final apiService = StockApiService();
    final Map<String, StockData> loaded = {};

    for (final item in state.items) {
      try {
        final data = await apiService.getStockData(item.symbol);
        loaded[item.symbol] = data;
      } catch (e) {
        // skip failed stocks silently
      }
    }

    if (mounted) {
      setState(() {
        _stockDataMap = loaded;
        _loading = false;
      });
    }
  }

  Future<void> _searchStocks() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searchLoading = true;
      _isSearching = true;
      _searchResults = [];
    });

    try {
      final types = ['14', '5', '16', '28', '7'];
      final results = <_SearchResult>[];

      for (final type in types) {
        if (results.isNotEmpty) break;
        try {
          final url = 'https://searchapi.eastmoney.com/api/suggest/get?input=$query&type=$type&count=5';
          final response = await http.get(
            Uri.parse(url),
            headers: {'User-Agent': 'Mozilla/5.0', 'Referer': 'https://quote.eastmoney.com/'},
          );
          if (response.statusCode == 200) {
            final json = jsonDecode(response.body) as Map<String, dynamic>;
            final table = json['QuotationCodeTable'] as Map<String, dynamic>?;
            final data = table?['Data'] as List<dynamic>?;
            if (data != null && data.isNotEmpty) {
              for (final item in data) {
                final mkt = _marketLabel(item['MktNum']?.toString() ?? '');
                results.add(_SearchResult(
                  symbol: item['Code']?.toString() ?? '',
                  name: item['Name']?.toString() ?? '',
                  market: mkt,
                ));
              }
            }
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
          _searchLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _searchLoading = false);
      }
    }
  }

  String _marketLabel(String mktNum) {
    return switch (mktNum) {
      '1' => '上交所',
      '2' => '深交所',
      '5' => '北交所',
      _ => '未知',
    };
  }

  Future<void> _addStock(String symbol, String name) async {
    context.read<WatchlistCubit>().addToWatchlist(symbol, name);
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _isSearching = false;
    });
  }
}
