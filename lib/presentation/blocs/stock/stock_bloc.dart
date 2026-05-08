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
  StockLocalStorage get stockStorage => storage;

  String _currentSymbol = '';
  String _startDate = '';
  String _endDate = '';
  String _computedParamsHash = '';
  String _computedDataHash = '';

  StockBloc({
    required this.apiService,
    required this.storage,
  }) : super(StockInitial()) {
    on<LoadStock>(_onLoadStock);
    on<RefreshStock>(_onRefreshStock);
    on<ChangeDateRange>(_onChangeDateRange);
  }

  /// 从Settings读取指标周期参数（Fix #1: 统一参数来源）
  Map<String, dynamic> get _indicatorParams {
    final settings = storage.getSettings();
    return {
      'shortPeriod':  settings['shortPeriod'] ?? 12,
      'longPeriod':   settings['longPeriod']  ?? 26,
      'signalPeriod': settings['signalPeriod'] ?? 9,
      'rsiPeriod':    settings['rsiPeriod']   ?? 6,
      'kdjPeriod':    settings['kdjPeriod']   ?? 9,
      'bollPeriod':   settings['bollPeriod']  ?? 20,
    };
  }

  /// 计算参数Hash，用于检测参数是否变化
  String _computeParamsHash(Map<String, dynamic> params) {
    return '${params['shortPeriod']}_${params['longPeriod']}_${params['signalPeriod']}_'
           '${params['rsiPeriod']}_${params['kdjPeriod']}_${params['bollPeriod']}';
  }

  /// 计算数据Hash，用于检测数据是否变化
  String _computeDataHash(StockData stockData) {
    // 使用数据长度 + 最后一条数据的时间戳作为hash
    if (stockData.quotes.isEmpty) return '';
    final lastQuote = stockData.quotes.last;
    return '${stockData.quotes.length}_${lastQuote.date}';
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

      // Fix #2: 从Settings读取参数，而非硬编码默认值
      final params = _indicatorParams;
      final paramsHash = _computeParamsHash(params);
      final dataHash = _computeDataHash(stockData);

      // Fix #2: 检测参数和数据是否变化，如无变化则跳过指标计算
      final combinedHash = '${event.symbol}_${dataHash}_$paramsHash';
      if (combinedHash == _computedParamsHash && state is StockLoaded) {
        // 数据和参数未变化，保留当前状态
        return;
      }
      _computedParamsHash = combinedHash;
      _computedDataHash = dataHash;

      // Fix #2: 使用Future.wait()并行计算所有指标（除MACD信号检测外，因为它依赖macdData）
      final results = await Future.wait([
        Future(() => MacdCalculator.calculate(
          stockData.quotes,
          shortPeriod: params['shortPeriod'] as int,
          longPeriod: params['longPeriod'] as int,
          signalPeriod: params['signalPeriod'] as int,
        )),
        Future(() => RsiCalculator.calculate(
          stockData.quotes,
          period: params['rsiPeriod'] as int,
        )),
        Future(() => KdjCalculator.calculate(
          stockData.quotes,
          period: params['kdjPeriod'] as int,
        )),
        Future(() => BollCalculator.calculate(
          stockData.quotes,
          period: params['bollPeriod'] as int,
        )),
        Future(() => MaCalculator.calculate(stockData.quotes)),
        Future(() => WrCalculator.calculate(stockData.quotes)),
        Future(() => DmiCalculator.calculate(stockData.quotes)),
      ]);

      final macdData = results[0] as List<MacdData>;
      final rsiData = results[1] as List<RsiData>;
      final kdjData = results[2] as List<KdjData>;
      final bollData = results[3] as List<BollData>;
      final maData = results[4] as List<MaData>;
      final wrData = results[5] as List<WrData>;
      final dmiData = results[6] as List<DmiData>;

      // MACD信号检测必须在macdData计算完成后进行（顺序依赖）
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
