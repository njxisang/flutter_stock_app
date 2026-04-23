# Flutter Stock App 代码审查报告

**审查日期**: 2026-04-23
**项目路径**: `/home/xisang/flutter_stock_app`
**审查范围**: 全项目代码审查（不包含代码修改）

---

## 项目概览

| 项目 | 信息 |
|------|------|
| 架构 | Clean Architecture (data/domain/presentation) |
| 状态管理 | flutter_bloc (StockBloc, ChartCubit, WatchlistCubit) |
| 导航 | go_router + ShellRoute |
| 图表 | fl_chart + CustomPainter(K线) |
| 数据源 | 东方财富(主) → 腾讯(备) → Yahoo Finance(美股) |
| 本地存储 | SharedPreferences |
| 技术栈 | Flutter 3.24.0, Dart 3.5.0 |
| 主要页面 | MainPage(K线), WatchlistPage, HistoryPage, BacktestPage, AnalysisPage |

---

## 一、严重Bug (Critical)

### 1.1 MainPage Tab状态同步问题 🔴

**位置**: `lib/presentation/pages/main_page.dart:106-108`

```dart
onTap: () {
  setState(() => _currentTabIndex = index);  // 本地状态
  context.read<ChartCubit>().changeTab(index);  // 全局状态
}
```

**问题**:
- `_currentTabIndex` 是 `MainPage` 的本地 `State`，每次 widget rebuild 时不会保持
- `ChartCubit.currentTab` 是全局状态，但实际 UI 渲染依赖的是 `_currentTabIndex`
- 从其他页面返回时，`_currentTabIndex` 重置为 0，但 `ChartCubit` 保持原值
- Line 202 只读 `_currentTabIndex == 1`，实际从不使用 `ChartCubit.currentTab`

**现象**: 从分析页返回K线页，Tab指示器可能显示K线但实际渲染了MACD图

**修复方向**: 统一使用 `ChartCubit.currentTab`，删除本地 `_currentTabIndex`

---

### 1.2 路由导航方式错误 🔴

**位置**: `lib/presentation/pages/analysis_page.dart:276`

```dart
Navigator.of(context).pushNamed(route);  // 使用Navigator.pushNamed
```

**问题**: App 使用 `go_router` 作为路由方案，`Navigator.pushNamed` 无法匹配 go_router 定义的路由表

**影响**: 点击"信号分析/风险分析/价格预测/海龟交易/组合分析"等按钮导航失败

**修复方向**: 改用 `context.go(route)` 或 `context.push(route)`

---

### 1.3 回测DMI策略未实现 🔴

**位置**: `lib/domain/usecases/calculators/backtest_calculator.dart:254-258`

```dart
static Map<String, dynamic>? _dmiSignal(List<StockQuote> quotes) {
  // 简化版DMI信号
  if (quotes.length < 14) return null;
  return null;  // 直接返回null，没有实现
}
```

**问题**: DMI 回测永远无信号，用户选择 DMI 策略实际等同于空仓

---

### 1.4 Settings按钮未实现 🔴

**位置**: `lib/presentation/pages/main_page.dart:38`

```dart
IconButton(
  icon: const Icon(Icons.add),
  onPressed: () => _showSettingsDialog(context),  // 方法从未定义
)
```

**问题**: 点击设置按钮会崩溃，`_showSettingsDialog` 方法不存在

---

### 1.5 自选股无实时价格刷新 🔴

**位置**: `lib/presentation/blocs/watchlist/watchlist_cubit.dart` + `stock_local_storage.dart`

**问题**:
- 自选股列表只存了 symbol 和 name，不存价格/涨跌
- 每次打开自选页需要重新拉取数据
- 没有批量刷新机制，所有股票串行请求
- 没有离线展示能力

**修复方向**: 添加批量 API 请求能力，或至少缓存上次价格

---

## 二、性能问题 (Performance)

### 2.1 指标重复计算 ⚠️

**位置**: `lib/presentation/pages/main_page.dart:265-268`

```dart
final ma5 = _computeMa(displayQuotes, 5);      // 页面内重新计算
final ma10 = _computeMa(displayQuotes, 10);
final ma20 = _computeMa(displayQuotes, 20);
```

**问题**:
- `StockBloc._onLoadStock` 里已经调用过 `MaCalculator.calculate(quotes)`
- 又在 MainPage 页面里重复计算一次 MA
- 每个指标计算器在 BLoC 层算一遍，页面又算一遍
- `_computeMa` 方法本身就是 MA 计算的重复实现

**修复方向**: BLoC 层的 `StockLoaded` 状态已包含 `maData`，直接复用

---

### 2.2 K线图MA数组越界风险 ⚠️

**位置**: `lib/presentation/widgets/candle_chart_widget.dart:248`

```dart
final v = ma[start + i];  // MA数组索引可能越界
```

**问题**:
- `ma` 数组长度是 `quotes.length`
- 当 `startIdx > 0` 时，`ma[start + i]` 访问的索引 = `startIdx + i`
- 如果 `ma` 数组比 `quotes` 短（例如 MA20 的结果从 index 19 开始），会导致越界
- Line 280-294 的 `_computeMa` 也是从头开始填充 null，实际有效数据从 `period-1` 开始

**修复方向**: MA 数组应该以 quotes 索引对齐存储，或在 `_CandlePainter` 中做索引映射

---

### 2.3 所有指标串行同步计算 ⚠️

**位置**: `lib/presentation/blocs/stock/stock_bloc.dart:130-137`

```dart
final macdData = MacdCalculator.calculate(stockData.quotes);
final rsiData = RsiCalculator.calculate(stockData.quotes);
final kdjData = KdjCalculator.calculate(stockData.quotes);
final bollData = BollCalculator.calculate(stockData.quotes);
final maData = MaCalculator.calculate(stockData.quotes);
final wrData = WrCalculator.calculate(stockData.quotes);
final dmiData = DmiCalculator.calculate(stockData.quotes);
```

**问题**: 7个指标串行同步计算，数据量大时可能卡顿，无缓存机制

---

### 2.4 EMA实现重复 ⚠️

- `macd_calculator.dart:53-75` 有 `_calculateEma`
- `backtest_calculator.dart:286-300` 也有 `_ema`

两份实现略有差异（multiplier 公式写法一致，但变量命名不同），应统一

---

### 2.5 无数据缓存 ⚠️

**位置**: `lib/core/constants/app_constants.dart:87`

```dart
static const int cacheValidHours = 1;  // 定义了但从未使用
```

API 没有实现缓存，每次启动都重新请求

---

## 三、架构/代码质量 (Architecture)

### 3.1 违反依赖倒置原则 ⚠️

| 位置 | 问题 |
|------|------|
| `analysis_page.dart:348` | `bloc.apiService.getStockData('000001')` 直接访问 Bloc 内部服务 |
| `history_page.dart:23` | `context.read<StockBloc>().storage` 直接访问内部存储 |
| `watchlist_page.dart:89` | `context.read<StockBloc>().add(LoadStock(item.symbol))` 直接操作 Bloc |

**应该**: 通过 Repository 接口或独立 Service 获取

---

### 3.2 状态管理分散 ⚠️

| 数据 | 状态管理方式 |
|------|------------|
| 股票数据/指标 | StockBloc |
| 图表Tab | ChartCubit + MainPage 本地 State（混乱） |
| 自选股列表 | WatchlistCubit |
| 回测结果 | MainPage 本地 State `_result` |
| 搜索历史 | 直接读 `StockBloc.storage` |
| 指数对比数据 | AnalysisPage 本地 State `_indexData` |
| 日期范围 | StockBloc 内部字段 `_startDate/_endDate` |

**问题**: 状态分散，难以追踪和调试，部分状态重复存储

---

### 3.3 未使用的类型残留 ⚠️

**位置**: `lib/domain/entities/stock_quote.dart`

以下类型在 presentation 层未使用（可能是早期版本遗留）:
- `PricePrediction`
- `PredictionResult`
- `TurtleDetails`
- `FactorResult` (仅在 multi_factor_analyzer 内部使用)

---

### 3.4 Magic Numbers ⚠️

```dart
ChartConstants.maxChartPoints = 100     // 但实际 _defaultVisible = 60
ApiConstants.cacheValidHours = 1        // 但没有任何缓存实现
ApiConstants.maxHistoryItems = 20       // 正确使用
```

---

### 3.5 无错误边界 ⚠️

- API 全部失败只显示"无法获取股票数据"
- 无重试机制
- 无网络状态检测
- 无离线数据展示

---

### 3.6 `date` 字段类型不一致 ⚠️

**位置**: `stock_quote.dart`

```dart
class StockQuote {
  final String date;  // 字符串格式 "2024-01-01"
}
```

在 `macd_calculator.dart:33` 中直接使用:
```dart
result.add(MacdData(date: quotes[i].date, ...));
```

在 `_getUSStockData` 中却是:
```dart
final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
```

美国数据和中国数据 date 格式理论上应该一致，但无类型保证

---

## 四、可用性问题 (Usability)

### 4.1 缺少下拉刷新

- 无法刷新当前股票数据
- 需重新搜索才能刷新

### 4.2 无搜索自动补全

- 用户必须记住股票代码
- 无实时搜索建议
- 无股票名称搜索

### 4.3 无离线/缓存模式

- 网络不稳定时完全无法使用
- 无历史数据缓存
- 无超时处理

### 4.4 缺少周期切换

- 只有日K线
- 无周线/月线/季线切换
- 无分钟线

### 4.5 回测持仓计算取整问题 ⚠️

**位置**: `backtest_calculator.dart:48-49`

```dart
final maxPosition = (capital * positionRatio) / entryPrice;
position = maxPosition.floor().toDouble();  // 取整导致资金利用率 < 100%
```

在大牛市可能累积较大误差

### 4.6 AlertDialog 样式不统一

**位置**: `history_page.dart:98-119`

使用 `showDialog` + `AlertDialog`，而其他页面使用 Material 3 组件

---

## 五、测试覆盖

```
test/domain/calculators/
├── macd_calculator_test.dart   ✓
├── rsi_calculator_test.dart   ✓
└── wr_calculator_test.dart    ✓

test/presentation/               ✗ 无
test/bloc/                      ✗ 无 (尽管 pubspec.yaml 有 bloc_test 依赖)
test/data/                      ✗ 无
```

---

## 六、修复优先级

| 优先级 | 问题 | 修复工作量 | 影响 |
|--------|------|----------|------|
| P0 | `Navigator.pushNamed` → `go_router` | 10min | 功能完全不可用 |
| P0 | Settings按钮 crash | 30min | 点击必崩 |
| P0 | Tab 状态同步 | 20min | UI 显示错误 |
| P1 | DMI 回测未实现 | 1h | 功能缺失 |
| P1 | 自选股价格刷新 | 2h | 体验差 |
| P1 | 指标重复计算 | 1h | 性能浪费 |
| P2 | K线图 MA 数组越界 | 30min | 潜在崩溃 |
| P2 | 离线缓存 | 4h | 可用性 |
| P2 | 搜索自动补全 | 3h | 可用性 |
| P2 | EMA 代码重复 | 30min | 代码质量 |
| P3 | 测试覆盖 | - | 长期质量 |
| P3 | 架构重构 | - | 长期可维护性 |

---

## 七、建议改进项

### 7.1 短期（1-2天）

1. 修复 P0/P1 的所有 bug
2. 添加下拉刷新
3. 统一 Dialog 样式

### 7.2 中期（1周）

1. 实现搜索自动补全（调用东方财富搜索 API）
2. 添加数据缓存层
3. 统一状态管理（考虑引入 `freezed` + `riverpod`）

### 7.3 长期（1月+）

1. 补全测试覆盖（至少 BLoC 层）
2. 引入 `Repository` 模式解耦数据源
3. 支持多周期 K 线
4. 添加技术指标参数自定义 UI
