import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// States
class ChartState extends Equatable {
  final int currentTab;
  final int shortPeriod;
  final int longPeriod;
  final int signalPeriod;
  final int rsiPeriod;
  final int kdjPeriod;
  final int bollPeriod;

  const ChartState({
    this.currentTab = 0,
    this.shortPeriod = 12,
    this.longPeriod = 26,
    this.signalPeriod = 9,
    this.rsiPeriod = 6,
    this.kdjPeriod = 9,
    this.bollPeriod = 20,
  });

  ChartState copyWith({
    int? currentTab,
    int? shortPeriod,
    int? longPeriod,
    int? signalPeriod,
    int? rsiPeriod,
    int? kdjPeriod,
    int? bollPeriod,
  }) {
    return ChartState(
      currentTab: currentTab ?? this.currentTab,
      shortPeriod: shortPeriod ?? this.shortPeriod,
      longPeriod: longPeriod ?? this.longPeriod,
      signalPeriod: signalPeriod ?? this.signalPeriod,
      rsiPeriod: rsiPeriod ?? this.rsiPeriod,
      kdjPeriod: kdjPeriod ?? this.kdjPeriod,
      bollPeriod: bollPeriod ?? this.bollPeriod,
    );
  }

  @override
  List<Object?> get props => [currentTab, shortPeriod, longPeriod, signalPeriod, rsiPeriod, kdjPeriod, bollPeriod];
}

// Cubit
class ChartCubit extends Cubit<ChartState> {
  ChartCubit() : super(const ChartState());

  void changeTab(int tabIndex) {
    emit(state.copyWith(currentTab: tabIndex));
  }

  void updatePeriods({
    int? shortPeriod,
    int? longPeriod,
    int? signalPeriod,
    int? rsiPeriod,
    int? kdjPeriod,
    int? bollPeriod,
  }) {
    emit(state.copyWith(
      shortPeriod: shortPeriod,
      longPeriod: longPeriod,
      signalPeriod: signalPeriod,
      rsiPeriod: rsiPeriod,
      kdjPeriod: kdjPeriod,
      bollPeriod: bollPeriod,
    ));
  }
}
