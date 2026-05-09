import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';

class TurtleHelpPage extends StatelessWidget {
  const TurtleHelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('海龟交易帮助'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/turtle'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            title: '📐 原理说明',
            icon: Icons.architecture,
            children: [
              _buildCard(
                title: '海龟交易法的起源',
                content: '''
理查德·丹尼斯（Richard Dennis）于 1983 年在芝加哥训练了一群交易员（被称为"海龟"），证明交易系统可以被传授。

他的核心观点是：交易成功不在于直觉，而在于严格遵守一套规则。

海龟交易法是最经典的趋势跟踪系统之一，核心理念：
  • 市场大部分时间处于震荡，趋势来时果断跟上
  • 用ATR（真实波幅）衡量波动性，实现动态仓位管理
  • 每笔交易风险固定为账户的1%，严格止损
  • 趋势跟踪必须一致性执行，不能临时主观判断
                ''',
              ),
              const SizedBox(height: 12),
              _buildCard(
                title: '核心概念：N值（ATR）',
                content: '''
N值是海龟交易系统的核心单位，表示市场的波动性。

计算方法（真实波幅 TR 的均值）：
  TR = max(H - L, |H - PC|, |L - PC|)
  N = TR的20日均值

其中：
  H：当日最高价
  L：当日最低价
  PC：前一日收盘价

N值的作用：
  • 衡量市场波动幅度
  • 用于计算仓位：每份风险 = 账户×1% / N
  • 用于设置止损：入场价 ± 2N
  • 用于设置止盈：入场价 ± 4N（或更高）
                ''',
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildSection(
            title: '📋 参数说明',
            icon: Icons.tune,
            children: [
              _buildParamCard(
                name: '账户资金',
                defaultVal: '100,000 元',
                range: '1万 ~ 100万',
                meaning: '回测的初始资金金额。资金大小会影响绝对收益，但不影响收益率和胜率。',
              ),
              _buildParamCard(
                name: '每份风险比例',
                defaultVal: '1.0%',
                range: '0.1% ~ 5%',
                meaning: '每笔交易愿意承受的账户资金比例。1%表示单笔最大亏损为账户的1%。配合2N止损，这意味着每份仓位的理论亏损是固定的。',
              ),
              _buildParamCard(
                name: 'ATR计算周期',
                defaultVal: '20日',
                range: '10 ~ 60日',
                meaning: 'N值的计算窗口。周期越长，N值越平滑（稳定但滞后）；周期越短，N值越灵敏（波动大）。丹尼斯原版使用20日。',
              ),
              _buildParamCard(
                name: '入场周期',
                defaultVal: '20日',
                range: '5 ~ 60日',
                meaning: '价格突破该周期高点入场做多，跌破该周期低点入场做空。丹尼斯原版使用20日。周期越短信号越多但假信号越多；周期越长信号越少但趋势跟随越稳定。',
              ),
              _buildParamCard(
                name: '离场周期',
                defaultVal: '10日',
                range: '3 ~ 30日',
                meaning: '做多时：价格跌破该周期最低点 → 平仓离场；做空时：价格突破该周期最高点 → 平仓离场。丹尼斯原版使用10日。离场周期越短保护越紧密但可能错过大趋势；周期越长越能持有趋势但回撤也越大。',
              ),
              _buildParamCard(
                name: '止损倍数',
                defaultVal: '2.0N',
                range: '0.5N ~ 4.0N',
                meaning: '止损距离 = 2N（即入场价 ± 2×ATR）。2N的含义是：如果市场向不利方向移动2个平均波动幅度，则止损。倍数越小止损越紧（亏损少但可能频繁触发）；倍数越大止损越松（能承受更大波动但单笔亏损也更大）。',
              ),
              _buildParamCard(
                name: '止盈倍数',
                defaultVal: '4.0N',
                range: '1.0N ~ 8.0N',
                meaning: '止盈目标 = 入场价 ± 4N。4N的意义：风险收益比4:1（止损2N vs 止盈4N）。倍数越小越容易实现止盈（胜率提高但单笔盈利减少）；倍数越大越追求大趋势（胜率降低但赔率高）。',
              ),
              _buildParamCard(
                name: '追踪止损周期',
                defaultVal: '20日',
                range: '5 ~ 60日',
                meaning: '做多时：价格跌破该周期最低点触发追踪止损；做空时：价格突破该周期最高点触发追踪止损。与离场周期的区别：离场周期主要用于趋势破坏退出，追踪止损用于锁定利润。丹尼斯原版使用20日。',
              ),
              _buildParamCard(
                name: '追踪止损ATR倍数',
                defaultVal: '2.0N',
                range: '0.5N ~ 4.0N',
                meaning: '触发追踪止损时，要求价格相对于周期最高/最低点额外偏离一定比例。默认2.0N意味着：做多时若价格从周期最高点回落超过2个ATR，则触发追踪止损。倍数越小越敏感（较早锁定利润但可能错过大趋势）；倍数越大越迟钝。',
              ),
              _buildParamCard(
                name: '最大持仓份数',
                defaultVal: '4份',
                range: '1 ~ 8份',
                meaning: '海龟加仓上限。当趋势延续时，每盈利0.5N可加仓一份（最多加到最大份数）。原版海龟最多持有4份。增加持仓份数可放大盈利但也会增加回撤。',
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildSection(
            title: '🔄 完整交易规则',
            icon: Icons.loop,
            children: [
              _buildCard(
                title: '入场信号',
                content: '''
做多入场：价格突破 N1 日最高点（可加仓：每盈利 0.5N 加仓一份）
做空入场：价格跌破 N1 日最低点

注：若前一交易日为涨跌停，当日禁止入场（防止流动性风险）
                ''',
              ),
              const SizedBox(height: 8),
              _buildCard(
                title: '止损规则',
                content: '''
每笔交易的最大亏损限制为：入场价 ± 止损倍数 × N
标准海龟止损 = 入场价 ± 2N

触发止损后：全部平仓，不允许扛单。
                ''',
              ),
              const SizedBox(height: 8),
              _buildCard(
                title: '离场信号（趋势破坏）',
                content: '''
做多离场：价格跌破最近 N2 日最低点
做空离场：价格突破最近 N2 日最高点

触发离场后：全部平仓，等待下一个入场信号。
                ''',
              ),
              const SizedBox(height: 8),
              _buildCard(
                title: '止盈规则',
                content: '''
当价格达到止盈目标位（入场价 ± 止盈倍数 × N）时触发止盈。
止盈后：全部平仓，不参与后续趋势。
注：若同时触发追踪止损，以先触发者为准。
                ''',
              ),
              const SizedBox(height: 8),
              _buildCard(
                title: '追踪止损',
                content: '''
追踪止损在趋势破坏离场基础上增加一层利润保护：
  做多：若价格从周期最高点回落超过（ATR倍数-1）× ATR，则触发
  做空：若价格从周期最低点上涨超过（ATR倍数-1）× ATR，则触发

追踪止损触发后：全部平仓。
                ''',
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildSection(
            title: '📐 仓位计算',
            icon: Icons.calculate,
            children: [
              _buildCard(
                title: '单份仓位公式',
                content: '''
每份股数 = 账户 × 风险比例% / (N × 止损倍数N)

例：账户10万，风险1%，N=0.5，止损2N
  每份股数 = 100,000 × 1% / (0.5 × 2) = 1,000 股

实际买入金额 = 每份股数 × 入场价
持仓价值应控制在账户的合理范围内。
                ''',
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildSection(
            title: '⚠️ 局限性说明',
            icon: Icons.warning_amber,
            children: [
              _buildCard(
                title: '适用场景与局限',
                content: '''
海龟交易法是趋势跟踪系统，适用于：
  ✅ 趋势明显的品种（期货、指数、周期股）
  ✅ 波动性适中的市场（ATR不太大也不太小）
  ✅ 长周期操作（持有数周至数月）

其局限性包括：
  ❌ 震荡行情中连续亏损（假突破频繁）
  ❌ 需要足够资金支持加仓（否则无法发挥系统优势）
  ❌ 对交易成本敏感（频繁交易+加仓会产生大量手续费）
  ❌ 无法规避突发性跳空（隔夜/节假日风险）

实盘建议：
  • 选择流动性好、趋势明显的ETF或指数基金
  • 预留足够资金用于加仓（建议初始资金至少能买4份）
  • 每年评估系统有效性，若连续亏损超过预期应停止实盘
  • 可以用模拟盘先验证2-3个月再上实盘
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
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }

  Widget _buildCard({required String title, required String content}) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(content.trim(), style: const TextStyle(fontSize: 12.5, height: 1.6)),
          ],
        ),
      ),
    );
  }

  Widget _buildParamCard({
    required String name,
    required String defaultVal,
    required String range,
    required String meaning,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('默认值: $defaultVal', style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('可调范围: $range', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text(meaning.trim(), style: const TextStyle(fontSize: 12.5, height: 1.55)),
          ],
        ),
      ),
    );
  }
}
