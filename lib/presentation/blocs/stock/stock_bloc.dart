import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/datasources/stock_api_service.dart';
import '../../../data/datasources/stock_local_storage.dart';
import '../../../domain/entities/stock_quote.dart';
import '../../../domain/usecases/calculators/macd_calculator.dart';
import '../../../domain/usecases/calculators/rsi_calculator.dart';
import '../../../domain/usecases/calculators/kdj_calculator.dart';
import '../../../domain/usecases/calculators/boll_calculator.dart';
import '../../../domain/usecases/calculators/ma_calculator.dart';
import '../../../domain/usecases/calculators/wr_calculator.dart';
import '../../../domain/usecases/calculators/dmi_calculator.dart';

// Events
abstract class StockEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadStock extends StockEvent {
  final String symbol;
  final String startDate;
  final String endDate;

  LoadStock(this.symbol, {this.startDate = '', this.endDate = ''});

  @override
  List<Object?> get props => [symbol, startDate, endDate];
}

class RefreshStock extends StockEvent {}

class ChangeDateRange extends StockEvent {
  final String startDate;
  final String endDate;

  ChangeDateRange(this.startDate, this.endDate);

  @override
  List<Object?> get props => [startDate, endDate];
}

// States
abstract class StockState extends Equatable {
  @override
  List<Object?> get props => [];
}

class StockInitial extends StockState {}

class StockLoading extends StockState {}

class StockLoaded extends StockState {
  final StockData stockData;
  final List<MacdData> macdData;
  final List<RsiData> rsiData;
  final List<KdjData> kdjData;
  final List<BollData> bollData;
  final List<MaData> maData;
  final List<WrData> wrData;
  final List<DmiData> dmiData;
  final MacdSignalResult? macdSignal;
  final String startDate;
  final String endDate;

  StockLoaded({
    required this.stockData,
    required this.macdData,
    required this.rsiData,
    required this.kdjData,
    required this.bollData,
    required this.maData,
    required this.wrData,
    required this.dmiData,
    this.macdSignal,
    required this.startDate,
    required this.endDate,
  });

  @override
  List<Object?> get props => [stockData, macdData, rsiData, kdjData, bollData, maData, wrData, dmiData, macdSignal, startDate, endDate];
}

class StockError extends StockState {
  final String message;

  StockError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class StockBloc extends Bloc<StockEvent, StockState> {
  final StockApiService apiService;
  final StockLocalStorage storage;

  String _currentSymbol = '';
  String _startDate = '';
  String _endDate = '';

  StockBloc({
    required this.apiService,
    required this.storage,
  }) : super(StockInitial()) {
    on<LoadStock>(_onLoadStock);
    on<RefreshStock>(_onRefreshStock);
    on<ChangeDateRange>(_onChangeDateRange);
  }

  Future<void> _onLoadStock(LoadStock event, Emitter<StockState> emit) async {
    emit(StockLoading());
    _currentSymbol = event.symbol;
    _startDate = event.startDate;
    _endDate = event.endDate;

    try {
      await storage.addToSearchHistory(event.symbol);
      final stockData = await apiService.getStockData(
        event.symbol,
        startDate: event.startDate,
        endDate: event.endDate,
      );

      if (stockData.quotes.isEmpty) {
        emit(StockError('暂无数据'));
        return;
      }

      final macdData = MacdCalculator.calculate(stockData.quotes);
      final rsiData = RsiCalculator.calculate(stockData.quotes);
      final kdjData = KdjCalculator.calculate(stockData.quotes);
      final bollData = BollCalculator.calculate(stockData.quotes);
      final maData = MaCalculator.calculate(stockData.quotes);
      final wrData = WrCalculator.calculate(stockData.quotes);
      final dmiData = DmiCalculator.calculate(stockData.quotes);
      final macdSignal = MacdCalculator.detectSignal(macdData);

      emit(StockLoaded(
        stockData: stockData,
        macdData: macdData,
        rsiData: rsiData,
        kdjData: kdjData,
        bollData: bollData,
        maData: maData,
        wrData: wrData,
        dmiData: dmiData,
        macdSignal: macdSignal,
        startDate: _startDate,
        endDate: _endDate,
      ));
    } catch (e) {
      emit(StockError(e.toString()));
    }
  }

  Future<void> _onRefreshStock(RefreshStock event, Emitter<StockState> emit) async {
    if (_currentSymbol.isNotEmpty) {
      add(LoadStock(_currentSymbol, startDate: _startDate, endDate: _endDate));
    }
  }

  Future<void> _onChangeDateRange(ChangeDateRange event, Emitter<StockState> emit) async {
    _startDate = event.startDate;
    _endDate = event.endDate;
    if (_currentSymbol.isNotEmpty) {
      add(LoadStock(_currentSymbol, startDate: _startDate, endDate: _endDate));
    }
  }
}
