import 'package:flutter/material.dart';
import '../models/diary_entry.dart';
import '../utils/date_formatter.dart';
import 'package:fl_chart/fl_chart.dart';

class MoodChart extends StatelessWidget {
  final List<DiaryEntry> entries;
  final DateTime startOfWeek;
  final DateTime endOfWeek;

  MoodChart({
    required this.entries,
    required this.startOfWeek,
    required this.endOfWeek,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0), // ✅ 좌우 간격 거의 없음
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white, // ✅ 거의 흰색에 가까운 연한 배경
          borderRadius: BorderRadius.zero, // ✅ 둥근 박스
        ),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '한 주 돌아보기',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              DateFormatter.formatWeekRange(startOfWeek, endOfWeek),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 24), // ✅ 텍스트와 그래프 간 여백
            Container(
              height: 200,
              width: double.infinity,
              child: entries.isEmpty ? _buildEmptyChart() : _buildMoodChart(),
            ),
          ],
        ),
      ),
    );
  }




  Widget _buildEmptyChart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart,
            size: 48,
            color: Colors.grey[300],
          ),
          SizedBox(height: 16),
          Text(
            '이번 주에 작성된 일기가 없습니다.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
          Text(
            '일기를 작성하고 기분을 기록해보세요.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodChart() {
    // 1주일치 데이터 준비 (월~일)
    Map<int, DiaryEntry?> weekData = {};

    // 초기화: 모든 요일에 null 할당
    for (int i = 1; i <= 7; i++) {
      weekData[i] = null;
    }

    // 데이터 매핑: 해당 요일에 일기가 있으면 할당
    for (var entry in entries) {
      final weekday = entry.date.weekday; // 1(월)~7(일)

      // 이번 주의 범위 내에 있는 항목만 추가
      if (entry.date.isAfter(startOfWeek.subtract(Duration(days: 1))) &&
          entry.date.isBefore(endOfWeek.add(Duration(days: 1)))) {
        // 이미 해당 요일에 항목이 있고, 현재 항목이 더 최신이면 업데이트
        if (weekData[weekday] == null ||
            entry.date.isAfter(weekData[weekday]!.date)) {
          weekData[weekday] = entry;
        }
      }
    }

    return LineChart(
      LineChartData(
        backgroundColor: Color(0xFFF8F8FA),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.04), // ✅ 더더 연하게
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final day = value.toInt();
                if (day < 1 || day > 7) return SizedBox.shrink();

                final date = startOfWeek.add(Duration(days: day - 1));
                final now = DateTime.now();

                final isToday = date.year == now.year &&
                    date.month == now.month &&
                    date.day == now.day;

                final textStyle = TextStyle(
                  fontSize: 14,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isToday ? Colors.deepPurple : Color(0xFF68737D),
                );

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ['월', '화', '수', '목', '금', '토', '일'][day - 1],
                      style: textStyle,
                    ),
                    Text(
                      '${date.month}.${date.day}',
                      style: textStyle,
                    ),
                  ],
                );
              },

            ),
          ),

          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: const Color(0xFFECECEC), width: 1),
        ),
        minX: 1,
        maxX: 7,
        minY: 0,
        maxY: 4,
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (int day = 1; day <= 7; day++)
                if (weekData[day] != null)
                  FlSpot(
                      day.toDouble(), 4 - weekData[day]!.mood.index.toDouble()) // Invert the mood index
            ],
            isCurved: true,
            color: Color(0xFFB39DDB), // colors 배열 대신 단일 color 속성 사용
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 6,
                  color: Color(0xFFB39DDB),
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Color(0xFFB39DDB).withOpacity(0.3),
              // 그라데이션 설정
              gradient: LinearGradient(
                colors: [
                  Color(0xFFB39DDB).withOpacity(0.3),
                  Color(0xFFB39DDB).withOpacity(0.1),
                ],
                stops: [0.5, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}