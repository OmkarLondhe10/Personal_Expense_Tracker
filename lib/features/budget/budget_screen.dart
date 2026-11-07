import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_expense_tracker/features/transaction/screen/add_transaction.dart';
import 'package:personal_expense_tracker/features/transaction/widget/transaction_tile.dart';
import 'package:personal_expense_tracker/provider/transaction_provider.dart';
import 'package:provider/provider.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  // 0: All, 1: Online, 2: Offline
  int _selectedModeIndex = 0;

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
  }

  void _resetToCurrentMonth() {
    final now = DateTime.now();
    setState(() {
      _selectedMonth = DateTime(now.year, now.month);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();

    final totalBudget = provider.monthlyBudget;
    final onlineBudget = provider.onlineBudget;
    final offlineBudget = provider.offlineBudget;
    final useSeparate = provider.useSeparateBudgets;

    final totalSpent = provider.getMonthlyExpense(_selectedMonth);
    final onlineSpent = provider.getMonthlyOnlineExpense(_selectedMonth);
    final offlineSpent = provider.getMonthlyOfflineExpense(_selectedMonth);

    // Active displayed budget and spent amounts based on selected mode (All, Online, Offline)
    final double displayedBudget;
    final double displayedSpent;
    final String modeTitle;

    switch (_selectedModeIndex) {
      case 1:
        displayedBudget = useSeparate ? onlineBudget : totalBudget;
        displayedSpent = onlineSpent;
        modeTitle = useSeparate ? 'Online Budget' : 'Online Expenses';
        break;
      case 2:
        displayedBudget = useSeparate ? offlineBudget : totalBudget;
        displayedSpent = offlineSpent;
        modeTitle = useSeparate ? 'Offline Budget' : 'Offline Expenses';
        break;
      case 0:
      default:
        displayedBudget = totalBudget;
        displayedSpent = totalSpent;
        modeTitle = 'Total Monthly Budget';
        break;
    }

    final isOverBudget =
        displayedBudget > 0 && displayedSpent > displayedBudget;
    final remainingBudget = (displayedBudget - displayedSpent).clamp(
      0.0,
      double.infinity,
    );
    final overBudgetAmount = (displayedSpent - displayedBudget).clamp(
      0.0,
      double.infinity,
    );
    final progress = displayedBudget == 0
        ? 0.0
        : (displayedSpent / displayedBudget).clamp(0.0, 1.0);
    final percentage = displayedBudget == 0
        ? 0
        : ((displayedSpent / displayedBudget) * 100).toInt();

    // Category spending and recent transactions filtered by mode
    final categorySpending = provider.getMonthlyCategorySpending(
      targetMonth: _selectedMonth,
      isOnline: _selectedModeIndex == 0 ? null : (_selectedModeIndex == 1),
    );

    final allMonthlyTransactions = provider.getMonthlyTransactions(
      _selectedMonth,
    );
    final modeTransactions = _selectedModeIndex == 0
        ? allMonthlyTransactions
        : allMonthlyTransactions
              .where((t) => _selectedModeIndex == 1 ? t.isOnline : !t.isOnline)
              .toList();
    final recentExpenses = modeTransactions
        .where((t) => !t.isIncome)
        .take(5)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Budget'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: totalBudget > 0 ? 'Adjust Budget' : 'Set Budget',
            icon: Icon(totalBudget > 0 ? Icons.tune : Icons.add_circle_outline),
            onPressed: () => _showBudgetBottomSheet(
              context,
              currentTotal: totalBudget,
              currentOnline: onlineBudget,
              currentOffline: offlineBudget,
              currentUseSeparate: useSeparate,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.load();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // MONTH SELECTOR BAR
            _buildMonthSelectorBar(context),

            const SizedBox(height: 12),

            // PAYMENT MODE SELECTOR (All, Online, Offline)
            _buildModeSelectorSegment(context, useSeparate: useSeparate),

            const SizedBox(height: 16),

            // BUDGET HERO CARD (Total Budget & Expenses only)
            if (displayedBudget == 0 && totalBudget == 0)
              _buildEmptyBudgetCard(context)
            else
              _buildActiveBudgetCard(
                context,
                title: modeTitle,
                budget: displayedBudget,
                spent: displayedSpent,
                remaining: remainingBudget,
                overspent: overBudgetAmount,
                progress: progress,
                percentage: percentage,
                isOverBudget: isOverBudget,
                isSeparateSubBudget: useSeparate && _selectedModeIndex != 0,
              ),

            // SEPARATE ONLINE & OFFLINE SUMMARY CARDS (When on 'All' mode with separate budgets enabled)
            if (_selectedModeIndex == 0 &&
                useSeparate &&
                (onlineBudget > 0 || offlineBudget > 0)) ...[
              const SizedBox(height: 14),
              _buildSeparateBudgetsBreakdown(
                context,
                onlineBudget: onlineBudget,
                onlineSpent: onlineSpent,
                offlineBudget: offlineBudget,
                offlineSpent: offlineSpent,
              ),
            ],

            const SizedBox(height: 16),

            // DAILY SPENDING ALLOWANCE (for current month)
            if (_isCurrentMonth && displayedBudget > 0) ...[
              _buildDailyAllowanceCard(
                context,
                remaining: remainingBudget,
                isOverBudget: isOverBudget,
                overspent: overBudgetAmount,
                budget: displayedBudget,
                modeName: _selectedModeIndex == 1
                    ? 'online'
                    : (_selectedModeIndex == 2 ? 'offline' : 'overall'),
              ),
              const SizedBox(height: 16),
            ],

            // CATEGORY BREAKDOWN SECTION
            _buildCategoryBreakdownSection(
              context,
              categorySpending: categorySpending,
              totalSpent: displayedSpent,
              budget: displayedBudget,
            ),

            const SizedBox(height: 20),

            // RECENT EXPENSES FOR SELECTED MONTH
            _buildRecentExpensesSection(
              context,
              expenses: recentExpenses,
              monthName: DateFormat.MMMM().format(_selectedMonth),
              modeIndex: _selectedModeIndex,
            ),
          ],
        ),
      ),
      floatingActionButton: totalBudget == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showBudgetBottomSheet(
                context,
                currentTotal: totalBudget,
                currentOnline: onlineBudget,
                currentOffline: offlineBudget,
                currentUseSeparate: useSeparate,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Set Budget'),
            )
          : null,
    );
  }

  // Payment Mode Segmented Button (All, Online, Offline)
  Widget _buildModeSelectorSegment(
    BuildContext context, {
    required bool useSeparate,
  }) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<int>(
        segments: [
          const ButtonSegment<int>(
            value: 0,
            label: Text('All'),
            icon: Icon(Icons.all_inclusive, size: 16),
          ),
          ButtonSegment<int>(
            value: 1,
            label: Text(useSeparate ? 'Online Budget' : 'Online'),
            icon: const Icon(Icons.credit_card_outlined, size: 16),
          ),
          ButtonSegment<int>(
            value: 2,
            label: Text(useSeparate ? 'Offline Budget' : 'Offline'),
            icon: const Icon(Icons.payments_outlined, size: 16),
          ),
        ],
        selected: {_selectedModeIndex},
        onSelectionChanged: (set) {
          setState(() {
            _selectedModeIndex = set.first;
          });
        },
      ),
    );
  }

  // Month Selector Navigation Bar
  Widget _buildMonthSelectorBar(BuildContext context) {
    final theme = Theme.of(context);
    final monthLabel = DateFormat.yMMMM().format(_selectedMonth);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous Month',
            onPressed: _previousMonth,
          ),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _isCurrentMonth ? null : _resetToCurrentMonth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_month,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    monthLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isCurrentMonth)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Current',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Past',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next Month',
            onPressed: _nextMonth,
          ),
        ],
      ),
    );
  }

  // Active Budget Hero Card (Focused purely on Expenses & Budget)
  Widget _buildActiveBudgetCard(
    BuildContext context, {
    required String title,
    required double budget,
    required double spent,
    required double remaining,
    required double overspent,
    required double progress,
    required int percentage,
    required bool isOverBudget,
    required bool isSeparateSubBudget,
  }) {
    final theme = Theme.of(context);
    final provider = context.read<TransactionProvider>();

    final Color statusColor;
    final String statusText;
    final IconData statusIcon;

    if (budget == 0) {
      statusColor = Colors.white70;
      statusText = 'No Specific Budget Set';
      statusIcon = Icons.info_outline;
    } else if (isOverBudget) {
      statusColor = Colors.redAccent;
      statusText = 'Over Budget ($percentage%)';
      statusIcon = Icons.warning_amber_rounded;
    } else if (progress >= 0.8) {
      statusColor = Colors.amber;
      statusText = 'Near Limit ($percentage%)';
      statusIcon = Icons.info_outline;
    } else {
      statusColor = Colors.lightGreenAccent;
      statusText = 'On Track ($percentage%)';
      statusIcon = Icons.check_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Title and Health Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _selectedModeIndex == 1
                        ? Icons.credit_card_outlined
                        : (_selectedModeIndex == 2
                              ? Icons.payments_outlined
                              : Icons.shield_outlined),
                    color: Colors.white70,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 13, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Main Spent / Budget Display
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₹${spent.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                budget > 0
                    ? '/ ₹${budget.toStringAsFixed(0)}'
                    : '(Total Spent)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
            ],
          ),

          if (budget > 0) ...[
            const SizedBox(height: 14),
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOverBudget
                      ? Colors.redAccent
                      : (progress >= 0.8
                            ? Colors.amber
                            : Colors.lightGreenAccent),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),

          // 2-Column Metrics Row: Total Budget & Remaining/Overspent
          Row(
            children: [
              Expanded(
                child: _buildMetricCol(
                  label: 'Target Budget',
                  value: budget > 0
                      ? '₹${budget.toStringAsFixed(0)}'
                      : 'Not Set',
                  valueColor: Colors.white,
                  icon: Icons.track_changes,
                ),
              ),
              Container(width: 1, height: 32, color: Colors.white24),
              Expanded(
                child: _buildMetricCol(
                  label: isOverBudget ? 'Overspent' : 'Remaining',
                  value: budget == 0
                      ? '₹${spent.toStringAsFixed(0)} Spent'
                      : (isOverBudget
                            ? '-₹${overspent.toStringAsFixed(0)}'
                            : '₹${remaining.toStringAsFixed(0)}'),
                  valueColor: isOverBudget
                      ? Colors.redAccent.shade100
                      : Colors.white,
                  icon: isOverBudget
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Adjust Button inside card
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.tune, size: 14),
              label: const Text(
                'Adjust Budget',
                style: TextStyle(fontSize: 12),
              ),
              onPressed: () => _showBudgetBottomSheet(
                context,
                currentTotal: provider.monthlyBudget,
                currentOnline: provider.onlineBudget,
                currentOffline: provider.offlineBudget,
                currentUseSeparate: provider.useSeparateBudgets,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCol({
    required String label,
    required String value,
    required Color valueColor,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: Colors.white70),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // Mini Breakdown Card for Separate Online & Offline Budgets
  Widget _buildSeparateBudgetsBreakdown(
    BuildContext context, {
    required double onlineBudget,
    required double onlineSpent,
    required double offlineBudget,
    required double offlineSpent,
  }) {
    final theme = Theme.of(context);

    final onlineRemaining = (onlineBudget - onlineSpent).clamp(
      0.0,
      double.infinity,
    );
    final offlineRemaining = (offlineBudget - offlineSpent).clamp(
      0.0,
      double.infinity,
    );

    final onlineProgress = onlineBudget == 0
        ? 0.0
        : (onlineSpent / onlineBudget).clamp(0.0, 1.0);
    final offlineProgress = offlineBudget == 0
        ? 0.0
        : (offlineSpent / offlineBudget).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Split Budget Tracking',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                'Online & Offline',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Online Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
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
                            'Online',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '₹${onlineSpent.toStringAsFixed(0)} / ₹${onlineBudget.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: onlineProgress,
                          minHeight: 4,
                          backgroundColor: Colors.blue.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            onlineSpent > onlineBudget
                                ? Colors.redAccent
                                : Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        onlineSpent > onlineBudget
                            ? 'Over by ₹${(onlineSpent - onlineBudget).toStringAsFixed(0)}'
                            : 'Left: ₹${onlineRemaining.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: onlineSpent > onlineBudget
                              ? Colors.red
                              : Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Offline Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
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
                            'Offline',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '₹${offlineSpent.toStringAsFixed(0)} / ₹${offlineBudget.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: offlineProgress,
                          minHeight: 4,
                          backgroundColor: Colors.orange.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            offlineSpent > offlineBudget
                                ? Colors.redAccent
                                : Colors.orange.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        offlineSpent > offlineBudget
                            ? 'Over by ₹${(offlineSpent - offlineBudget).toStringAsFixed(0)}'
                            : 'Left: ₹${offlineRemaining.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: offlineSpent > offlineBudget
                              ? Colors.red
                              : Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
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

  // Empty Budget Callout
  Widget _buildEmptyBudgetCard(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.read<TransactionProvider>();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.savings_outlined,
              size: 40,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No Monthly Budget Set',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Set an overall expense budget or configure separate budgets for online and offline expenses.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue, // Button background color
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Set Monthly Budget'),
            onPressed: () => _showBudgetBottomSheet(
              context,
              currentTotal: 0,
              currentOnline: 0,
              currentOffline: 0,
              currentUseSeparate: false,
            ),
          ),
          const SizedBox(height: 12),
          // Quick presets chips
          Wrap(
            spacing: 8,
            children: [
              _buildPresetChip(context, 10000),
              _buildPresetChip(context, 20000),
              _buildPresetChip(context, 35000),
              _buildPresetChip(context, 50000),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(BuildContext context, double amount) {
    return ActionChip(
      label: Text(
        '₹${amount.toStringAsFixed(0)}',
        style: const TextStyle(fontSize: 12),
      ),
      onPressed: () async {
        await context.read<TransactionProvider>().setBudget(amount);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Monthly budget set to ₹${amount.toStringAsFixed(0)}',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  // Daily Allowance Card (Expenses & Budget only)
  Widget _buildDailyAllowanceCard(
    BuildContext context, {
    required double remaining,
    required bool isOverBudget,
    required double overspent,
    required double budget,
    required String modeName,
  }) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = (daysInMonth - now.day) + 1;
    final dailyAllowance = daysLeft > 0 ? (remaining / daysLeft) : 0.0;

    if (isOverBudget) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Budget Exceeded ($modeName)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'You are ₹${overspent.toStringAsFixed(0)} over your ₹${budget.toStringAsFixed(0)} target with $daysLeft days remaining this month.',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lightbulb_outline,
              color: theme.colorScheme.secondary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Safe Daily Spend ($modeName)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                    Text(
                      '$daysLeft days left',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${dailyAllowance.toStringAsFixed(0)} / day',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Keep daily spending below this limit to finish the month within budget.',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Category Spending Breakdown Section
  Widget _buildCategoryBreakdownSection(
    BuildContext context, {
    required Map<String, double> categorySpending,
    required double totalSpent,
    required double budget,
  }) {
    final theme = Theme.of(context);

    if (categorySpending.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 8),
            const Text(
              'No Expenses Recorded',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Expenses recorded in ${DateFormat.yMMMM().format(_selectedMonth)} will appear grouped here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final sortedEntries = categorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedModeIndex == 1
                    ? 'Online Spending by Category'
                    : (_selectedModeIndex == 2
                          ? 'Offline Spending by Category'
                          : 'Spending by Category'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(
                '${sortedEntries.length} categories',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...sortedEntries.map((entry) {
            final category = entry.key;
            final amount = entry.value;
            final proportion = totalSpent > 0 ? (amount / totalSpent) : 0.0;
            final percent = (proportion * 100).toStringAsFixed(1);
            final categoryColor = _getCategoryColor(category);

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getCategoryIcon(category),
                          size: 18,
                          color: categoryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '$percent% of spent',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₹${amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: proportion,
                      minHeight: 5,
                      backgroundColor: categoryColor.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(categoryColor),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // Recent Expenses Section
  Widget _buildRecentExpensesSection(
    BuildContext context, {
    required List<dynamic> expenses,
    required String monthName,
    required int modeIndex,
  }) {
    if (expenses.isEmpty) {
      return const SizedBox.shrink();
    }

    final titleSuffix = modeIndex == 1
        ? 'Online'
        : (modeIndex == 2 ? 'Offline' : 'All');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Expenses ($monthName · $titleSuffix)',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...expenses.map((tx) {
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddTransactionScreen(transaction: tx),
                ),
              );
            },
            child: TransactionTile(transaction: tx),
          );
        }),
      ],
    );
  }

  // Set / Edit Budget BottomSheet with Option for Separate Online & Offline Budgets
  void _showBudgetBottomSheet(
    BuildContext context, {
    required double currentTotal,
    required double currentOnline,
    required double currentOffline,
    required bool currentUseSeparate,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return _BudgetSettingsSheet(
          initialTotal: currentTotal,
          initialOnline: currentOnline,
          initialOffline: currentOffline,
          initialUseSeparate: currentUseSeparate,
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'dining':
      case 'groceries':
      case 'restaurant':
        return Icons.restaurant;
      case 'transport':
      case 'travel':
      case 'fuel':
      case 'cab':
        return Icons.directions_car;
      case 'bills':
      case 'utilities':
      case 'electricity':
      case 'recharge':
        return Icons.receipt_long;
      case 'shopping':
      case 'clothing':
        return Icons.shopping_bag;
      case 'entertainment':
      case 'movies':
        return Icons.movie;
      case 'health':
      case 'medical':
      case 'pharmacy':
        return Icons.local_hospital;
      case 'salary':
      case 'income':
        return Icons.account_balance_wallet;
      case 'education':
      case 'books':
        return Icons.menu_book;
      default:
        return Icons.category;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'dining':
      case 'groceries':
      case 'restaurant':
        return Colors.orange;
      case 'transport':
      case 'travel':
      case 'fuel':
      case 'cab':
        return Colors.blue;
      case 'bills':
      case 'utilities':
      case 'electricity':
      case 'recharge':
        return Colors.redAccent;
      case 'shopping':
      case 'clothing':
        return Colors.purple;
      case 'entertainment':
      case 'movies':
        return Colors.pink;
      case 'health':
      case 'medical':
      case 'pharmacy':
        return Colors.teal;
      case 'salary':
      case 'income':
        return Colors.green;
      case 'education':
      case 'books':
        return Colors.amber.shade800;
      default:
        return Colors.indigo;
    }
  }
}

// Stateful BottomSheet for Budget Configuration (Total or Separate Online/Offline)
class _BudgetSettingsSheet extends StatefulWidget {
  final double initialTotal;
  final double initialOnline;
  final double initialOffline;
  final bool initialUseSeparate;

  const _BudgetSettingsSheet({
    required this.initialTotal,
    required this.initialOnline,
    required this.initialOffline,
    required this.initialUseSeparate,
  });

  @override
  State<_BudgetSettingsSheet> createState() => _BudgetSettingsSheetState();
}

class _BudgetSettingsSheetState extends State<_BudgetSettingsSheet> {
  late bool _useSeparate;
  late TextEditingController _totalController;
  late TextEditingController _onlineController;
  late TextEditingController _offlineController;

  @override
  void initState() {
    super.initState();
    _useSeparate = widget.initialUseSeparate;
    _totalController = TextEditingController(
      text: widget.initialTotal == 0
          ? ''
          : widget.initialTotal.toStringAsFixed(0),
    );
    _onlineController = TextEditingController(
      text: widget.initialOnline == 0
          ? ''
          : widget.initialOnline.toStringAsFixed(0),
    );
    _offlineController = TextEditingController(
      text: widget.initialOffline == 0
          ? ''
          : widget.initialOffline.toStringAsFixed(0),
    );

    _onlineController.addListener(_updateCombinedTotal);
    _offlineController.addListener(_updateCombinedTotal);
  }

  void _updateCombinedTotal() {
    if (_useSeparate) {
      final on = double.tryParse(_onlineController.text) ?? 0.0;
      final off = double.tryParse(_offlineController.text) ?? 0.0;
      final combined = on + off;
      setState(() {
        _totalController.text = combined > 0 ? combined.toStringAsFixed(0) : '';
      });
    }
  }

  @override
  void dispose() {
    _onlineController.removeListener(_updateCombinedTotal);
    _offlineController.removeListener(_updateCombinedTotal);
    _totalController.dispose();
    _onlineController.dispose();
    _offlineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
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
                  'Set Monthly Budget',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                if (widget.initialTotal > 0 ||
                    widget.initialOnline > 0 ||
                    widget.initialOffline > 0)
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Clear'),
                    onPressed: () async {
                      await context.read<TransactionProvider>().setBudgets(
                        totalBudget: 0,
                        onlineBudget: 0,
                        offlineBudget: 0,
                        useSeparate: false,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  ),
              ],
            ),
            Text(
              'Set your spending target for the month. You can also split budgets between online and offline expenses.',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 14),

            // TOGGLE: SEPARATE ONLINE & OFFLINE BUDGETS
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.call_split_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Separate Online & Offline',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Set dedicated limits for each mode',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Switch(
                    value: _useSeparate,
                    onChanged: (val) {
                      setState(() {
                        _useSeparate = val;
                      });
                      if (val) {
                        _updateCombinedTotal();
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // INPUT FORM: EITHER COMBINED OR SEPARATE
            if (!_useSeparate) ...[
              // SINGLE COMBINED TOTAL BUDGET INPUT
              const Text(
                'Total Monthly Budget',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _totalController,
                autofocus: true,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  hintText: '0',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _totalController.clear(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  _quickAddChip(_totalController, 1000),
                  _quickAddChip(_totalController, 5000),
                  _quickAddChip(_totalController, 10000),
                ],
              ),
            ] else ...[
              // SEPARATE ONLINE & OFFLINE INPUTS
              Row(
                children: const [
                  Icon(
                    Icons.credit_card_outlined,
                    size: 16,
                    color: Colors.blue,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Online Budget (UPI / Card / NetBanking)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _onlineController,
                autofocus: true,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  hintText: '0',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _onlineController.clear(),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  _quickAddChip(_onlineController, 2000),
                  _quickAddChip(_onlineController, 5000),
                ],
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Icon(
                    Icons.payments_outlined,
                    size: 16,
                    color: Colors.orange.shade800,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Offline Budget (Cash)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _offlineController,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  hintText: '0',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _offlineController.clear(),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  _quickAddChip(_offlineController, 1000),
                  _quickAddChip(_offlineController, 3000),
                ],
              ),

              const SizedBox(height: 12),

              // COMBINED TOTAL INFO BAR
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Combined Total Budget:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '₹${_totalController.text.isEmpty ? "0" : _totalController.text}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // SAVE CTA
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  if (_useSeparate) {
                    final onlineVal =
                        double.tryParse(_onlineController.text) ?? 0.0;
                    final offlineVal =
                        double.tryParse(_offlineController.text) ?? 0.0;
                    final totalVal = onlineVal + offlineVal;

                    await context.read<TransactionProvider>().setBudgets(
                      totalBudget: totalVal,
                      onlineBudget: onlineVal,
                      offlineBudget: offlineVal,
                      useSeparate: true,
                    );
                  } else {
                    final totalVal =
                        double.tryParse(_totalController.text) ?? 0.0;
                    await context.read<TransactionProvider>().setBudgets(
                      totalBudget: totalVal,
                      onlineBudget: 0.0,
                      offlineBudget: 0.0,
                      useSeparate: false,
                    );
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  'Save Budget',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAddChip(TextEditingController controller, int amount) {
    return ActionChip(
      label: Text('+₹$amount', style: const TextStyle(fontSize: 11)),
      padding: EdgeInsets.zero,
      onPressed: () {
        final current = double.tryParse(controller.text) ?? 0.0;
        controller.text = (current + amount).toStringAsFixed(0);
      },
    );
  }
}
