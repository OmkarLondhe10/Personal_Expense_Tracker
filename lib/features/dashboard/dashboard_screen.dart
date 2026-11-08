import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_expense_tracker/features/dashboard/monthly_transactions_screen.dart';
import 'package:personal_expense_tracker/features/transaction/screen/add_transaction.dart';
import 'package:personal_expense_tracker/features/transaction/widget/transaction_tile.dart';
import 'package:personal_expense_tracker/models/transaction_filter_model.dart';
import 'package:personal_expense_tracker/models/transaction_model.dart';
import 'package:personal_expense_tracker/provider/transaction_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // 0: All (Combined), 1: Online, 2: Offline
  int _selectedModeIndex = 0;

  // Defaults to This Month (start of month to end of month)
  TransactionDateFilter _selectedFilter = TransactionDateFilter.thisMonth;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTimeRange? _customRange;

  // Tracks calendar month rollover to auto-reset filter upon new month arrival
  DateTime _currentMonthTracker = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _checkAndResetForNewMonth();
    _checkStoredMonthRoll();
  }

  void _checkAndResetForNewMonth() {
    final now = DateTime.now();
    final current = DateTime(now.year, now.month);
    if (_currentMonthTracker.year != current.year ||
        _currentMonthTracker.month != current.month) {
      _currentMonthTracker = current;
      _selectedMonth = current;
      _selectedFilter = TransactionDateFilter.thisMonth;
      _customRange = null;
    }
  }

  Future<void> _checkStoredMonthRoll() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final currentKey = '${now.year}-${now.month}';
    final storedKey = prefs.getString('last_active_calendar_month');
    if (storedKey != null && storedKey != currentKey) {
      if (mounted) {
        setState(() {
          _currentMonthTracker = DateTime(now.year, now.month);
          _resetToCurrentMonth();
        });
      }
    }
    await prefs.setString('last_active_calendar_month', currentKey);
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  bool get _isDefaultMonthly =>
      _selectedFilter == TransactionDateFilter.thisMonth &&
      _isCurrentMonth &&
      _customRange == null;

  bool get isDefaultMonthly => _isDefaultMonthly;

  void _resetToCurrentMonth() {
    final now = DateTime.now();
    setState(() {
      _selectedFilter = TransactionDateFilter.thisMonth;
      _customRange = null;
      _selectedMonth = DateTime(now.year, now.month);
    });
  }

  @override
  Widget build(BuildContext context) {
    _checkAndResetForNewMonth();
    final provider = context.watch<TransactionProvider>();

    final filterRange = _selectedFilter == TransactionDateFilter.thisMonth
        ? TransactionDateFilter.getMonthRange(_selectedMonth)
        : _selectedFilter.getDateRange(customRange: _customRange);

    // Apply date filter (Default: Last 30 days)
    final dateFilteredTransactions = filterRange == null
        ? List<TransactionModel>.from(provider.transactions)
        : provider.transactions.where((tx) {
            return !tx.date.isBefore(filterRange.start) &&
                !tx.date.isAfter(filterRange.end);
          }).toList();

    // Summary calculations for filtered date range
    final filteredIncome = dateFilteredTransactions
        .where((t) => t.isIncome)
        .fold(0.0, (sum, t) => sum + t.amount);

    final filteredExpense = dateFilteredTransactions
        .where((t) => !t.isIncome)
        .fold(0.0, (sum, t) => sum + t.amount);

    final filteredBalance = filteredIncome - filteredExpense;

    final onlineIncome = dateFilteredTransactions
        .where((t) => t.isIncome && t.isOnline)
        .fold(0.0, (sum, t) => sum + t.amount);

    final onlineExpense = dateFilteredTransactions
        .where((t) => !t.isIncome && t.isOnline)
        .fold(0.0, (sum, t) => sum + t.amount);

    final onlineBalance = onlineIncome - onlineExpense;

    final offlineIncome = dateFilteredTransactions
        .where((t) => t.isIncome && !t.isOnline)
        .fold(0.0, (sum, t) => sum + t.amount);

    final offlineExpense = dateFilteredTransactions
        .where((t) => !t.isIncome && !t.isOnline)
        .fold(0.0, (sum, t) => sum + t.amount);

    final offlineBalance = offlineIncome - offlineExpense;

    // Current displayed amounts depending on selected payment mode filter
    final double displayedBalance;
    final double displayedIncome;
    final double displayedExpense;
    final String balanceTitle;

    switch (_selectedModeIndex) {
      case 1:
        displayedBalance = onlineBalance;
        displayedIncome = onlineIncome;
        displayedExpense = onlineExpense;
        balanceTitle = "Online Balance";
        break;
      case 2:
        displayedBalance = offlineBalance;
        displayedIncome = offlineIncome;
        displayedExpense = offlineExpense;
        balanceTitle = "Offline Balance";
        break;
      case 0:
      default:
        displayedBalance = filteredBalance;
        displayedIncome = filteredIncome;
        displayedExpense = filteredExpense;
        balanceTitle = "Total Balance (Combined)";
        break;
    }

    // Filter recent transactions based on payment mode and sort descending by date
    final modeFiltered = _selectedModeIndex == 0
        ? dateFilteredTransactions
        : dateFilteredTransactions
            .where((t) => _selectedModeIndex == 1 ? t.isOnline : !t.isOnline)
            .toList();

    modeFiltered.sort((a, b) => b.date.compareTo(a.date));
    final recent = modeFiltered.take(10).toList();

    return Scaffold(
      drawer: _buildDrawer(context, provider),
      appBar: AppBar(
        title: const Text("Dashboard"),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Filter by Date / Calendar",
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.calendar_month_outlined),
                if (!isDefaultMonthly)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => _showCalendarOptions(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.load();
          setState(() {});
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              // If viewing an archived month or custom timeframe from drawer, show a clean dismissible notification
              if (!isDefaultMonthly) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Viewing Archive: ${_selectedFilter == TransactionDateFilter.thisMonth ? DateFormat('MMMM yyyy').format(_selectedMonth) : _selectedFilter.chipLabel}",
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.close, size: 14),
                        label: const Text("Current Month", style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: _resetToCurrentMonth,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          balanceTitle,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _selectedFilter == TransactionDateFilter.thisMonth
                                ? DateFormat('MMMM yyyy').format(_selectedMonth)
                                : _selectedFilter.chipLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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
                    // Breakdown row inside hero card
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.credit_card_outlined,
                                color: Colors.white70,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Online Net',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  Text(
                                    '₹${onlineBalance.toStringAsFixed(2)}',
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
                              const Icon(
                                Icons.payments_outlined,
                                color: Colors.white70,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Offline Net',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  Text(
                                    '₹${offlineBalance.toStringAsFixed(2)}',
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
                          : (_selectedModeIndex == 1
                              ? "Online Income"
                              : "Offline Income"),
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
                          : (_selectedModeIndex == 1
                              ? "Online Expense"
                              : "Offline Expense"),
                      amount: displayedExpense,
                      color: Colors.red,
                      icon: Icons.arrow_upward,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ONLINE VS OFFLINE COMPARISON SUMMARY CARD
              _buildModeComparisonCard(
                context,
                onlineExpense: onlineExpense,
                onlineIncome: onlineIncome,
                onlineBalance: onlineBalance,
                offlineExpense: offlineExpense,
                offlineIncome: offlineIncome,
                offlineBalance: offlineBalance,
              ),

              const SizedBox(height: 24),

              // RECENT TRANSACTIONS HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedFilter == TransactionDateFilter.thisMonth
                        ? 'Transactions (${DateFormat('MMMM yyyy').format(_selectedMonth)})'
                        : 'Transactions (${_selectedFilter.chipLabel})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_selectedModeIndex != 0)
                    Text(
                      _selectedModeIndex == 1 ? 'Online Only' : 'Offline Only',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 10),

              // TRANSACTION LIST OR FILTERED EMPTY STATE
              if (provider.transactions.isEmpty)
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
              else if (recent.isEmpty)
                _buildNoFilteredResultsState(context)
              else
                ...recent.map(
                  (e) => InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddTransactionScreen(transaction: e),
                        ),
                      );
                    },
                    child: TransactionTile(transaction: e),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Income / Expense Stat Card
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

  // Payment Breakdown Summary Card (Online vs Offline for the filtered period)
  Widget _buildModeComparisonCard(
    BuildContext context, {
    required double onlineExpense,
    required double onlineIncome,
    required double onlineBalance,
    required double offlineExpense,
    required double offlineIncome,
    required double offlineBalance,
  }) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Payment Breakdown Summary",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                _selectedFilter == TransactionDateFilter.thisMonth
                    ? "${DateFormat('MMMM').format(_selectedMonth)} Breakdown"
                    : _selectedFilter.chipLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
                          Icon(
                            Icons.credit_card_outlined,
                            size: 14,
                            color: Colors.blue,
                          ),
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
                        "Spent: ₹${onlineExpense.toStringAsFixed(0)}",
                        style: const TextStyle(fontSize: 11, color: Colors.red),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Income: ₹${onlineIncome.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Net: ₹${onlineBalance.toStringAsFixed(0)}",
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
                          Icon(
                            Icons.payments_outlined,
                            size: 14,
                            color: Colors.orange.shade800,
                          ),
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
                        "Spent: ₹${offlineExpense.toStringAsFixed(0)}",
                        style: const TextStyle(fontSize: 11, color: Colors.red),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Income: ₹${offlineIncome.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Net: ₹${offlineBalance.toStringAsFixed(0)}",
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

  // Empty state when transactions exist in database, but none in current date filter
  Widget _buildNoFilteredResultsState(BuildContext context) {
    final rangeText = _selectedFilter.getDisplaySubtitle(
      customRange: _customRange,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_busy_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 10),
          Text(
            "No Transactions in this Timeframe",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "No transactions were recorded during $rangeText.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.all_inclusive, size: 16),
                label: const Text("View All Time"),
                onPressed: () {
                  setState(() {
                    _selectedFilter = TransactionDateFilter.all;
                    _customRange = null;
                  });
                },
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.date_range, size: 16),
                label: const Text("Change Date"),
                onPressed: () => _showCalendarOptions(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Calendar bottom sheet offering Month Picker, Date Range, Single Day, and Presets
  void _showCalendarOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Dashboard Timeframe Filter',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    if (!isDefaultMonthly)
                      TextButton.icon(
                        icon: const Icon(Icons.restart_alt, size: 16),
                        label: const Text('Reset to This Month'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _resetToCurrentMonth();
                        },
                      ),
                  ],
                ),
                Text(
                  'Dashboard totals and transactions are shown monthly (start of month to end of month) by default. You can select any month or custom timeframe.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),

                // OPTION 1: Select Month & Year
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.calendar_month,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  title: const Text(
                    'Select Month & Year',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'View all totals and transactions for an entire month (start to end)',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickMonth(context);
                  },
                ),

                const Divider(height: 16),

                // OPTION 2: Pick Date Range
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.date_range,
                      color: Colors.indigo,
                    ),
                  ),
                  title: const Text(
                    'Pick Date Range',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Choose custom start and end dates (e.g. past 15 days, 45 days)',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickDateRange();
                  },
                ),

                const Divider(height: 16),

                // OPTION 3: Pick Single Day
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.calendar_today, color: Colors.teal),
                  ),
                  title: const Text(
                    'Pick Specific Day',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'View home screen totals for a single day',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickSingleDate();
                  },
                ),

                const Divider(height: 16),
                const SizedBox(height: 6),

                const Text(
                  "Quick Timeframes",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 10),

                // Quick presets wrap
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildQuickActionChip(
                      label: "This Month (Default)",
                      isSelected: isDefaultMonthly,
                      onTap: () {
                        Navigator.pop(ctx);
                        _resetToCurrentMonth();
                      },
                    ),
                    _buildQuickActionChip(
                      label: "Last Month",
                      isSelected:
                          _selectedFilter == TransactionDateFilter.lastMonth,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedFilter = TransactionDateFilter.lastMonth;
                          _customRange = null;
                        });
                      },
                    ),
                    _buildQuickActionChip(
                      label: "Today",
                      isSelected:
                          _selectedFilter == TransactionDateFilter.custom &&
                          _customRange != null &&
                          _customRange!.start.day == DateTime.now().day &&
                          _customRange!.end.day == DateTime.now().day,
                      onTap: () {
                        Navigator.pop(ctx);
                        final now = DateTime.now();
                        setState(() {
                          _selectedFilter = TransactionDateFilter.custom;
                          _customRange = DateTimeRange(start: now, end: now);
                        });
                      },
                    ),
                    _buildQuickActionChip(
                      label: "Past 1 Week",
                      isSelected:
                          _selectedFilter == TransactionDateFilter.oneWeek,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedFilter = TransactionDateFilter.oneWeek;
                          _customRange = null;
                        });
                      },
                    ),
                    _buildQuickActionChip(
                      label: "Past 2 Weeks",
                      isSelected:
                          _selectedFilter == TransactionDateFilter.twoWeeks,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedFilter = TransactionDateFilter.twoWeeks;
                          _customRange = null;
                        });
                      },
                    ),
                    _buildQuickActionChip(
                      label: "All Time",
                      isSelected: _selectedFilter == TransactionDateFilter.all,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedFilter = TransactionDateFilter.all;
                          _customRange = null;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionChip({
    required String label,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    final theme = Theme.of(context);
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? theme.colorScheme.onPrimary : null,
        ),
      ),
      backgroundColor: isSelected ? theme.colorScheme.primary : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onPressed: onTap,
    );
  }

  // Opens Month & Year Selector Dialog
  Future<void> _pickMonth(BuildContext context) async {
    final now = DateTime.now();
    int tempYear = _selectedMonth.year;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final theme = Theme.of(dialogCtx);
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous Year',
                    onPressed: () {
                      setDialogState(() {
                        tempYear--;
                      });
                    },
                  ),
                  Text(
                    '$tempYear',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next Year',
                    onPressed: () {
                      setDialogState(() {
                        tempYear++;
                      });
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.8,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final monthIndex = index + 1;
                    final isSelected =
                        _selectedFilter == TransactionDateFilter.thisMonth &&
                        _selectedMonth.year == tempYear &&
                        _selectedMonth.month == monthIndex;
                    final isCurrent =
                        now.year == tempYear && now.month == monthIndex;
                    final monthDate = DateTime(tempYear, monthIndex);
                    final monthName = DateFormat('MMM').format(monthDate);

                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedMonth = DateTime(tempYear, monthIndex);
                          _selectedFilter = TransactionDateFilter.thisMonth;
                          _customRange = null;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : (isCurrent
                                  ? theme.colorScheme.primaryContainer.withValues(
                                      alpha: 0.4,
                                    )
                                  : theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(8),
                          border: isCurrent && !isSelected
                              ? Border.all(
                                  color: theme.colorScheme.primary,
                                  width: 1.5,
                                )
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          monthName,
                          style: TextStyle(
                            fontWeight: isSelected || isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : null,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _resetToCurrentMonth();
                  },
                  child: const Text('Current Month'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Opens Flutter's Date Range Picker for arbitrary date range
  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialRange =
        _customRange ??
        TransactionDateFilter.getMonthRange(_selectedMonth);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDateRange: initialRange,
      helpText: 'Select Date Range for Dashboard',
      cancelText: 'Cancel',
      confirmText: 'Apply',
      saveText: 'Apply',
      builder: (context, child) {
        return Theme(data: Theme.of(context), child: child!);
      },
    );

    if (picked != null) {
      setState(() {
        _selectedFilter = TransactionDateFilter.custom;
        _customRange = picked;
      });
    }
  }

  // Opens Flutter's Single Date Picker for specific day
  Future<void> _pickSingleDate() async {
    final now = DateTime.now();
    final initialDate = _customRange?.start ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: 'Select Specific Day',
      builder: (context, child) {
        return Theme(data: Theme.of(context), child: child!);
      },
    );

    if (picked != null) {
      setState(() {
        _selectedFilter = TransactionDateFilter.custom;
        _customRange = DateTimeRange(start: picked, end: picked);
      });
    }
  }

  List<DateTime> _getCompletedMonths(List<TransactionModel> transactions) {
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month);

    final Set<int> monthKeys = {};
    final List<DateTime> months = [];

    // 1. Gather all past months from transactions that are strictly before the current month
    for (final tx in transactions) {
      final m = DateTime(tx.date.year, tx.date.month);
      if (m.isBefore(currentMonthStart)) {
        final key = m.year * 100 + m.month;
        if (monthKeys.add(key)) {
          months.add(m);
        }
      }
    }

    // 2. Include past 12 completed calendar months based on current time
    for (int i = 1; i <= 12; i++) {
      final m = DateTime(now.year, now.month - i);
      final key = m.year * 100 + m.month;
      if (monthKeys.add(key)) {
        months.add(m);
      }
    }

    // Sort descending: most recent completed month first
    months.sort((a, b) => b.compareTo(a));
    return months;
  }

  void _confirmDeleteMonth(
    BuildContext context,
    TransactionProvider provider,
    DateTime month,
    int count,
  ) {
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

  Widget _buildDrawer(BuildContext context, TransactionProvider provider) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final completedMonths = _getCompletedMonths(provider.transactions);

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Personal Expense",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Monthly History & Completed Archives",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // CURRENT MONTH TILE
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDefaultMonthly
                          ? theme.colorScheme.primary.withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.today,
                      color: isDefaultMonthly
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    DateFormat('MMMM yyyy').format(currentMonth),
                    style: TextStyle(
                      fontWeight: isDefaultMonthly ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    isDefaultMonthly
                        ? 'Current Month (Active)'
                        : 'Tap to switch back to Current Month',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDefaultMonthly ? theme.colorScheme.primary : null,
                    ),
                  ),
                  trailing: isDefaultMonthly
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                  selected: isDefaultMonthly,
                  onTap: () {
                    Navigator.pop(context);
                    _resetToCurrentMonth();
                  },
                ),

                const Divider(height: 1),

                // SECTION HEADER FOR COMPLETED MONTHS
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "COMPLETED MONTHS",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        "${completedMonths.length} months",
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                if (completedMonths.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.hourglass_empty, color: Colors.grey.shade400, size: 36),
                          const SizedBox(height: 8),
                          const Text(
                            "No completed months yet",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "When the current month ends, it will automatically appear here.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...completedMonths.map((m) {
                    final mTransactions = provider.transactions
                        .where((t) => t.date.year == m.year && t.date.month == m.month)
                        .toList();
                    final count = mTransactions.length;
                    final expense = mTransactions
                        .where((t) => !t.isIncome)
                        .fold(0.0, (sum, t) => sum + t.amount);
                    final monthName = DateFormat('MMMM yyyy').format(m);

                    final isViewingThisInDashboard =
                        _selectedFilter == TransactionDateFilter.thisMonth &&
                        _selectedMonth.year == m.year &&
                        _selectedMonth.month == m.month;

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: isViewingThisInDashboard
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.calendar_month,
                          size: 18,
                          color: isViewingThisInDashboard
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      title: Text(
                        monthName,
                        style: TextStyle(
                          fontWeight:
                              isViewingThisInDashboard ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        count == 0
                            ? '0 transactions'
                            : '$count transaction${count > 1 ? 's' : ''} • Spent: ₹${expense.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (count > 0)
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              tooltip: 'Delete $monthName',
                              onPressed: () => _confirmDeleteMonth(
                                context,
                                provider,
                                m,
                                count,
                              ),
                            ),
                          const Icon(Icons.chevron_right, size: 18),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MonthlyTransactionsScreen(
                              month: m,
                              onSelectForDashboard: () {
                                setState(() {
                                  _selectedMonth = m;
                                  _selectedFilter = TransactionDateFilter.thisMonth;
                                  _customRange = null;
                                });
                              },
                            ),
                          ),
                        );
                      },
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
