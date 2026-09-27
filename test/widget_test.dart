import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_expense_tracker/features/transaction/screen/transaction_screen.dart';
import 'package:personal_expense_tracker/provider/transaction_provider.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('App smoke test: TransactionScreen loads properly', (WidgetTester tester) async {
    final provider = TransactionProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<TransactionProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: TransactionScreen(),
        ),
      ),
    );

    expect(find.text('Transactions'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
