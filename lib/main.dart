import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/datasources/stock_api_service.dart';
import 'data/datasources/stock_local_storage.dart';
import 'presentation/blocs/stock/stock_bloc.dart';
import 'presentation/blocs/chart/chart_state.dart';
import 'presentation/blocs/watchlist/watchlist_cubit.dart';
import 'presentation/pages/main_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final storage = StockLocalStorage(prefs);
  final apiService = StockApiService();

  runApp(MyApp(
    storage: storage,
    apiService: apiService,
  ));
}

class MyApp extends StatelessWidget {
  final StockLocalStorage storage;
  final StockApiService apiService;

  const MyApp({
    super.key,
    required this.storage,
    required this.apiService,
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
      ],
      child: MaterialApp(
        title: '股票MACD',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const MainPage(),
      ),
    );
  }
}
