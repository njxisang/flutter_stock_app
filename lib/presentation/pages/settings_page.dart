import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../blocs/settings/settings_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
                  value: !(s['hollowCandle'] ?? false),
                  onChanged: (v) => context.read<SettingsCubit>()
                      .updateSetting('hollowCandle', !v),
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
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('确认清除'),
                      content: const Text('将清除所有搜索历史'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('清除')),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    await context.read<SettingsCubit>().clearSearchHistory();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('搜索历史已清除')),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 32),
            ],
          );
        },
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
