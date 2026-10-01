import 'dart:convert';

class TransactionModel {
  final int id;
  final double amount;
  final String category;
  final DateTime date;
  final bool isIncome;
  final bool isOnline;

  TransactionModel({
    required this.id, 
    required this.amount, 
    required this.category, 
    required this.date, 
    required this.isIncome,
    this.isOnline = true,
  });

Map<String, dynamic> toMap(){
  return{
    'id':id,
    'amount':amount,
    'category': category,
    'date': date.toIso8601String(),
    'isIncome': isIncome,
    'isOnline': isOnline,
  };
}

factory TransactionModel.fromMap(Map<String, dynamic> map) {
  return TransactionModel(
    id: map['id'] ?? 0,
    amount: (map['amount'] ?? 0).toDouble(),
    category: map['category'] ?? '',
    date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
    isIncome: map['isIncome'] ?? false,
    isOnline: map['isOnline'] ?? true,
  );
}

String toJson ()=> json.encode(toMap());
  factory TransactionModel.fromJson(String source) => TransactionModel.fromMap(json.decode(source));
}