import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/datasources/stock_local_storage.dart';
import '../../../domain/entities/stock_quote.dart';

// Sort options
enum WatchlistSort { addedTime, name, changePercent }

// States
class WatchlistState extends Equatable {
  final List<WatchlistItem> items;
  final Set<String> selectedItems;
  final bool isSelectionMode;
  final WatchlistSort sortBy;

  const WatchlistState({
    this.items = const [],
    this.selectedItems = const {},
    this.isSelectionMode = false,
    this.sortBy = WatchlistSort.addedTime,
  });

  List<WatchlistItem> get sortedItems {
    final list = List<WatchlistItem>.from(items);
    switch (sortBy) {
      case WatchlistSort.addedTime:
        return list;
      case WatchlistSort.name:
        list.sort((a, b) => a.name.compareTo(b.name));
        return list;
      case WatchlistSort.changePercent:
        // Fallback to name sort if no price data
        return list;
    }
  }

  WatchlistState copyWith({
    List<WatchlistItem>? items,
    Set<String>? selectedItems,
    bool? isSelectionMode,
    WatchlistSort? sortBy,
  }) {
    return WatchlistState(
      items: items ?? this.items,
      selectedItems: selectedItems ?? this.selectedItems,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  @override
  List<Object?> get props => [items, selectedItems, isSelectionMode, sortBy];
}

// Cubit
class WatchlistCubit extends Cubit<WatchlistState> {
  final StockLocalStorage storage;

  WatchlistCubit({required this.storage}) : super(const WatchlistState()) {
    loadWatchlist();
  }

  void loadWatchlist() {
    final items = storage.getWatchlist();
    emit(state.copyWith(items: items));
  }

  Future<void> addToWatchlist(String symbol, String name) async {
    await storage.addToWatchlist(symbol, name);
    loadWatchlist();
  }

  Future<void> removeFromWatchlist(String symbol) async {
    await storage.removeFromWatchlist(symbol);
    loadWatchlist();
  }

  void toggleSelectionMode() {
    emit(state.copyWith(
      isSelectionMode: !state.isSelectionMode,
      selectedItems: state.isSelectionMode ? {} : state.selectedItems,
    ));
  }

  void toggleSelection(String symbol) {
    final newSelected = Set<String>.from(state.selectedItems);
    if (newSelected.contains(symbol)) {
      newSelected.remove(symbol);
    } else {
      newSelected.add(symbol);
    }
    emit(state.copyWith(selectedItems: newSelected));
  }

  void clearSelection() {
    emit(state.copyWith(selectedItems: {}));
  }

  void setSortBy(WatchlistSort sort) {
    emit(state.copyWith(sortBy: sort));
  }

  List<String> getSelectedSymbols() {
    return state.selectedItems.toList();
  }
}
