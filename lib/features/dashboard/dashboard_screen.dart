import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_expense_tracker/features/transaction/screen/add_transaction.dart';
import 'package:personal_expense_tracker/features/transaction/widget/transaction_tile.dart';
import 'package:personal_expense_tracker/models/transaction_filter_model.dart';
import 'package:personal_expense_tracker/models/transaction_model.dart';
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

  // Defaults to Last 30 Days (auto-refreshes as time advances)
  TransactionDateFilter _selectedFilter = TransactionDateFilter.oneMonth;
  DateTimeRange? _customRange;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();

    final filterRange = _selectedFilter.getDateRange(customRange: _customRange);

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

    final isDefault30Days =
        _selectedFilter == TransactionDateFilter.oneMonth &&
        _customRange == null;

    return Scaffold(
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
                if (!isDefault30Days)
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
              // DATE FILTER BANNER (Shows active timeframe & auto-refresh status)
              _buildDateFilterBanner(context, filterRange),

              const SizedBox(height: 10),

              // QUICK TIMEFRAME PRESET CHIPS
              _buildQuickFilterChips(context),

              const SizedBox(height: 16),

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
                            isDefault30Days
                                ? "Last 30 Days"
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
                    isDefault30Days
                        ? 'Recent Transactions (30 Days)'
                        : 'Recent Transactions (${_selectedFilter.chipLabel})',
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

  // Active Date Filter Banner showing current timeframe and auto-refresh status
  Widget _buildDateFilterBanner(
    BuildContext context,
    DateTimeRange? filterRange,
  ) {
    final theme = Theme.of(context);
    final isDefault30Days =
        _selectedFilter == TransactionDateFilter.oneMonth &&
        _customRange == null;
    final rangeText = _selectedFilter.getDisplaySubtitle(
      customRange: _customRange,
    );

    return Container(
      decoration: BoxDecoration(
        color: isDefault30Days
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : theme.colorScheme.tertiaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDefault30Days
              ? theme.colorScheme.primary.withValues(alpha: 0.25)
              : theme.colorScheme.tertiary.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showCalendarOptions(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDefault30Days
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : theme.colorScheme.tertiary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    size: 20,
                    color: isDefault30Days
                        ? theme.colorScheme.primary
                        : theme.colorScheme.tertiary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              isDefault30Days
                                  ? "Last 30 Days"
                                  : (_selectedFilter ==
                                          TransactionDateFilter.custom
                                      ? "Custom Range"
                                      : _selectedFilter.label),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDefault30Days
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDefault30Days
                                  ? theme.colorScheme.primary.withValues(
                                      alpha: 0.15,
                                    )
                                  : Colors.orange.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isDefault30Days ? "Auto-refreshing" : "Filtered",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDefault30Days
                                    ? theme.colorScheme.primary
                                    : Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rangeText,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isDefault30Days) ...[
                  IconButton(
                    tooltip: "Reset to 30 Days",
                    icon: Icon(
                      Icons.replay,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedFilter = TransactionDateFilter.oneMonth;
                        _customRange = null;
                      });
                    },
                  ),
                ] else ...[
                  Icon(
                    Icons.arrow_drop_down,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Quick timeframe chips for instant 1-tap switching
  Widget _buildQuickFilterChips(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    final quickFilters = [
      TransactionDateFilter.oneMonth,
      TransactionDateFilter.oneWeek,
      TransactionDateFilter.twoWeeks,
      TransactionDateFilter.thisMonth,
      TransactionDateFilter.all,
      TransactionDateFilter.custom,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: quickFilters.map((filter) {
          final isSelected = _selectedFilter == filter;

          String label;
          IconData iconData;

          switch (filter) {
            case TransactionDateFilter.oneMonth:
              label = '30 Days (Default)';
              iconData = Icons.timelapse;
              break;
            case TransactionDateFilter.oneWeek:
              label = '1 Wk';
              iconData = Icons.history;
              break;
            case TransactionDateFilter.twoWeeks:
              label = '2 Wks';
              iconData = Icons.history_toggle_off;
              break;
            case TransactionDateFilter.thisMonth:
              label = 'This Month';
              iconData = Icons.calendar_view_month;
              break;
            case TransactionDateFilter.all:
              label = 'All Time';
              iconData = Icons.all_inclusive;
              break;
            case TransactionDateFilter.custom:
              if (isSelected && _customRange != null) {
                label = _formatCustomShortLabel(_customRange!);
              } else {
                label = 'Calendar';
              }
              iconData = Icons.calendar_today_outlined;
              break;
            default:
              label = filter.chipLabel;
              iconData = Icons.date_range;
              break;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              showCheckmark: false,
              avatar: Icon(
                iconData,
                size: 15,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              label: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                ),
              ),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              selectedColor: primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? primaryColor
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              onSelected: (selected) {
                if (filter == TransactionDateFilter.custom) {
                  _showCalendarOptions(context);
                } else {
                  setState(() {
                    _selectedFilter = filter;
                    _customRange = null;
                  });
                }
              },
            ),
          );
        }).toList(),
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
    final isDefault30Days =
        _selectedFilter == TransactionDateFilter.oneMonth &&
        _customRange == null;

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
                isDefault30Days ? "30-Day Period" : _selectedFilter.chipLabel,
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

  // Calendar bottom sheet offering Date Range, Single Day, and Presets
  void _showCalendarOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDefault30Days =
            _selectedFilter == TransactionDateFilter.oneMonth &&
            _customRange == null;

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
                      'Dashboard Calendar Filter',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    if (!isDefault30Days)
                      TextButton.icon(
                        icon: const Icon(Icons.restart_alt, size: 16),
                        label: const Text('Reset to 30 Days'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _selectedFilter = TransactionDateFilter.oneMonth;
                            _customRange = null;
                          });
                        },
                      ),
                  ],
                ),
                Text(
                  'Home screen automatically refreshes every 30 days. Select custom calendar dates or presets to view data for any timeframe.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),

                // OPTION 1: Pick Date Range
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.date_range,
                      color: theme.colorScheme.primary,
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

                // OPTION 2: Pick Single Day
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
                      label: "Last 30 Days (Default)",
                      isSelected: isDefault30Days,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedFilter = TransactionDateFilter.oneMonth;
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
                      label: "This Month",
                      isSelected:
                          _selectedFilter == TransactionDateFilter.thisMonth,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedFilter = TransactionDateFilter.thisMonth;
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

  // Opens Flutter's Date Range Picker for arbitrary date range
  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialRange =
        _customRange ??
        DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);

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

  String _formatCustomShortLabel(DateTimeRange range) {
    final isSameDay =
        range.start.year == range.end.year &&
        range.start.month == range.end.month &&
        range.start.day == range.end.day;

    if (isSameDay) {
      return DateFormat('dd MMM').format(range.start);
    }
    return '${DateFormat('dd MMM').format(range.start)} - ${DateFormat('dd MMM').format(range.end)}';
  }
}
