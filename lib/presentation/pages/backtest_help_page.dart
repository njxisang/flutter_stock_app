import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';

class BacktestHelpPage extends StatelessWidget {
  const BacktestHelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('回测帮助'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/backtest'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            title: '📊 指标说明',
            icon: Icons.analytics,
            children: [
              _buildStrategyCard(
                context,
                name: 'MACD（指数平滑异同移动平均线）',
                subtitle: '最广泛的趋势跟踪指标',
                params: const [
                  _Param('快线周期 (fast)', '12', '计算快速EMA的周期，值越小越灵敏'),
                  _Param('慢线周期 (slow)', '26', '计算慢速EMA的周期，值越大越滞后但越稳定'),
                  _Param('信号周期 (signal)', '9', '对DIF进行平滑的周期，形成DEA线'),
                ],
                logic: '''
MACD 由 Gerald Appel 发明，由三部分组成：

• DIF（差离值）= EMA(快线) - EMA(慢线)
  - DIF > 0：短期价格高于长期价格 → 多头趋势
  - DIF < 0：短期价格低于长期价格 → 空头趋势

• DEA（信号线）= EMA(DIF, signalPeriod)
  - DIF 从下方穿越 DEA → 金叉 → 买入信号
  - DIF 从上方穿越 DEA → 死叉 → 卖出信号

• MACD 柱 = (DIF - DEA) × 2
  - 柱状图翻红（正值）→ 多头动能增强
  - 柱状图翻绿（负值）→ 空头动能增强

本 app 采用标准参数 (12,26,9)，这是最常用的组合。
参数调整建议：
  - 短线交易：可缩短周期如 (6,13,5)，信号更早但假信号更多
  - 长线趋势：可延长周期如 (19,39,9)，信号更少更可靠
                ''',
                tips: 'MACD 是趋势跟踪指标，在震荡行情中会有较多虚假信号。建议配合其他指标使用。',
              ),
              _buildStrategyCard(
                context,
                name: 'KDJ（随机指标）',
                subtitle: '乔治·莱恩发明的超买超卖指标',
                params: const [
                  _Param('周期 (period)', '9', 'RSV 计算的窗口大小'),
                  _Param('K 权重', '1/3', 'K 值的平滑权重（固定）'),
                  _Param('D 权重', '1/3', 'D 值的平滑权重（固定）'),
                  _Param('超买阈值', '80', 'D 值超过此值认为超买（看空）'),
                  _Param('超卖阈值', '20', 'D 值低于此值认为超卖（看多）'),
                ],
                logic: '''
KDJ 由 George Lane 在 1950 年代发明，基于随机游走原理：

• RSV（未成熟随机值）= (C - LLV) / (HHV - LLV) × 100
  - C：当日收盘价
  - LLV：最近 N 日最低价
  - HHV：最近 N 日最高价
  - RSV 越高：当前价格越接近 N 日最高价（偏强）
  - RSV 越低：当前价格越接近 N 日最低价（偏弱）

• K 值 = 2/3 × 前K + 1/3 × RSV（平滑处理）
• D 值 = 2/3 × 前D + 1/3 × K（同上）
• J 值 = 3×K - 2×D（放大波动）

★ 金叉：D 值在超卖区（<20）时，K 从下向上穿越 D → 买入
★ 死叉：D 值在超买区（>80）时，K 从上向下穿越 D → 卖出

参数调整建议：
  - 周期越小（如 5,6）：指标越灵敏，波动越剧烈
  - 周期越大（如 18,21）：指标越平滑，信号越少
  - 超买超卖阈值：保守交易者可调整为 70/30（更严格）
                ''',
                tips: 'KDJ 的 J 值波动极大，一般主要参考 K 和 D 的交叉。KDJ 在盘整行情中容易反复交叉产生噪音。',
              ),
              _buildStrategyCard(
                context,
                name: 'RSI（相对强弱指数）',
                subtitle: 'J. Welles Wilder Jr. 发明的动量指标',
                params: const [
                  _Param('周期 (period)', '14', '计算平均涨跌的窗口大小'),
                  _Param('超买阈值', '70', 'RSI 超过此值认为超买'),
                  _Param('超卖阈值', '30', 'RSI 低于此值认为超卖'),
                ],
                logic: '''
RSI 由 J. Welles Wilder Jr. 在 1978 年《技术交易系统新概念》中提出，是最经典的动量指标：

• 计算步骤：
  1. 每日变化 Δ = 收盘价今日 - 收盘价昨日
  2. 平均涨幅 = N 日内所有正 Δ 的均值
  3. 平均跌幅 = N 日内所有负 |Δ| 的均值
  4. RS = 平均涨幅 / 平均跌幅
  5. RSI = 100 - 100/(1+RS)   或   RSI = 平均涨幅/(平均涨幅+平均跌幅) × 100

• RSI 取值范围 [0, 100]：
  - RSI > 70（超买）：买方力量过度，可能反转向下
  - RSI < 30（超卖）：卖方力量过度，可能反弹向上
  - RSI ≈ 50：多空力量平衡

★ 买入：RSI 从超卖区（<30）向上突破 → 多头介入
★ 卖出：RSI 从超买区（>70）向下突破 → 空头介入

参数调整建议：
  - 短线（如 6 日）：更灵敏，RSI 波动大，信号更多
  - 中线（如 14 日）：Wilder 默认值，最常用
  - 长线（如 21 日）：更平滑，过滤噪音但延迟大
  - 超买超卖：激进型 80/20，保守型 60/40
                ''',
                tips: 'RSI 是bounded oscillator（受限振荡器），数值会被限制在 0~100。极端行情中 RSI 可长时间维持在超买/超卖区。',
              ),
              _buildStrategyCard(
                context,
                name: 'BOLL（布林带）',
                subtitle: '约翰·布林格发明的波动率通道指标',
                params: const [
                  _Param('周期 (period)', '20', '计算中轨和标准差的窗口大小'),
                  _Param('标准差倍数', '2', '上下轨与中轨的距离（多少倍标准差）'),
                ],
                logic: '''
BOLL 由 John Bollinger 在 1980 年代发明，利用统计学原理刻画价格波动范围：

• 中轨（MB）= N 日简单移动平均线（SMA）
• 上轨（UP）= 中轨 + K × 标准差
• 下轨（DN）= 中轨 - K × 标准差

标准差的含义：
  - 标准差 ≈ 2：意味着约 95% 的价格落在通道内（2σ 置信区间）
  - K 越大 → 通道越宽 → 容纳更多价格波动，假信号少但延迟大
  - K 越小 → 通道越窄 → 价格更频繁穿越轨道，假信号多但灵敏

★ 买入：价格从下轨下方向上穿越下轨 → 突破支撑，看多
★ 卖出：价格从上轨上方，向下跌破上轨 → 跌破压力，看空

参数调整建议：
  - 周期 20：Boll 默认为 20，是统计学上常用的样本数
  - 标准差倍数：默认 2（覆盖约 95% 数据），可调至 3（更宽，减少假突破）
  - 周期缩短（如 14）：通道更窄，更灵敏但假信号多
                ''',
                tips: '布林带是"价格包络型"指标，趋势行情中轨道会张口（扩散），震荡行情中会收口（收窄）。布林带收口到极致后往往伴随大幅波动。',
              ),
              _buildStrategyCard(
                context,
                name: 'MA（移动均线）',
                subtitle: '最基础的趋势判断工具',
                params: const [
                  _Param('短期均线', '5', '最灵敏的均线，反映短期趋势'),
                  _Param('中期均线', '10', '反映中期趋势方向'),
                  _Param('长期均线', '20', '最稳定的均线，反映长期趋势'),
                ],
                logic: '''
移动平均线（MA）是最古老也是最常用的技术分析工具：

• 计算：MA(N) = (P₁ + P₂ + ... + Pₙ) / N
  - 对过去 N 日价格求简单平均，作为当前趋势的参考线

均线排列的本质：
  - 多头排列：短期 > 中期 > 长期均线 → 市场处于上升趋势
  - 空头排列：短期 < 中期 < 长期均线 → 市场处于下降趋势
  - 缠绕：各均线交织在一起 → 市场方向不明

★ 买入条件（空头 → 多头转换）：
  1. 短期均线从下向上穿越中期均线（金叉）
  2. 中期均线在长期均线之上
  3. 三条均线呈多头顺序排列

★ 卖出条件（多头 → 空头转换）：
  1. 短期均线从上向下穿越中期均线（死叉）
  2. 三条均线呈空头顺序排列

参数调整建议：
  - 短线 (5,10,20)：最常用，均线系灵敏
  - 中线 (10,20,60)：适合波段操作，过滤短期噪音
  - 长线 (20,60,120)：适合趋势跟踪，信号少但可靠
  - 注意：短中长三根均线的周期差距要足够大，否则多头/空头排列不明显
                ''',
                tips: '均线系统天然具有滞后性。在行情反转初期，均线可能发出延迟信号。频繁震荡行情中，均线会反复交叉产生"均线缠绕"噪音。',
              ),
              _buildStrategyCard(
                context,
                name: 'WR（威廉指标）',
                subtitle: '拉里·威廉斯发明的超买超卖指标',
                params: const [
                  _Param('周期 (period)', '10', '计算最高价/最低价的窗口大小'),
                  _Param('超买阈值', '20', 'WR 低于此值认为超买（看空）'),
                  _Param('超卖阈值', '80', 'WR 高于此值认为超卖（看多）'),
                ],
                logic: '''
威廉指标（Williams %R）由 Larry Williams 发明，与 RSI、KDJ 同属超买超卖类指标：

• 计算公式：WR(N) = (HHV - C) / (HHV - LLV) × 100
  - HHV：最近 N 日最高价
  - LLV：最近 N 日最低价
  - C：当前收盘价

• 理解 WR 的取值：
  - WR ≈ 0（即 C ≈ HHV）：价格处于 N 日最高点，极度偏强
  - WR ≈ -100（即 C ≈ LLV）：价格处于 N 日最低点，极度偏弱
  - WR = -50：价格处于 N 日区间的中点

• WR 的超买超卖逻辑（注意与 RSI 方向相反）：
  - WR > 80（处于区间下半部）：价格偏低位运行 → 超卖区域 → 潜在买入机会
  - WR < 20（处于区间上半部）：价格偏高位运行 → 超买区域 → 潜在卖出机会

★ 买入：WR 从超卖区（>80）向上突破 80 关口 → 价格从低位启动
★ 卖出：WR 从超买区（<20）向下跌破 20 关口 → 价格从高位回落

参数调整建议：
  - 周期越小：指标越灵敏，波动越剧烈
  - 周期越大：指标越平滑，信号越少
  - WR 变化非常快，常配合其他指标使用
                ''',
                tips: '威廉指标的周期参数影响极大：短周期（如 6 日）非常灵敏但噪音多；长周期（如 20 日）更稳定但有较大延迟。',
              ),
              _buildStrategyCard(
                context,
                name: 'DMI（趋向指标）',
                subtitle: 'J. Welles Wilder Jr. 发明的趋势强度指标',
                params: const [
                  _Param('DI 周期', '14', '计算 +DI/-DI 的 ATR 窗口（Wilder 推荐值）'),
                  _Param('ADX 周期', '14', '平滑 DX 形成 ADX 的周期'),
                  _Param('趋势阈值', '25', 'ADX 高于此值认为存在明确趋势'),
                ],
                logic: '''
DMI（Directional Movement Index）由 J. Welles Wilder Jr. 在 1978 年提出，是 ADX 趋势强度指标的核心：

• 核心概念：
  - +DM（正向趋向）：今日高点高于昨日高点的幅度
  - -DM（负向趋向）：昨日低点低于今日低点的幅度
  - TR（真实波幅）：今日价格波动范围，考虑了跳空缺口

• 计算过程（迭代，Wilder 平滑）：
  1. ATR[N] = (ATR[N-1] × (period-1) + TR[N]) / period
  2. +DI[N] = (+DM[N] / ATR[N]) × 100
  3. -DI[N] = (-DM[N] / ATR[N]) × 100
  4. DX = |+DI - -DI| / (+DI + -DI) × 100
  5. ADX[N] = (ADX[N-1] × (period-1) + DX[N]) / period

• 读数含义：
  - +DI > -DI：上升趋势占优，看多
  - -DI > +DI：下降趋势占优，看空
  - ADX 越高：趋势越强（无论多空）
  - ADX 越低：趋势越弱（盘整）

★ 买入：+DI > -DI 且 ADX 在上升（确认趋势）→ 做多
★ 卖出：-DI > +DI 且 ADX 在上升 → 做空
★ 无操作：ADX < 趋势阈值（如 25）→ 趋势不明显

参数调整建议：
  - 周期 14：Wilder 原版推荐，最广泛使用
  - 趋势阈值 25：ADX > 25 才认为有明确趋势，可调至 20（更宽松）或 30（更严格）
                ''',
                tips: 'DMI 的核心价值在于 ADX 能衡量趋势的"强度"而非"方向"。ADX 上升不意味着上涨，可能只是下跌趋势在加强。需要结合 +DI/-DI 共同判断方向。',
              ),
              _buildStrategyCard(
                context,
                name: '多指标综合（共振策略）',
                subtitle: 'MACD + KDJ + RSI 三指标共振',
                params: const [
                  _Param('MACD 参数', '使用当前设置', 'MACD 快/慢/信号周期'),
                  _Param('RSI 参数', '使用当前设置', 'RSI 周期和超买超卖阈值'),
                  _Param('KDJ 参数', '使用当前设置', 'KDJ 周期和超买超卖阈值'),
                ],
                logic: '''
多指标共振策略通过同时满足多个指标的条件来过滤虚假信号，提高信号质量：

• 信号逻辑：
  - 统计 MACD、KDJ、RSI 三个指标的信号方向
  - 至少 2 个指标同时发出做多信号 → 才执行做多
  - 至少 2 个指标同时发出做空信号 → 才执行做空
  - 否则保持观望

• 共振策略的优势：
  1. 过滤假信号：单一指标的虚假信号被其他指标过滤
  2. 提高胜率：多指标共振时，往往对应更强的趋势
  3. 减少频繁交易：要求多指标一致，交易频率自然降低

• 共振策略的劣势：
  1. 信号延迟更大：需要等待多个指标确认
  2. 可能错过最佳入场点
  3. 在趋势初期可能无法触发信号

• 调整方法：分别调整 MACD、RSI、KDJ 的参数，可以精细化控制共振灵敏度
                ''',
                tips: '共振策略适合中线操作，短线交易可能因为等待多个指标确认而错过机会。建议在大周期（如日线）使用。',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: '📐 通用参数说明',
            icon: Icons.tune,
            children: [
              _buildInfoCard(
                title: '初始资金',
                content: '回测开始时的账户资金金额（单位：元）。用于计算收益率、仓位大小等。',
                default_: '100000',
              ),
              _buildInfoCard(
                title: '费率（手续费率）',
                content: '买卖双向收取的费用比率。\n\nA股实际费率参考：\n• 券商佣金：一般约 0.0003~0.001（万0.3~千1），最低 5 元\n• 印花税：仅卖出时收取，0.001（千1）\n• 过户费：约 0.00002（双向）\n\n本 app 采用简化的双边费率模型：\n费率 = 0.001 表示买卖各收 0.1%，卖出再加 0.1% 印花税，共约 0.2% 的交易成本',
                default_: '0.001（千1）',
              ),
              _buildInfoCard(
                title: '仓位比例（0~1）',
                content: '每次信号触发时，用于买入的资金占总资金的比例。\n\n• 1.0 = 全仓：每次信号使用全部资金买入\n• 0.5 = 半仓：每次信号使用 50% 资金买入\n• 0.1 = 10% 仓位：轻仓试探\n\n说明：仓位越低，最大回撤越小，但收益也相应降低。真实交易中建议不超过 0.5 以控制风险。',
                default_: '1.0（全仓）',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: '📋 回测结果指标说明',
            icon: Icons.assessment,
            children: [
              _buildInfoCard(
                title: '总收益',
                content: '回测结束时相较初始资金的绝对盈利金额（扣除费用后）。',
                default_: '',
              ),
              _buildInfoCard(
                title: '收益率',
                content: '总收益 / 初始资金 × 100%。最直观反映策略盈利能力。',
                default_: '',
              ),
              _buildInfoCard(
                title: '胜率',
                content: '盈利交易次数 / 总交易次数 × 100%。\n\n注意：高胜率不等于盈利，还需看盈亏比。例如：\n• 胜率 60%，平均盈利 100 元，平均亏损 200 元 → 最终亏损\n• 胜率 40%，平均盈利 300 元，平均亏损 100 元 → 最终盈利',
                default_: '',
              ),
              _buildInfoCard(
                title: '盈亏比',
                content: '平均盈利金额 / 平均亏损金额。\n\n• 盈亏比 > 1：每次盈利比亏损多，胜率不用很高也能盈利\n• 盈亏比 < 1：需要高胜率才能盈利\n• 盈亏比 = 0：表示全程亏损',
                default_: '',
              ),
              _buildInfoCard(
                title: '夏普比率（Sharpe Ratio）',
                content: '每承受一单位风险所获得的超额收益。\n\n公式：夏普比率 = (策略年化收益 - 无风险利率) / 策略收益年化波动率\n\n参考标准：\n• < 0：策略不如无风险资产（国债）\n• 0~1：收益不足以补偿风险\n• 1~2：较好\n• > 2：优秀（但也需警惕过度拟合）',
                default_: '',
              ),
              _buildInfoCard(
                title: '最大回撤（Max Drawdown）',
                content: '从历史最高点到最低点的最大跌幅百分比。\n\n• 反映策略在最恶劣情况下的损失\n• 比收益率更重要，因为亏损需要更大的涨幅来弥补\n  - 亏损 10% → 需涨 11.1% 回本\n  - 亏损 50% → 需涨 100% 回本\n  - 亏损 80% → 需涨 400% 回本\n\n实盘建议：最大回撤控制在 20% 以内为宜。',
                default_: '',
              ),
              _buildInfoCard(
                title: 'Kelly 仓位',
                content: 'Kelly Formula 计算的最优下注比例：\nKelly% = W - (1-W)/R\n  其中 W = 胜率，R = 盈亏比\n\n• Kelly 100%：理论上最优，实际中建议用半 Kelly（50%）降低风险\n• Kelly 50%：保守但更稳定\n• Kelly 0% 或负数：策略没有正向期望',
                default_: '',
              ),
              _buildInfoCard(
                title: '平均盈利 / 平均亏损',
                content: '所有盈利交易的平均金额，和所有亏损交易的平均金额。用于计算盈亏比和评估策略的盈亏分布。',
                default_: '',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: '⚠️ 回测局限性说明',
            icon: Icons.warning_amber,
            children: [
              _buildWarningCard(
                content: '''
回测结果仅供参考，不代表实盘表现。

以下因素会导致回测与实盘差异：

1. 未来函数偏差（Look-ahead bias）
   回测时使用了当时还不存在的数据
   → 本 app 严格按时间顺序处理，每根 K 线只用已知数据

2. 过度拟合（Overfitting）
   用同一段历史数据反复调参，直到结果好看
   → 多参数比较中发现的最优参数可能只是巧合

3. 流动性假设
   回测假设任何价格都能买入/卖出
   实盘中大额资金无法瞬间以"收盘价"成交

4. 交易滑点
   实盘成交价通常比回测价格差 0.1%~0.5%
   → 建议在费率中加入 0.1%~0.2% 滑点缓冲

5. 市场结构变化
   2020 年后A股量化机构增多，部分因子有效性下降
   历史上有效的策略未来可能失效

6. 涨跌停无法交易
   本 app 已处理：涨停时无法买入，跌停时无法卖出
   但未处理：持仓股票连续涨停后无法卖出（一字板）

建议：回测收益率 ≥ 3 倍无风险收益、夏普比率 > 1.5、最大回撤 < 20% 的策略才值得考虑实盘。
''',
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 22, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildStrategyCard(
    BuildContext context, {
    required String name,
    required String subtitle,
    required List<_Param> params,
    required String logic,
    required String tips,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          initiallyExpanded: false,
          title: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          children: [
            // 参数列表
            if (params.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(13),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('可调参数', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...params.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 130,
                                child: Text('${p.name}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              ),
                              Text('默认 ${p.defaultVal}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        )),
                    if (params.any((p) => p.desc.isNotEmpty)) ...[
                      const Divider(height: 16),
                      ...params.where((p) => p.desc.isNotEmpty).map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('• ${p.name}：${p.desc}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          )),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            // 实现逻辑
            const Text('实现逻辑', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(logic.trim(),
                style: const TextStyle(fontSize: 12.5, height: 1.6, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            // 提示
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(26),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.withAlpha(77)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(tips,
                        style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String content,
    required String default_,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
                if (default_.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(13),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('默认: $default_',
                        style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(content.trim(), style: const TextStyle(fontSize: 12.5, height: 1.6)),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningCard({required String content}) {
    return Card(
      color: Colors.orange.withAlpha(13),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(content.trim(), style: const TextStyle(fontSize: 12.5, height: 1.6)),
      ),
    );
  }
}

class _Param {
  final String name;
  final String defaultVal;
  final String desc;
  const _Param(this.name, this.defaultVal, this.desc);
}

