import 'package:flutter/material.dart';
import '../utils/date_formatter.dart';

class MonthSelector extends StatelessWidget {
  final List<String> availableMonths;
  final String? selectedMonth;
  final Function(String?) onMonthSelected;

  MonthSelector({
    required this.availableMonths,
    required this.selectedMonth,
    required this.onMonthSelected,
  });

  @override
  Widget build(BuildContext context) {
    final sortedMonths = List<String>.from(availableMonths)..sort(); // 오름차순 정렬

    return Container(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: sortedMonths.length,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final month = sortedMonths[index];
          final isSelected = month == selectedMonth;
          final monthOnly = DateFormatter.formatMonthOnly(month);

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => onMonthSelected(month),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected ? Color(0xFFB39DDB) : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Color(0xFFB39DDB) : Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    monthOnly,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
