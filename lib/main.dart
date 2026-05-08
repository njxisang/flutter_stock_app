import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_constants.dart';
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
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.background,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
            error: AppColors.error,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            color: AppColors.cardBackground,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border, width: 0.5),
            ),
          ),
          dividerTheme: const DividerThemeData(
            color: AppColors.divider,
            thickness: 0.5,
          ),
        ),
        routerConfig: AppRouter.router,
      ),
    );
  }
}
