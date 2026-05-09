import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/stock_quote.dart';
import '../blocs/settings/settings_cubit.dart';
import '../blocs/stock/stock_bloc.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<ExitTemplate> _exitTemplates = [];

  @override
  void initState() {
    super.initState();
    _loadExitTemplates();
  }

  void _loadExitTemplates() {
    final templates = context.read<StockBloc>().stockStorage.getExitTemplates();
    setState(() => _exitTemplates = templates);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.settings),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          final s = state.settings;
          return ListView(
            children: [
              // ── 图表设置 ──────────────────────────────────────
              const _SectionHeader(title: AppStrings.chartSettings),
              _SettingsGroup(children: [
                _SwitchTile(
                  title: AppStrings.solidCandle,
                  subtitle: '实心填充K线',
                  value: s['hollowCandle'] == false,  // false=实心(默认), true=空心
                  onChanged: (v) => context.read<SettingsCubit>()
                      .updateSetting('hollowCandle', !v),  // v=false时存false(实心), v=true时存true(空心)
                ),
                _SliderTile(
                  title: '${AppStrings.candleWidth}：${s['candleWidth'] ?? 8}',
                  value: (s['candleWidth'] ?? 8).toDouble(),
                  min: 4, max: 14, divisions: 10,
                  onChanged: (v) => context.read<SettingsCubit>()
                      .updateSetting('candleWidth', v.round()),
                ),
                _SegmentTile(
                  title: AppStrings.colorTheme,
                  value: s['colorTheme'] ?? 'classic',
                  options: const {
                    'classic':   '经典红绿',
                    'green_red': '绿涨红跌',
                    'purple':    '紫蓝配色',
                  },
                  onChanged: (v) => context.read<SettingsCubit>()
                      .updateSetting('colorTheme', v),
                ),
              ]),

              // ── 均线显示 ──────────────────────────────────────
              const _SectionHeader(title: AppStrings.maSettings),
              _SettingsGroup(children: [
                _SwitchTile(title: 'MA5',  value: s['showMa5']  ?? true,  onChanged: (v) => context.read<SettingsCubit>().updateSetting('showMa5',  v)),
                _SwitchTile(title: 'MA10', value: s['showMa10'] ?? true,  onChanged: (v) => context.read<SettingsCubit>().updateSetting('showMa10', v)),
                _SwitchTile(title: 'MA20', value: s['showMa20'] ?? true,  onChanged: (v) => context.read<SettingsCubit>().updateSetting('showMa20', v)),
                _SwitchTile(title: 'MA60', value: s['showMa60'] ?? false, onChanged: (v) => context.read<SettingsCubit>().updateSetting('showMa60', v)),
              ]),

              // ── 成交量 ──────────────────────────────────────
              const _SectionHeader(title: AppStrings.volume),
              _SettingsGroup(children: [
                _SwitchTile(
                  title: AppStrings.showVolume,
                  value: s['showVolume'] ?? true,
                  onChanged: (v) => context.read<SettingsCubit>().updateSetting('showVolume', v),
                ),
              ]),

              const Divider(height: 32),

              // ── 指标参数 ──────────────────────────────────────
              const _SectionHeader(title: '指标参数'),
              _SettingsTile(
                title: 'MACD ${AppStrings.shortPeriod}',
                trailing: Text('${s['shortPeriod']}'),
                onTap: () => _showPeriodPicker(context, 'shortPeriod', 5, 20, s['shortPeriod']),
              ),
              _SettingsTile(
                title: 'MACD ${AppStrings.longPeriod}',
                trailing: Text('${s['longPeriod']}'),
                onTap: () => _showPeriodPicker(context, 'longPeriod', 15, 60, s['longPeriod']),
              ),
              _SettingsTile(
                title: 'MACD ${AppStrings.signalPeriod}',
                trailing: Text('${s['signalPeriod']}'),
                onTap: () => _showPeriodPicker(context, 'signalPeriod', 5, 15, s['signalPeriod']),
              ),
              _SettingsTile(
                title: 'RSI ${AppStrings.period}',
                trailing: Text('${s['rsiPeriod']}'),
                onTap: () => _showPeriodPicker(context, 'rsiPeriod', 6, 21, s['rsiPeriod']),
              ),
              _SettingsTile(
                title: 'KDJ ${AppStrings.period}',
                trailing: Text('${s['kdjPeriod']}'),
                onTap: () => _showPeriodPicker(context, 'kdjPeriod', 5, 20, s['kdjPeriod']),
              ),
              _SettingsTile(
                title: 'BOLL ${AppStrings.period}',
                trailing: Text('${s['bollPeriod']}'),
                onTap: () => _showPeriodPicker(context, 'bollPeriod', 10, 30, s['bollPeriod']),
              ),

              const Divider(height: 32),

              // ── 显示设置 ──────────────────────────────────────
              const _SectionHeader(title: AppStrings.displaySettings),
              SwitchListTile(
                title: const Text('深色模式'),
                subtitle: const Text('切换应用主题'),
                value: s['darkMode'] ?? false,
                onChanged: (value) => context.read<SettingsCubit>().updateSetting('darkMode', value),
              ),

              const Divider(height: 32),

              // ── 数据管理 ──────────────────────────────────────
              const _SectionHeader(title: AppStrings.dataManagement),
              _SettingsTile(
                title: AppStrings.clearSearchHistory,
                trailing: const Icon(Icons.delete_outline, size: 20),
                onTap: () => _showClearHistoryConfirmation(context),
              ),

              // ── S-4: 出场模板 ─────────────────────────────────────
              const Divider(height: 32),
              const _SectionHeader(title: '出场模板'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('新增模板'),
                  onPressed: () => _showAddTemplateSheet(context),
                ),
              ),
              const SizedBox(height: 8),
              if (_exitTemplates.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('暂无模板，点击上方新增', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                )
              else
                ..._exitTemplates.expand((t) => [
                  _buildTemplateCard(context, t),
                  const Divider(height: 1),
                ]),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  // ─── S-4: 出场模板卡片 ───
  Widget _buildTemplateCard(BuildContext context, ExitTemplate t) {
    return Dismissible(
      key: Key(t.name),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDeleteTemplate(context, t.name),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        title: Text(t.name),
        subtitle: Text(
          '止损${t.stopLossPercent != null ? '${t.stopLossPercent}%' : '未设'}  '
          '止盈${t.takeProfitPercent != null ? '${t.takeProfitPercent}%' : '未设'}  '
          '时间止损${t.enableTimeExit ? '${t.maxHoldingDays}天' : '关'}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: TextButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('模板"${t.name}"已应用，请前往回测页面'),
                action: SnackBarAction(label: '去回测', onPressed: () => context.go('/backtest')),
              ),
            );
          },
          child: const Text('应用'),
        ),
      ),
    );
  }

  Future<bool> _confirmDeleteTemplate(BuildContext context, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除模板'),
        content: Text('确定删除模板"$name"吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await context.read<StockBloc>().stockStorage.deleteExitTemplate(name);
      _loadExitTemplates();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('模板"$name"已删除')));
      }
    }
    return false; // prevent default dismiss behavior
  }

  // ─── S-4: 新增模板 BottomSheet ───
  void _showAddTemplateSheet(BuildContext context) {
    final nameController = TextEditingController();
    final stopLossController = TextEditingController();
    final takeProfitController = TextEditingController();
    final maxDaysController = TextEditingController(text: '20');
    final slippageController = TextEditingController();
    bool enableTimeExit = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('新增出场模板', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '模板名称', hintText: '如：保守型',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: stopLossController,
                        decoration: const InputDecoration(
                          labelText: '止损%', hintText: '如：5',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: takeProfitController,
                        decoration: const InputDecoration(
                          labelText: '止盈%', hintText: '如：10',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('时间止损'),
                    Switch(
                      value: enableTimeExit,
                      onChanged: (v) => setSheetState(() => enableTimeExit = v),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: maxDaysController,
                        decoration: const InputDecoration(
                          labelText: '最大持仓(天)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: slippageController,
                        decoration: const InputDecoration(
                          labelText: '滑点‰',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;
                          final template = ExitTemplate(
                            name: name,
                            stopLossPercent: double.tryParse(stopLossController.text),
                            takeProfitPercent: double.tryParse(takeProfitController.text),
                            enableTimeExit: enableTimeExit,
                            maxHoldingDays: int.tryParse(maxDaysController.text) ?? 20,
                            slippagePercent: double.tryParse(slippageController.text),
                          );
                          await context.read<StockBloc>().stockStorage.saveExitTemplate(template);
                          _loadExitTemplates();
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('模板"$name"已保存')),
                            );
                          }
                        },
                        child: const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showClearHistoryConfirmation(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('清除搜索历史', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('为确认清除，请在下方输入"清除"', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '输入"清除"',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        if (controller.text == '清除') {
                          Navigator.pop(ctx);
                          await context.read<SettingsCubit>().clearSearchHistory();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('搜索历史已清除')),
                            );
                          }
                        }
                      },
                      child: const Text('确认'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPeriodPicker(BuildContext context, String key, int min, int max, int current) {
    int selected = current;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置周期'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Slider(
                  value: selected.toDouble(),
                  min: min.toDouble(),
                  max: max.toDouble(),
                  divisions: max - min,
                  label: '$selected',
                  onChanged: (value) => setState(() => selected = value.round()),
                ),
                Text('$selected', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              context.read<SettingsCubit>().updateSetting(key, selected);
              Navigator.pop(ctx);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _SettingsTile({required this.title, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}

/// Card-style group with subtle border and rounded corners.
class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(children: children),
    );
  }
}

/// Toggle switch tile inside a settings group.
class _SwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({required this.title, this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: subtitle != null ? Text(subtitle!, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)) : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      dense: true,
    );
  }
}

/// Slider tile inside a settings group.
class _SliderTile extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  const _SliderTile({required this.title, required this.value, required this.min, required this.max, this.divisions, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15)),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

/// Segmented button tile inside a settings group.
class _SegmentTile extends StatelessWidget {
  final String title;
  final String value;
  final Map<String, String> options; // key -> label
  final ValueChanged<String> onChanged;
  const _SegmentTile({required this.title, required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: options.entries
                .map((e) => ButtonSegment(value: e.key, label: Text(e.value, style: const TextStyle(fontSize: 12))))
                .toList(),
            selected: {value},
            onSelectionChanged: (s) => onChanged(s.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return AppColors.primary.withAlpha(40);
                return Colors.transparent;
              }),
            ),
          ),
        ],
      ),
    );
  }
}
