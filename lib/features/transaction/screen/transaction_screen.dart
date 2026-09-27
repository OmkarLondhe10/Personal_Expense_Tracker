import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_expense_tracker/features/transaction/screen/add_transaction.dart';
import 'package:personal_expense_tracker/features/transaction/widget/transaction_tile.dart';
import 'package:personal_expense_tracker/models/transaction_filter_model.dart';
import 'package:personal_expense_tracker/models/transaction_model.dart';
import 'package:personal_expense_tracker/provider/transaction_provider.dart';
import 'package:provider/provider.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  TransactionDateFilter _selectedFilter = TransactionDateFilter.all;
  DateTimeRange? _customRange;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final allTransactions = provider.transactions;

    final filterRange = _selectedFilter.getDateRange(customRange: _customRange);

    // Apply date filter
    final filteredTransactions = filterRange == null
        ? List<TransactionModel>.from(allTransactions)
        : allTransactions.where((tx) {
            return !tx.date.isBefore(filterRange.start) &&
                !tx.date.isAfter(filterRange.end);
          }).toList();

    // Sort descending by date so date headers group days consecutively
    filteredTransactions.sort((a, b) => b.date.compareTo(a.date));

    // Summary calculations for filtered set
    final filteredExpense = filteredTransactions
        .where((t) => !t.isIncome)
        .fold(0.0, (sum, t) => sum + t.amount);

    final filteredIncome = filteredTransactions
        .where((t) => t.isIncome)
        .fold(0.0, (sum, t) => sum + t.amount);

    final isFilterActive = _selectedFilter != TransactionDateFilter.all;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Transactions"),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: "Choose date filter",
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.calendar_month_outlined),
                if (isFilterActive)
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

      body: Column(
        children: [
          // QUICK FILTER CHIPS
          _buildFilterChips(context),

          // ACTIVE FILTER & SUMMARY CARD
          if (isFilterActive)
            _buildActiveFilterCard(
              context,
              filteredCount: filteredTransactions.length,
              expense: filteredExpense,
              income: filteredIncome,
            ),

          // TRANSACTION LIST OR EMPTY STATE
          Expanded(
            child: allTransactions.isEmpty
                ? _buildEmptyState(context)
                : filteredTransactions.isEmpty
                ? _buildNoFilteredResultsState(context)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final tx = filteredTransactions[index];

                      // Check whether we need to show a new date header.
                      final bool showDateHeader;
                      if (index == 0) {
                        showDateHeader = true;
                      } else {
                        final previousTx = filteredTransactions[index - 1];
                        showDateHeader = !_isSameDay(tx.date, previousTx.date);
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // DATE HEADER
                          if (showDateHeader)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _getDateLabel(tx.date),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  _buildDailyTotalText(
                                    tx.date,
                                    filteredTransactions,
                                  ),
                                ],
                              ),
                            ),

                          // TRANSACTION TILE
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            child: Dismissible(
                              key: ValueKey(tx.id),
                              direction: DismissDirection.endToStart,

                              // DELETE BACKGROUND
                              background: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red.shade400,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),

                              // DELETE CONFIRMATION
                              confirmDismiss: (_) async {
                                return await showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text("Delete Transaction?"),
                                    content: const Text(
                                      "This action cannot be undone.",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(ctx, false);
                                        },
                                        child: const Text("Cancel"),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(ctx, true);
                                        },
                                        child: const Text(
                                          "Delete",
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },

                              // DELETE TRANSACTION
                              onDismissed: (_) {
                                final removedTx = tx;
                                provider.deleteTransaction(tx.id);

                                ScaffoldMessenger.of(context).clearSnackBars();

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text("Transaction deleted"),
                                    behavior: SnackBarBehavior.floating,
                                    action: SnackBarAction(
                                      label: "UNDO",
                                      onPressed: () {
                                        provider.addTransaction(removedTx);
                                      },
                                    ),
                                  ),
                                );
                              },

                              // EDIT TRANSACTION
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AddTransactionScreen(transaction: tx),
                                    ),
                                  );
                                },
                                child: TransactionTile(transaction: tx),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),

      // ADD TRANSACTION FAB
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text("Add"),
      ),
    );
  }

  // Horizontal Filter Chips Row
  Widget _buildFilterChips(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    final filters = [
      TransactionDateFilter.all,
      TransactionDateFilter.oneWeek,
      TransactionDateFilter.twoWeeks,
      TransactionDateFilter.threeWeeks,
      TransactionDateFilter.oneMonth,
      TransactionDateFilter.custom,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: filters.map((filter) {
            final isSelected = _selectedFilter == filter;

            String label;
            IconData iconData;

            switch (filter) {
              case TransactionDateFilter.all:
                label = 'All';
                iconData = Icons.all_inclusive;
                break;
              case TransactionDateFilter.oneWeek:
                label = 'Past 1 Wk';
                iconData = Icons.history;
                break;
              case TransactionDateFilter.twoWeeks:
                label = 'Past 2 Wks';
                iconData = Icons.history_toggle_off;
                break;
              case TransactionDateFilter.threeWeeks:
                label = 'Past 3 Wks';
                iconData = Icons.timelapse;
                break;
              case TransactionDateFilter.oneMonth:
                label = 'Past 1 Mo';
                iconData = Icons.calendar_view_month;
                break;
              case TransactionDateFilter.custom:
                if (isSelected && _customRange != null) {
                  label = _formatCustomShortLabel(_customRange!);
                } else {
                  label = 'Calendar';
                }
                iconData = Icons.calendar_today_outlined;
                break;
            }

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: isSelected,
                showCheckmark: false,
                avatar: Icon(
                  iconData,
                  size: 16,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                label: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
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
                        : theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
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
      ),
    );
  }

  // Active filter info banner & summary card
  Widget _buildActiveFilterCard(
    BuildContext context, {
    required int filteredCount,
    required double expense,
    required double income,
  }) {
    final theme = Theme.of(context);
    final rangeText = _selectedFilter.getDisplaySubtitle(
      customRange: _customRange,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 2, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.filter_list,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "${_selectedFilter.label} ($rangeText)",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedFilter = TransactionDateFilter.all;
                    _customRange = null;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.close,
                        size: 14,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        "Clear",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniMetric(
                label: "Filtered",
                value: "$filteredCount txns",
                color: theme.colorScheme.onSurfaceVariant,
              ),
              _buildMiniMetric(
                label: "Spent",
                value: "-₹${expense.toStringAsFixed(0)}",
                color: Colors.red,
              ),
              _buildMiniMetric(
                label: "Income",
                value: "+₹${income.toStringAsFixed(0)}",
                color: Colors.green,
              ),
              _buildMiniMetric(
                label: "Net",
                value:
                    "${(income - expense) >= 0 ? '+' : '-'}₹${(income - expense).abs().toStringAsFixed(0)}",
                color: (income - expense) >= 0 ? Colors.green : Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
                      'Filter by Calendar',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    if (_selectedFilter != TransactionDateFilter.all)
                      TextButton.icon(
                        icon: const Icon(Icons.restart_alt, size: 16),
                        label: const Text('Reset'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _selectedFilter = TransactionDateFilter.all;
                            _customRange = null;
                          });
                        },
                      ),
                  ],
                ),
                Text(
                  'Select a custom timeframe or specific day to view transactions',
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
                    'Choose start and end dates (e.g., past 4 days, custom range)',
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
                    'View transactions from one specific day',
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
                      label: "Today",
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
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedFilter = TransactionDateFilter.twoWeeks;
                          _customRange = null;
                        });
                      },
                    ),
                    _buildQuickActionChip(
                      label: "Past 3 Weeks",
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedFilter = TransactionDateFilter.threeWeeks;
                          _customRange = null;
                        });
                      },
                    ),
                    _buildQuickActionChip(
                      label: "Past 1 Month",
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedFilter = TransactionDateFilter.oneMonth;
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
  }) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onPressed: onTap,
    );
  }

  // Opens Flutter's Date Range Picker
  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialRange =
        _customRange ??
        DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDateRange: initialRange,
      helpText: 'Select Date Range',
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

  // Opens Flutter's Single Date Picker
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

  // Check whether two dates are the same calendar day.
  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  Widget _buildDailyTotalText(
    DateTime date,
    List<TransactionModel> transactions,
  ) {
    final dailyExpense = transactions
        .where((tx) => _isSameDay(tx.date, date) && !tx.isIncome)
        .fold(0.0, (sum, tx) => sum + tx.amount);

    final dailyIncome = transactions
        .where((tx) => _isSameDay(tx.date, date) && tx.isIncome)
        .fold(0.0, (sum, tx) => sum + tx.amount);

    if (dailyExpense > 0) {
      return Text(
        "-₹${dailyExpense.toStringAsFixed(2)}",
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.red,
        ),
      );
    } else if (dailyIncome > 0) {
      return Text(
        "+₹${dailyIncome.toStringAsFixed(2)}",
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.green,
        ),
      );
    } else {
      return const Text(
        "₹0.00",
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      );
    }
  }

  // Convert date into Today / Yesterday / actual date.
  String _getDateLabel(DateTime date) {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final transactionDate = DateTime(date.year, date.month, date.day);

    final yesterday = today.subtract(const Duration(days: 1));

    if (transactionDate == today) {
      return "TODAY";
    }

    if (transactionDate == yesterday) {
      return "YESTERDAY";
    }

    return DateFormat('dd MMM yyyy').format(date).toUpperCase();
  }

  // EMPTY STATE: No transactions exist at all
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            "No Transactions Yet",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            "Tap the + button to add one",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // EMPTY STATE: Transactions exist, but none match the current filter
  Widget _buildNoFilteredResultsState(BuildContext context) {
    final subtitle = _selectedFilter.getDisplaySubtitle(
      customRange: _customRange,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 72,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              "No Transactions Found",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "No transactions were recorded during $subtitle.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.clear_all),
              label: const Text("Show All Transactions"),
              onPressed: () {
                setState(() {
                  _selectedFilter = TransactionDateFilter.all;
                  _customRange = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
