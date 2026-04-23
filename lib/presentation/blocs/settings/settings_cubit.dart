import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/datasources/stock_local_storage.dart';

// State
class SettingsState extends Equatable {
  final Map<String, dynamic> settings;

  const SettingsState({required this.settings});

  @override
  List<Object?> get props => [settings];
}

// Cubit
class SettingsCubit extends Cubit<SettingsState> {
  final StockLocalStorage storage;

  SettingsCubit({required this.storage}) : super(SettingsState(settings: storage.getSettings()));

  void updateSetting(String key, dynamic value) {
    final newSettings = Map<String, dynamic>.from(state.settings);
    newSettings[key] = value;
    storage.saveSettings(newSettings);
    emit(SettingsState(settings: newSettings));
  }

  Future<void> clearSearchHistory() async {
    await storage.clearSearchHistory();
  }
}
