import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../blocs/watchlist/watchlist_cubit.dart';
import '../blocs/stock/stock_bloc.dart';

class WatchlistPage extends StatelessWidget {
  const WatchlistPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('自选股'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索股票',
            onPressed: () => context.go('/'),
          ),
          PopupMenuButton<WatchlistSort>(
            icon: const Icon(Icons.sort),
            tooltip: '排序',
            onSelected: (sort) => context.read<WatchlistCubit>().setSortBy(sort),
            itemBuilder: (ctx) {
              final current = ctx.read<WatchlistCubit>().state.sortBy;
              return [
                PopupMenuItem(
                  value: WatchlistSort.addedTime,
                  child: Row(
                    children: [
                      if (current == WatchlistSort.addedTime) const Icon(Icons.check, size: 18),
                      const SizedBox(width: 8),
                      const Text('添加时间'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: WatchlistSort.name,
                  child: Row(
                    children: [
                      if (current == WatchlistSort.name) const Icon(Icons.check, size: 18),
                      const SizedBox(width: 8),
                      const Text('名称'),
                    ],
                  ),
                ),
              ];
            },
          ),
          BlocBuilder<WatchlistCubit, WatchlistState>(
            builder: (context, state) {
              if (state.isSelectionMode) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${state.selectedItems.length}'),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => context.read<WatchlistCubit>().toggleSelectionMode(),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocBuilder<WatchlistCubit, WatchlistState>(
        builder: (context, state) {
          if (state.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star_border, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('暂无自选股', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('在图表页面搜索并添加', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/'),
                    child: const Text('去搜索'),
                  ),
                ],
              ),
            );
          }

          final sortedItems = state.sortedItems;
          return ListView.builder(
            itemCount: sortedItems.length,
            itemBuilder: (context, index) {
              final item = sortedItems[index];
              final isSelected = state.selectedItems.contains(item.symbol);

              return Dismissible(
                key: Key(item.symbol),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) {
                  context.read<WatchlistCubit>().removeFromWatchlist(item.symbol);
                },
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(item.symbol.substring(0, item.symbol.length > 2 ? 2 : item.symbol.length)),
                  ),
                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(item.symbol, style: const TextStyle(fontSize: 11)),
                  trailing: state.isSelectionMode
                      ? Checkbox(value: isSelected, onChanged: (_) => context.read<WatchlistCubit>().toggleSelection(item.symbol))
                      : const Icon(Icons.chevron_right),
                  onTap: () {
                    if (state.isSelectionMode) {
                      context.read<WatchlistCubit>().toggleSelection(item.symbol);
                    } else {
                      context.read<StockBloc>().add(LoadStock(item.symbol));
                      context.go('/');
                    }
                  },
                  onLongPress: () {
                    if (!state.isSelectionMode) {
                      context.read<WatchlistCubit>().toggleSelectionMode();
                      context.read<WatchlistCubit>().toggleSelection(item.symbol);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: BlocBuilder<WatchlistCubit, WatchlistState>(
        builder: (context, state) {
          if (state.selectedItems.length >= 2 && !state.isSelectionMode) {
            return FloatingActionButton(
              onPressed: () {
                context.read<WatchlistCubit>().toggleSelectionMode();
              },
              child: const Icon(Icons.compare_arrows),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
