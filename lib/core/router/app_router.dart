import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/pages/main_page.dart';
import '../../presentation/pages/watchlist_page.dart';
import '../../presentation/pages/history_page.dart';
import '../../presentation/pages/backtest_page.dart';
import '../../presentation/pages/analysis_page.dart';
import '../../presentation/pages/signal_analysis_page.dart';
import '../../presentation/pages/risk_analysis_page.dart';
import '../../presentation/pages/prediction_page.dart';
import '../../presentation/pages/turtle_trading_page.dart';
import '../../presentation/pages/portfolio_analysis_page.dart';
import '../../presentation/pages/settings_page.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return ScaffoldWithNav(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MainPage(),
            ),
          ),
          GoRoute(
            path: '/watchlist',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: WatchlistPage(),
            ),
          ),
          GoRoute(
            path: '/history',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HistoryPage(),
            ),
          ),
          GoRoute(
            path: '/backtest',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: BacktestPage(),
            ),
          ),
        ],
      ),
      // Analysis sub-pages (outside ShellRoute so no BottomNav)
      GoRoute(
        path: '/analysis',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AnalysisPage(),
        routes: [
          GoRoute(
            path: 'signal',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const SignalAnalysisPage(),
          ),
          GoRoute(
            path: 'risk',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const RiskAnalysisPage(),
          ),
          GoRoute(
            path: 'prediction',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const PredictionPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/turtle',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TurtleTradingPage(),
      ),
      GoRoute(
        path: '/portfolio',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PortfolioAnalysisPage(),
      ),
    ],
  );
}

class ScaffoldWithNav extends StatefulWidget {
  final Widget child;

  const ScaffoldWithNav({super.key, required this.child});

  @override
  State<ScaffoldWithNav> createState() => _ScaffoldWithNavState();
}

class _ScaffoldWithNavState extends State<ScaffoldWithNav> {
  int _currentIndex = 0;

  static const _routes = ['/', '/watchlist', '/history', '/backtest'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateSelectedIndex(context),
        onDestinationSelected: (index) => _onItemTapped(context, index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.show_chart), label: '图表'),
          NavigationDestination(icon: Icon(Icons.star), label: '自选'),
          NavigationDestination(icon: Icon(Icons.history), label: '历史'),
          NavigationDestination(icon: Icon(Icons.play_arrow), label: '回测'),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/watchlist')) return 1;
    if (location.startsWith('/history')) return 2;
    if (location.startsWith('/backtest')) return 3;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
    context.go(_routes[index]);
  }
}
