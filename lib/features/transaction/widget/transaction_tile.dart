import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_expense_tracker/models/transaction_model.dart';

class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;

  const TransactionTile({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final color = transaction.isIncome ? Colors.green : Colors.red; 
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(
          transaction.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
          color: color,
        ),
      ),

      title: Text(transaction.category),
      subtitle: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat.yMMMd().format(transaction.date),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: transaction.isOnline
                  ? Colors.blue.withValues(alpha: 0.12)
                  : Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  transaction.isOnline
                      ? Icons.credit_card_outlined
                      : Icons.payments_outlined,
                  size: 12,
                  color: transaction.isOnline ? Colors.blue : Colors.orange.shade800,
                ),
                const SizedBox(width: 3),
                Text(
                  transaction.isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: transaction.isOnline
                        ? Colors.blue
                        : Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      trailing: Text(
        '${transaction.isIncome ? '+' : '-'}₹${transaction.amount}',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}