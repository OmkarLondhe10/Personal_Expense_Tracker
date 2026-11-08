import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/transaction_model.dart';
import '../../provider/transaction_provider.dart';
import '../transaction/screen/add_transaction.dart';
import '../transaction/widget/transaction_tile.dart';

class MonthlyTransactionsScreen extends StatelessWidget {
  final DateTime month;
  final VoidCallback? onSelectForDashboard;

  const MonthlyTransactionsScreen({
    super.key,
    required this.month,
    this.onSelectForDashboard,
  });

  void _confirmDeleteAll(BuildContext context, TransactionProvider provider, int count) {
    final monthName = DateFormat('MMMM yyyy').format(month);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $monthName Transactions?'),
        content: Text(
          'Are you sure you want to delete all $count transaction(s) recorded in $monthName?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              provider.deleteTransactionsForMonth(month);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('All transactions for $monthName have been deleted.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSingle(
    BuildContext context,
    TransactionProvider provider,
    TransactionModel tx,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: Text(
          'Delete "${tx.category}" (₹${tx.amount.toStringAsFixed(2)})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              provider.deleteTransaction(tx.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Transaction deleted.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final transactions = provider.getMonthlyTransactions(month);
    final monthName = DateFormat('MMMM yyyy').format(month);

    final expense = provider.getMonthlyExpense(month);
    final income = provider.getMonthlyIncome(month);
    final net = income - expense;
    final onlineExpense = provider.getMonthlyOnlineExpense(month);
    final offlineExpense = provider.getMonthlyOfflineExpense(month);

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(monthName),
        centerTitle: true,
        actions: [
          if (transactions.isNotEmpty)
            IconButton(
              tooltip: 'Delete All Transactions for $monthName',
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
              onPressed: () => _confirmDeleteAll(context, provider, transactions.length),
            ),
        ],
      ),
      body: transactions.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.folder_open_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Transactions in $monthName',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All transactions for this month have either been deleted or none were recorded.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // MONTH SUMMARY HERO CARD
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primaryContainer,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Monthly Net Balance',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${transactions.length} items',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '₹${net.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Divider(color: Colors.white24, height: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatItem('Spent', '₹${expense.toStringAsFixed(0)}', Colors.white),
                          _buildStatItem('Income', '₹${income.toStringAsFixed(0)}', Colors.white),
                          _buildStatItem('Online', '₹${onlineExpense.toStringAsFixed(0)}', Colors.white70),
                          _buildStatItem('Offline', '₹${offlineExpense.toStringAsFixed(0)}', Colors.white70),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // OPTIONAL VIEW ON DASHBOARD BUTTON
                if (onSelectForDashboard != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.dashboard_outlined, size: 18),
                    label: Text('View $monthName on Dashboard'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      onSelectForDashboard!();
                      Navigator.pop(context);
                    },
                  ),

                const SizedBox(height: 16),

                // TRANSACTIONS HEADER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Transactions (${transactions.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Swipe left to delete',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // TRANSACTIONS LIST
                ...transactions.map((tx) {
                  return Dismissible(
                    key: ValueKey(tx.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Transaction?'),
                          content: Text(
                            'Are you sure you want to delete this ${tx.category} transaction?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (direction) {
                      provider.deleteTransaction(tx.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Transaction deleted.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: theme.dividerColor.withValues(alpha: 0.15),
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddTransactionScreen(
                                transaction: tx,
                              ),
                            ),
                          );
                        },
                        onLongPress: () => _confirmDeleteSingle(context, provider, tx),
                        child: TransactionTile(transaction: tx),
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

