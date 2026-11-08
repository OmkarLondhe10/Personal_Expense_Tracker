import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';

class TransactionProvider extends ChangeNotifier {
  TransactionProvider() {
    load();
  }

  final List<TransactionModel> _transactions = [];
  static const _storagekey = 'transactions';
  static const _budgetStorageKey = 'monthly_budget';
  static const _onlineBudgetStorageKey = 'online_budget';
  static const _offlineBudgetStorageKey = 'offline_budget';
  static const _useSeparateBudgetsStorageKey = 'use_separate_budgets';

  List<TransactionModel> get transactions => _transactions;

  void addTransaction(TransactionModel tx) {
    _transactions.insert(0, tx);
    _save();
    notifyListeners();
  }

  void deleteTransaction(int id) {
    _transactions.removeWhere((t) => t.id == id);
    _save();
    notifyListeners();
  }

  void updateTransaction(TransactionModel updated) {
    final index = _transactions.indexWhere((t) => t.id == updated.id);
    if (index != -1) {
      _transactions[index] = updated;
      _save();
      notifyListeners();
    }
  }

  void insertAt(int index, TransactionModel tx) {
    _transactions.insert(index, tx);
    _save();
    notifyListeners();
  }

  void deleteAt(int index) {
    _transactions.removeAt(index);
    _save();
    notifyListeners();
  }

  void deleteTransactionsForMonth(DateTime month) {
    _transactions.removeWhere((t) =>
        t.date.year == month.year && t.date.month == month.month);
    _save();
    notifyListeners();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_storagekey);

    _transactions.clear();

    if (data != null) {
      _transactions.addAll(
        data.map((e) => TransactionModel.fromJson(e)),
      );
    }

    _monthlyBudget = prefs.getDouble(_budgetStorageKey) ?? 0.0;
    _onlineBudget = prefs.getDouble(_onlineBudgetStorageKey) ?? 0.0;
    _offlineBudget = prefs.getDouble(_offlineBudgetStorageKey) ?? 0.0;
    _useSeparateBudgets = prefs.getBool(_useSeparateBudgetsStorageKey) ?? false;

    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _transactions.map((e) => e.toJson()).toList();
    await prefs.setStringList(_storagekey, data);
  }

  double get totalIncome =>
      _transactions.where((t) => t.isIncome).fold(0.0, (sum, t) => sum + t.amount);

  double get totalExpense =>
      _transactions.where((t) => !t.isIncome).fold(0.0, (sum, t) => sum + t.amount);

  double get balance => totalIncome - totalExpense;

  // Online breakdown
  double get onlineIncome =>
      _transactions.where((t) => t.isIncome && t.isOnline).fold(0.0, (sum, t) => sum + t.amount);

  double get onlineExpense =>
      _transactions.where((t) => !t.isIncome && t.isOnline).fold(0.0, (sum, t) => sum + t.amount);

  double get onlineBalance => onlineIncome - onlineExpense;

  // Offline breakdown
  double get offlineIncome =>
      _transactions.where((t) => t.isIncome && !t.isOnline).fold(0.0, (sum, t) => sum + t.amount);

  double get offlineExpense =>
      _transactions.where((t) => !t.isIncome && !t.isOnline).fold(0.0, (sum, t) => sum + t.amount);

  double get offlineBalance => offlineIncome - offlineExpense;

  List<TransactionModel> get recentTransactions => _transactions.take(10).toList();

  // Monthly Budget Management (Total, Online, and Offline)
  double _monthlyBudget = 0.0;
  double _onlineBudget = 0.0;
  double _offlineBudget = 0.0;
  bool _useSeparateBudgets = false;

  bool get useSeparateBudgets => _useSeparateBudgets;
  double get onlineBudget => _onlineBudget;
  double get offlineBudget => _offlineBudget;

  double get monthlyBudget =>
      _useSeparateBudgets ? (_onlineBudget + _offlineBudget) : _monthlyBudget;

  Future<void> setBudget(double value) async {
    _monthlyBudget = value;
    _useSeparateBudgets = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_budgetStorageKey, value);
    await prefs.setBool(_useSeparateBudgetsStorageKey, false);
    notifyListeners();
  }

  Future<void> setBudgets({
    required double totalBudget,
    double? onlineBudget,
    double? offlineBudget,
    bool useSeparate = false,
  }) async {
    _monthlyBudget = totalBudget;
    _onlineBudget = onlineBudget ?? 0.0;
    _offlineBudget = offlineBudget ?? 0.0;
    _useSeparateBudgets = useSeparate;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_budgetStorageKey, _monthlyBudget);
    await prefs.setDouble(_onlineBudgetStorageKey, _onlineBudget);
    await prefs.setDouble(_offlineBudgetStorageKey, _offlineBudget);
    await prefs.setBool(_useSeparateBudgetsStorageKey, _useSeparateBudgets);
    notifyListeners();
  }

  // Monthly statistics for a specific target month (defaults to current month)
  double getMonthlyExpense([DateTime? targetMonth]) {
    final target = targetMonth ?? DateTime.now();
    return _transactions
        .where((t) =>
            !t.isIncome &&
            t.date.year == target.year &&
            t.date.month == target.month)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double getMonthlyOnlineExpense([DateTime? targetMonth]) {
    final target = targetMonth ?? DateTime.now();
    return _transactions
        .where((t) =>
            !t.isIncome &&
            t.isOnline &&
            t.date.year == target.year &&
            t.date.month == target.month)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double getMonthlyOfflineExpense([DateTime? targetMonth]) {
    final target = targetMonth ?? DateTime.now();
    return _transactions
        .where((t) =>
            !t.isIncome &&
            !t.isOnline &&
            t.date.year == target.year &&
            t.date.month == target.month)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double getMonthlyIncome([DateTime? targetMonth]) {
    final target = targetMonth ?? DateTime.now();
    return _transactions
        .where((t) =>
            t.isIncome &&
            t.date.year == target.year &&
            t.date.month == target.month)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  List<TransactionModel> getMonthlyTransactions([DateTime? targetMonth]) {
    final target = targetMonth ?? DateTime.now();
    final list = _transactions
        .where((t) =>
            t.date.year == target.year &&
            t.date.month == target.month)
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Map<String, double> getMonthlyCategorySpending({
    DateTime? targetMonth,
    bool? isOnline,
  }) {
    final target = targetMonth ?? DateTime.now();
    final Map<String, double> map = {};
    for (final t in _transactions) {
      if (!t.isIncome &&
          t.date.year == target.year &&
          t.date.month == target.month) {
        if (isOnline != null && t.isOnline != isOnline) {
          continue;
        }
        map[t.category] = (map[t.category] ?? 0.0) + t.amount;
      }
    }
    return map;
  }

  double get spent => getMonthlyExpense();

  double get totalAvaliable => monthlyBudget;

  double get remaining => (monthlyBudget - getMonthlyExpense()).clamp(0.0, double.infinity);

  double get progress => monthlyBudget == 0.0
      ? 0.0
      : (getMonthlyExpense() / monthlyBudget).clamp(0.0, 1.0);
}
