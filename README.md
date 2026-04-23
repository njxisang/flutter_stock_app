# 股票 MACD 技术分析应用

A 股 / 港股 / 美股全品种技术分析工具，支持 K 线、MACD、RSI、KDJ、BOLL、MA、WR、DMI 等指标，支持回测、风险分析、因子分析。

---

## 功能概览

### 主页面（K 线分析）

**股票搜索**
- 输入股票代码/简称自动搜索，支持 A 股（上交所 / 深交所 / 北交所）、美股
- 搜索历史自动补全
- 示例代码：沪深 600519（茅台）、深 000001（平安）、沪 600000、港 00700（腾讯）、美 AAPL

**时间范围**
- 6 档快捷切换：近 1 周 / 1 月 / 3 月 / 6 月 / 1 年 / 5 年

**技术指标（9  tabs）**

| Tab | 指标 | 说明 |
|-----|------|------|
| K线 | 蜡烛图 + 均线 | 经典 OHLC 蜡烛图叠加 MA5/10/20/60 |
| MACD | DIF / DEA / MACD 柱 | 金叉死叉信号提示 |
| RSI | 相对强弱指数 | 超买超卖判断（默认 14 日） |
| KDJ | K / D / J 线 | 随机指标 |
| BOLL | 布林带上中下轨 | 支撑压力判断 |
| MA | 均线系统 | MA5 / MA10 / MA20 / MA60 多线叠加 |
| WR | 威廉指标 | 超买超卖（-20/-80 线） |
| DMI | PDX / MDI / ADX | 趋势方向与强度 |
| 分布 | 价格直方图 | 历史价格分布统计 |

### 自选股

- 添加 / 删除自选股，快捷访问常用标的

### 历史记录

- 自动记录每次搜索，方便回溯

### 回测

- 支持 7 种策略：MACD / KDJ / RSI / BOLL / MA / WR / DMI / 多指标共振
- 可配置参数：初始资金、费率、仓位比例
- 输出收益曲线、买卖信号图、年度统计

### 多因子分析

- 对当前加载股票进行综合技术面评分
- 包含趋势强度、波动率、量价关系等维度
- 支持与大盘（上证指数）对比

### 风险分析

- 最大回撤、年化波动率、夏普比率、收益风险比
- 持仓收益分布

### 其他

- 明暗主题切换（设置页）
- 最小化行情数据用量，纯计算本地完成

---

## 技术架构

```
lib/
├── main.dart                        # 入口，初始化 DI
├── app.dart                          # App 根组件，BlocProvider
├── core/
│   ├── constants/app_constants.dart  # 常量（颜色、字符串）
│   ├── router/app_router.dart       # go_router 路由配置
│   ├── theme/                        # 主题定义
│   └── widgets/                       # 公共 Widget
├── data/
│   ├── datasources/
│   │   ├── stock_api_service.dart   # 东方财富 API 数据获取
│   │   └── stock_local_storage.dart # SharedPreferences 本地存储
│   ├── models/                       # 数据模型（JSON 序列化）
│   └── repositories/                 # Repository 实现
├── domain/
│   ├── entities/stock_quote.dart    # 核心实体（K线数据、指标计算结果）
│   ├── repositories/                 # Repository 接口
│   └── usecases/calculators/         # 技术指标计算器
│       ├── macd_calculator.dart
│       ├── rsi_calculator.dart
│       ├── kdj_calculator.dart
│       ├── boll_calculator.dart
│       ├── ma_calculator.dart
│       ├── wr_calculator.dart
│       ├── dmi_calculator.dart
│       ├── multi_factor_analyzer.dart
│       ├── backtest_calculator.dart
│       └── risk_analyzer.dart
└── presentation/
    ├── blocs/                        # flutter_bloc 状态管理
    │   ├── stock/                    # 股票数据 Bloc
    │   ├── chart/                    # 图表 Tab 状态
    │   ├── watchlist/                # 自选股 Cubit
    │   └── settings/                 # 设置 Cubit
    ├── pages/                        # 页面
    │   ├── main_page.dart            # K线主页
    │   ├── watchlist_page.dart       # 自选股
    │   ├── history_page.dart         # 历史记录
    │   ├── backtest_page.dart        # 回测
    │   ├── analysis_page.dart        # 多因子分析
    │   ├── signal_analysis_page.dart # 信号分析
    │   ├── risk_analysis_page.dart   # 风险分析
    │   ├── prediction_page.dart      # 预测
    │   ├── turtle_trading_page.dart  # 海龟交易
    │   ├── portfolio_analysis_page.dart # 组合分析
    │   └── settings_page.dart        # 设置
    └── widgets/                      # 公共图表组件
```

**状态管理**：flutter_bloc + equatable
**路由**：go_router（ShellRoute 底部导航 + 子路由）
**图表**：fl_chart
**数据源**：东方财富 push2his API（实时 K 线，无 Key）
**本地存储**：shared_preferences

---

## 数据来源

股票 K 线数据来自东方财富（eastmoney.com），通过其公开 K 线 API 获取：

```
https://push2his.eastmoney.com/api/qt/stock/kline/get
```

支持上交所（6开头）、深交所（0/3开头）、北交所（8开头）、美股（Yahoo Finance）。

---

## 开发环境

```bash
# Flutter 版本
Flutter 3.24.0 / Dart 3.5.0

# 通过 fvm 管理版本
/home/xisang/fvm/versions/3.24.0/bin/flutter

# 安装依赖
flutter pub get

# 开发调试
flutter run

# 构建 Debug APK
flutter build apk --debug

# 构建 Release APK
flutter build apk --release
```

**环境要求**
- Android SDK
- JDK 17（如遇 Gradle 报错，检查 JAVA_HOME）
- 网络权限（INTERNET）

**JAVA_HOME 参考值**
```
JAVA_HOME=/home/xisang/miniconda3/pkgs/openjdk-17.0.18-ha668962_0/lib/jvm
```

---

## App 图标

当前使用自定义霓虹赛博朋克风格图标，包含 K 线蜡烛图元素。

**图标更新方式：**

```bash
# 1. 编辑源像素图（Neon 风格，512x512，6px 像素块）
#    路径 /tmp/stock_app_icon_pixel.png

# 2. 运行生成脚本（需要 Pillow）
/home/xisang/miniconda3/envs/a-trade-env/bin/python3 /tmp/gen_flutter_icons.py

# 3. 提交
git add android/app/src/main/res/mipmap-*/
git commit -m "chore: 更新 App 图标"
```

**设计规范：**
- 前景：霓虹绿（#00E676）上涨 K 线 + 霓虹红（#FF1744）下跌 K 线
- 背景：深蓝（#0D1B2A）
- 分辨率：mdpi(48dp) / hdpi(72dp) / xhdpi(96dp) / xxhdpi(144dp) / xxxhdpi(192dp)
- Android 8.0+ 使用 Adaptive Icon（前景 + 背景分层）

---

## 路由结构

| 路径 | 页面 | 导航 |
|------|------|------|
| `/` | K线主页 | 底部 Tab |
| `/watchlist` | 自选股 | 底部 Tab |
| `/history` | 历史记录 | 底部 Tab |
| `/backtest` | 回测 | 底部 Tab |
| `/analysis` | 多因子分析 | 从主页跳转（全屏） |
| `/analysis/signal` | 信号分析 | 子路由 |
| `/analysis/risk` | 风险分析 | 子路由 |
| `/analysis/prediction` | 预测 | 子路由 |
| `/analysis/turtle` | 海龟交易 | 子路由 |
| `/analysis/portfolio` | 组合分析 | 子路由 |
| `/settings` | 设置 | 主页右上角 |

---

## 版本历史

- **v1.0.0** — Flutter 重构版初版，支持 K 线、9 种技术指标、回测、多因子分析、风险分析、自选股
