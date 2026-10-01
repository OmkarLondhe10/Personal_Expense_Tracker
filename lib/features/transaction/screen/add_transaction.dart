import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_expense_tracker/models/transaction_model.dart';
import 'package:personal_expense_tracker/provider/transaction_provider.dart';
import 'package:provider/provider.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionModel? transaction;

  const AddTransactionScreen({super.key, this.transaction});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _amountController = TextEditingController();

  late List<String> categories;
  bool isIncome = false;
  bool isOnline = true;
  String category = 'Food';
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();

    categories = ['Food', 'Transport', 'Bills', 'Shopping', 'Other'];

    final tx = widget.transaction;

    if (tx != null) {
      _amountController.text = tx.amount.toString();
      isIncome = tx.isIncome;
      isOnline = tx.isOnline;
      category = tx.category;
      selectedDate = tx.date;

      if (!categories.contains(category)) {
        categories.insert(0, category);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(), // change this if you want to allow future dates
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    if (target == today) return 'Today';
    if (target == today.subtract(const Duration(days: 1))) return 'Yesterday';

    return DateFormat('dd MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.transaction == null ? 'Add Transaction' : 'Edit Transaction',
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _amountController,
              cursorColor: Colors.black,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter Amount',
                prefixText: '₹',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // DATE PICKER FIELD
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDate(selectedDate)),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                value: isIncome,
                title: Text(isIncome ? 'Income' : 'Expense'),
                secondary: Icon(
                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isIncome ? Colors.green : Colors.red,
                ),
                onChanged: (value) {
                  setState(() {
                    isIncome = value;
                  });
                },
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: category,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: categories.map((cat) {
                      return DropdownMenuItem<String>(value: cat, child: Text(cat));
                    }).toList(),
                    onChanged: (value) async {
                      if (value == 'Other') {
                        final defaultCategories = ['Food', 'Transport', 'Bills', 'Shopping', 'Other'];
                        final previousCategory = category;
                        final initial = defaultCategories.contains(previousCategory)
                            ? ''
                            : previousCategory;

                        final customCategory =
                            await _showCategoryDialog(initialCategory: initial);

                        if (customCategory != null && customCategory.isNotEmpty) {
                          setState(() {
                            if (!categories.contains(customCategory)) {
                              categories.insert(0, customCategory);
                            }
                            category = customCategory;
                          });
                        } else {
                          setState(() {
                            category = previousCategory;
                          });
                        }
                      } else {
                        setState(() {
                          category = value!;
                        });
                      }
                    },
                  ),
                ),
                if (!['Food', 'Transport', 'Bills', 'Shopping', 'Other']
                    .contains(category)) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Edit Category Name',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      final updated =
                          await _showCategoryDialog(initialCategory: category);
                      if (updated != null && updated.isNotEmpty) {
                        setState(() {
                          final index = categories.indexOf(category);
                          if (index != -1) {
                            categories[index] = updated;
                          } else {
                            categories.insert(0, updated);
                          }
                          category = updated;
                        });
                      }
                    },
                  ),
                ],
              ],
            ),

            const SizedBox(height: 20),

            // PAYMENT MODE SELECTOR (Online vs Offline)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Mode',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('Online'),
                        icon: Icon(Icons.credit_card_outlined),
                      ),
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('Offline / Cash'),
                        icon: Icon(Icons.payments_outlined),
                      ),
                    ],
                    selected: {isOnline},
                    onSelectionChanged: (newSelection) {
                      setState(() {
                        isOnline = newSelection.first;
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  final amount = double.tryParse(_amountController.text);
                  if (amount == null) return;

                  if (widget.transaction == null) {
                    final tx = TransactionModel(
                      id: DateTime.now().microsecondsSinceEpoch,
                      amount: amount,
                      category: category,
                      date: selectedDate,
                      isIncome: isIncome,
                      isOnline: isOnline,
                    );

                    context.read<TransactionProvider>().addTransaction(tx);
                  } else {
                    final updated = TransactionModel(
                      id: widget.transaction!.id,
                      amount: amount,
                      category: category,
                      isIncome: isIncome,
                      date: selectedDate,
                      isOnline: isOnline,
                    );

                    context.read<TransactionProvider>().updateTransaction(
                      updated,
                    );
                  }

                  Navigator.pop(context);
                },
                child: const Text(
                  "Save Transaction",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showCategoryDialog({String? initialCategory}) async {
    final controller = TextEditingController(text: initialCategory ?? '');
    if (controller.text.isNotEmpty) {
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
    }

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(initialCategory != null && initialCategory.isNotEmpty
              ? 'Edit Category'
              : 'Add Category'),
          content: TextField(
            controller: controller,
            cursorColor: Colors.black,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'E.g: Salary, Freelance',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.black54),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.black54),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.black, width: 1.5),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                final trimmed = controller.text.trim();
                Navigator.pop(context, trimmed.isEmpty ? null : trimmed);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
