import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum TransactionDateFilter {
  all,
  oneWeek,
  twoWeeks,
  threeWeeks,
  oneMonth,
  custom;

  String get label {
    switch (this) {
      case TransactionDateFilter.all:
        return 'All';
      case TransactionDateFilter.oneWeek:
        return 'Past 1 Week';
      case TransactionDateFilter.twoWeeks:
        return 'Past 2 Weeks';
      case TransactionDateFilter.threeWeeks:
        return 'Past 3 Weeks';
      case TransactionDateFilter.oneMonth:
        return 'Past 1 Month';
      case TransactionDateFilter.custom:
        return 'Custom Date';
    }
  }

  String get chipLabel {
    switch (this) {
      case TransactionDateFilter.all:
        return 'All';
      case TransactionDateFilter.oneWeek:
        return '1 Week';
      case TransactionDateFilter.twoWeeks:
        return '2 Weeks';
      case TransactionDateFilter.threeWeeks:
        return '3 Weeks';
      case TransactionDateFilter.oneMonth:
        return '1 Month';
      case TransactionDateFilter.custom:
        return 'Calendar';
    }
  }

  DateTimeRange? getDateRange({DateTimeRange? customRange, DateTime? referenceDate}) {
    final now = referenceDate ?? DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    switch (this) {
      case TransactionDateFilter.all:
        return null;
      case TransactionDateFilter.oneWeek:
        return DateTimeRange(
          start: startOfToday.subtract(const Duration(days: 7)),
          end: endOfToday,
        );
      case TransactionDateFilter.twoWeeks:
        return DateTimeRange(
          start: startOfToday.subtract(const Duration(days: 14)),
          end: endOfToday,
        );
      case TransactionDateFilter.threeWeeks:
        return DateTimeRange(
          start: startOfToday.subtract(const Duration(days: 21)),
          end: endOfToday,
        );
      case TransactionDateFilter.oneMonth:
        return DateTimeRange(
          start: startOfToday.subtract(const Duration(days: 30)),
          end: endOfToday,
        );
      case TransactionDateFilter.custom:
        if (customRange != null) {
          return DateTimeRange(
            start: DateTime(
              customRange.start.year,
              customRange.start.month,
              customRange.start.day,
              0,
              0,
              0,
            ),
            end: DateTime(
              customRange.end.year,
              customRange.end.month,
              customRange.end.day,
              23,
              59,
              59,
              999,
            ),
          );
        }
        return null;
    }
  }

  String getDisplaySubtitle({DateTimeRange? customRange, DateTime? referenceDate}) {
    final range = getDateRange(customRange: customRange, referenceDate: referenceDate);
    if (range == null) {
      return 'All time';
    }

    final isSameDay = range.start.year == range.end.year &&
        range.start.month == range.end.month &&
        range.start.day == range.end.day;

    if (isSameDay) {
      return DateFormat('dd MMM yyyy').format(range.start);
    }

    final startFormat = range.start.year == range.end.year ? 'dd MMM' : 'dd MMM yyyy';
    const endFormat = 'dd MMM yyyy';
    return '${DateFormat(startFormat).format(range.start)} – ${DateFormat(endFormat).format(range.end)}';
  }
}
