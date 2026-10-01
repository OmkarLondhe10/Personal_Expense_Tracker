import 'package:flutter/material.dart';
import 'package:personal_expense_tracker/features/transaction/widget/transaction_tile.dart';
import 'package:personal_expense_tracker/provider/transaction_provider.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // 0: All (Combined), 1: Online, 2: Offline
  int _selectedModeIndex = 0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();

    // Current displayed amounts depending on selected filter
    final double displayedBalance;
    final double displayedIncome;
    final double displayedExpense;
    final String balanceTitle;

    switch (_selectedModeIndex) {
      case 1:
        displayedBalance = provider.onlineBalance;
        displayedIncome = provider.onlineIncome;
        displayedExpense = provider.onlineExpense;
        balanceTitle = "Online Balance";
        break;
      case 2:
        displayedBalance = provider.offlineBalance;
        displayedIncome = provider.offlineIncome;
        displayedExpense = provider.offlineExpense;
        balanceTitle = "Offline Balance";
        break;
      case 0:
      default:
        displayedBalance = provider.balance;
        displayedIncome = provider.totalIncome;
        displayedExpense = provider.totalExpense;
        balanceTitle = "Total Balance (Combined)";
        break;
    }

    // Filter recent transactions based on mode selection
    final allRecent = provider.recentTransactions;
    final recent = _selectedModeIndex == 0
        ? allRecent
        : allRecent.where((t) => _selectedModeIndex == 1 ? t.isOnline : !t.isOnline).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // MODE SELECTOR SEGMENT (All, Online, Offline)
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(
                    value: 0,
                    label: Text('All'),
                    icon: Icon(Icons.all_inclusive, size: 16),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text('Online'),
                    icon: Icon(Icons.credit_card_outlined, size: 16),
                  ),
                  ButtonSegment<int>(
                    value: 2,
                    label: Text('Offline'),
                    icon: Icon(Icons.payments_outlined, size: 16),
                  ),
                ],
                selected: {_selectedModeIndex},
                onSelectionChanged: (set) {
                  setState(() {
                    _selectedModeIndex = set.first;
                  });
                },
              ),
            ),

            const SizedBox(height: 16),

            // TOTAL BALANCE HERO CARD
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primaryContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    balanceTitle,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${displayedBalance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 12),
                  // Breakdown row inside card
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.credit_card_outlined, color: Colors.white70, size: 18),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Online Net', style: TextStyle(fontSize: 11, color: Colors.white70)),
                                Text(
                                  '₹${provider.onlineBalance.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(height: 26, width: 1, color: Colors.white24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.payments_outlined, color: Colors.white70, size: 18),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Offline Net', style: TextStyle(fontSize: 11, color: Colors.white70)),
                                Text(
                                  '₹${provider.offlineBalance.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // INCOME & EXPENSE ROW
            Row(
              children: [
                Expanded(
                  child: _buildCard(
                    context,
                    title: _selectedModeIndex == 0
                        ? "Income"
                        : (_selectedModeIndex == 1 ? "Online Income" : "Offline Income"),
                    amount: displayedIncome,
                    color: Colors.green,
                    icon: Icons.arrow_downward,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCard(
                    context,
                    title: _selectedModeIndex == 0
                        ? "Expense"
                        : (_selectedModeIndex == 1 ? "Online Expense" : "Offline Expense"),
                    amount: displayedExpense,
                    color: Colors.red,
                    icon: Icons.arrow_upward,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ONLINE VS OFFLINE COMPARISON SUMMARY CARD
            _buildModeComparisonCard(context, provider),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Transactions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_selectedModeIndex != 0)
                  Text(
                    _selectedModeIndex == 1 ? 'Showing Online' : 'Showing Offline',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            if (recent.isEmpty)
              Column(
                children: const [
                  SizedBox(height: 30),
                  Icon(Icons.receipt_long, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text(
                    'No Transactions Yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              )
            else
              ...recent.map((e) => TransactionTile(transaction: e)),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeComparisonCard(BuildContext context, TransactionProvider provider) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Payment Breakdown Summary",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Online Summary Column
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.credit_card_outlined, size: 14, color: Colors.blue),
                          SizedBox(width: 4),
                          Text(
                            "Online",
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Spent: ₹${provider.onlineExpense.toStringAsFixed(0)}",
                        style: const TextStyle(fontSize: 11, color: Colors.red),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Income: ₹${provider.onlineIncome.toStringAsFixed(0)}",
                        style: const TextStyle(fontSize: 11, color: Colors.green),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Net: ₹${provider.onlineBalance.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Offline Summary Column
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.payments_outlined, size: 14, color: Colors.orange.shade800),
                          const SizedBox(width: 4),
                          Text(
                            "Offline",
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Spent: ₹${provider.offlineExpense.toStringAsFixed(0)}",
                        style: const TextStyle(fontSize: 11, color: Colors.red),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Income: ₹${provider.offlineIncome.toStringAsFixed(0)}",
                        style: const TextStyle(fontSize: 11, color: Colors.green),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Net: ₹${provider.offlineBalance.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}