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
          return ListView(
            children: [
              const _SectionHeader(title: '指标参数'),
              _SettingsTile(
                title: 'MACD 短期周期',
                trailing: Text('${state.settings['shortPeriod']}'),
                onTap: () => _showPeriodPicker(context, 'shortPeriod', 5, 20, state.settings['shortPeriod']),
              ),
              _SettingsTile(
                title: 'MACD 长期周期',
                trailing: Text('${state.settings['longPeriod']}'),
                onTap: () => _showPeriodPicker(context, 'longPeriod', 15, 60, state.settings['longPeriod']),
              ),
              _SettingsTile(
                title: 'MACD 信号周期',
                trailing: Text('${state.settings['signalPeriod']}'),
                onTap: () => _showPeriodPicker(context, 'signalPeriod', 5, 15, state.settings['signalPeriod']),
              ),
              _SettingsTile(
                title: 'RSI 周期',
                trailing: Text('${state.settings['rsiPeriod']}'),
                onTap: () => _showPeriodPicker(context, 'rsiPeriod', 6, 21, state.settings['rsiPeriod']),
              ),
              _SettingsTile(
                title: 'KDJ 周期',
                trailing: Text('${state.settings['kdjPeriod']}'),
                onTap: () => _showPeriodPicker(context, 'kdjPeriod', 5, 20, state.settings['kdjPeriod']),
              ),
              _SettingsTile(
                title: 'BOLL 周期',
                trailing: Text('${state.settings['bollPeriod']}'),
                onTap: () => _showPeriodPicker(context, 'bollPeriod', 10, 30, state.settings['bollPeriod']),
              ),
              const Divider(),
              const _SectionHeader(title: '显示设置'),
              SwitchListTile(
                title: const Text('深色模式'),
                subtitle: const Text('切换应用主题'),
                value: state.settings['darkMode'] ?? false,
                onChanged: (value) {
                  context.read<SettingsCubit>().updateSetting('darkMode', value);
                },
              ),
              const Divider(),
              const _SectionHeader(title: '数据管理'),
              _SettingsTile(
                title: '清除搜索历史',
                trailing: const Icon(Icons.delete_outline, size: 20),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('确认清除'),
                      content: const Text('将清除所有搜索历史'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('清除'),
                        ),
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
