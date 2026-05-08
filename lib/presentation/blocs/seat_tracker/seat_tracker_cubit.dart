import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/datasources/seat_history_service.dart';
import '../../../data/datasources/lhb_api_service.dart';

// ============ State ============

class SeatTrackerState extends Equatable {
  final List<String> trackedSeats;
  final Map<String, SeatStats> seatStats;      // 席位 -> 统计
  final Map<String, List<SeatOperation>> seatHistory;  // 席位 -> 最近操作
  final Map<String, List<SeatOperation>> newPositions; // 席位 -> 今日新建仓
  final bool isLoading;
  final String? selectedSeat;
  final String? lastUpdateTime;

  const SeatTrackerState({
    this.trackedSeats = const [],
    this.seatStats = const {},
    this.seatHistory = const {},
    this.newPositions = const {},
    this.isLoading = false,
    this.selectedSeat,
    this.lastUpdateTime,
  });

  SeatTrackerState copyWith({
    List<String>? trackedSeats,
    Map<String, SeatStats>? seatStats,
    Map<String, List<SeatOperation>>? seatHistory,
    Map<String, List<SeatOperation>>? newPositions,
    bool? isLoading,
    String? selectedSeat,
    String? lastUpdateTime,
  }) {
    return SeatTrackerState(
      trackedSeats: trackedSeats ?? this.trackedSeats,
      seatStats: seatStats ?? this.seatStats,
      seatHistory: seatHistory ?? this.seatHistory,
      newPositions: newPositions ?? this.newPositions,
      isLoading: isLoading ?? this.isLoading,
      selectedSeat: selectedSeat ?? this.selectedSeat,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
    );
  }

  @override
  List<Object?> get props => [trackedSeats, seatStats, seatHistory, newPositions, isLoading, selectedSeat, lastUpdateTime];
}

// ============ Cubit ============

class SeatTrackerCubit extends Cubit<SeatTrackerState> {
  final SeatHistoryService _historyService;
  final LhbApiService _lhbApiService;

  SeatTrackerCubit({
    required SeatHistoryService historyService,
    required LhbApiService lhbApiService,
  })  : _historyService = historyService,
        _lhbApiService = lhbApiService,
        super(const SeatTrackerState());

  /// 初始化：加载追踪席位列表
  void loadSeats() {
    final seats = _historyService.getTrackedSeats();
    emit(state.copyWith(trackedSeats: seats));
    // 默认选中第一个
    if (seats.isNotEmpty && state.selectedSeat == null) {
      selectSeat(seats.first);
    }
  }

  /// 刷新今日龙虎榜并记录
  Future<void> refreshToday({bool keepSelection = true}) async {
    emit(state.copyWith(isLoading: true));

    try {
      final today = _todayStr();
      final entries = await _lhbApiService.getLhbData(date: today);

      if (entries.isNotEmpty) {
        // 批量写入存储
        await _historyService.recordLhbEntries(entries);
      }

      // 重新加载所有席位的统计数据
      await _reloadAllSeatData(keepSelection);

      emit(state.copyWith(
        isLoading: false,
        lastUpdateTime: DateTime.now().toString().substring(0, 19),
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false));
    }
  }

  /// 选择某个席位查看详情
  void selectSeat(String seat) {
    if (state.selectedSeat == seat) return;

    final history = _historyService.getSeatHistory(seat);
    final stats = _historyService.getSeatStats(seat);
    final newPos = _historyService.getNewPositions(seat);

    final newHistory = Map<String, List<SeatOperation>>.from(state.seatHistory);
    newHistory[seat] = history.take(20).toList();

    final newStats = Map<String, SeatStats>.from(state.seatStats);
    newStats[seat] = stats;

    final newNewPos = Map<String, List<SeatOperation>>.from(state.newPositions);
    newNewPos[seat] = newPos;

    emit(state.copyWith(
      selectedSeat: seat,
      seatHistory: newHistory,
      seatStats: newStats,
      newPositions: newNewPos,
    ));
  }

  /// 添加追踪席位
  Future<void> addSeat(String seat) async {
    await _historyService.addTrackedSeat(seat);
    final seats = _historyService.getTrackedSeats();
    emit(state.copyWith(trackedSeats: seats));
    selectSeat(seat);
  }

  /// 移除追踪席位
  Future<void> removeSeat(String seat) async {
    await _historyService.removeTrackedSeat(seat);
    final seats = _historyService.getTrackedSeats();
    final newStats = Map<String, SeatStats>.from(state.seatStats);
    newStats.remove(seat);
    final newHistory = Map<String, List<SeatOperation>>.from(state.seatHistory);
    newHistory.remove(seat);

    String? newSelected = state.selectedSeat;
    if (state.selectedSeat == seat) {
      newSelected = seats.isNotEmpty ? seats.first : null;
      if (newSelected != null) selectSeat(newSelected);
    }

    emit(state.copyWith(
      trackedSeats: seats,
      selectedSeat: newSelected,
      seatStats: newStats,
      seatHistory: newHistory,
    ));
  }

  // ============ 内部方法 ============

  Future<void> _reloadAllSeatData(bool keepSelection) async {
    final seats = _historyService.getTrackedSeats();
    final statsMap = <String, SeatStats>{};
    final historyMap = <String, List<SeatOperation>>{};
    final newPosMap = <String, List<SeatOperation>>{};

    for (final seat in seats) {
      statsMap[seat] = _historyService.getSeatStats(seat);
      historyMap[seat] = _historyService.getSeatHistory(seat).take(20).toList();
      newPosMap[seat] = _historyService.getNewPositions(seat);
    }

    emit(state.copyWith(
      trackedSeats: seats,
      seatStats: statsMap,
      seatHistory: historyMap,
      newPositions: newPosMap,
    ));

    if (keepSelection && state.selectedSeat != null) {
      // 刷新已选中席位的最新数据
      selectSeat(state.selectedSeat!);
    }
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
