import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/router/app_router.dart';
import 'data/datasources/stock_api_service.dart';
import 'data/datasources/stock_local_storage.dart';
import 'data/datasources/seat_history_service.dart';
import 'presentation/blocs/stock/stock_bloc.dart';
import 'presentation/blocs/chart/chart_state.dart';
import 'presentation/blocs/watchlist/watchlist_cubit.dart';
import 'presentation/blocs/settings/settings_cubit.dart';
import 'presentation/blocs/seat_tracker/seat_tracker_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final storage = StockLocalStorage(prefs);
  final apiService = StockApiService();
  final seatHistoryService = SeatHistoryService(prefs);

  runApp(MyApp(
    storage: storage,
    apiService: apiService,
    seatHistoryService: seatHistoryService,
  ));
}

class MyApp extends StatelessWidget {
  final StockLocalStorage storage;
  final StockApiService apiService;
  final SeatHistoryService seatHistoryService;

  const MyApp({
    super.key,
    required this.storage,
    required this.apiService,
    required this.seatHistoryService,
  });

  @override
  Widget build(BuildContext context) {
    final settingsState = SettingsState(settings: storage.getSettings());
    final isDark = settingsState.settings['darkMode'] ?? false;

    return MultiBlocProvider(
      providers: [
        BlocProvider<StockBloc>(
          create: (_) => StockBloc(apiService: apiService, storage: storage),
        ),
        BlocProvider<ChartCubit>(
          create: (_) => ChartCubit(),
        ),
        BlocProvider<WatchlistCubit>(
          create: (_) => WatchlistCubit(storage: storage),
        ),
        BlocProvider<SettingsCubit>(
          create: (_) => SettingsCubit(storage: storage),
        ),
        BlocProvider<SeatTrackerCubit>(
          create: (_) => SeatTrackerCubit(
            historyService: seatHistoryService,
            apiService: apiService,
          )..loadSeats(),
        ),
      ],
      child: MaterialApp.router(
        title: '股票MACD',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          brightness: isDark ? Brightness.dark : Brightness.light,
        ),
        routerConfig: AppRouter.router,
      ),
    );
  }
}
