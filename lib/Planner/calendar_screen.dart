import 'package:flutter/material.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  _CalendarSectionState createState() => _CalendarSectionState();
}

class _CalendarSectionState extends State<CalendarScreen> {
  List<String> months = [
    '1월', '2월', '3월', '4월', '5월', '6월', '7월', '8월', '9월', '10월', '11월', '12월'
  ];
  int currentMonthIndex = 9; // 10월
  int selectedDay = 3; // 기본적으로 선택된 날짜 3일

  // 2025년 달력 기준으로 각 달의 첫날(0: 일, 1: 월, ..., 6: 토)
  List<int> firstDaysOfMonth = [
    3,  // 1월 1일은 수요일 (3)
    6,  // 2월 1일은 토요일 (6)
    6,  // 3월 1일은 토요일 (6)
    2,  // 4월 1일은 화요일 (2)
    4,  // 5월 1일은 목요일 (4)
    0,  // 6월 1일은 일요일 (0)
    2,  // 7월 1일은 화요일 (2)
    5,  // 8월 1일은 금요일 (5)
    1,  // 9월 1일은 월요일 (1)
    3,  // 10월 1일은 수요일 (3)
    6,  // 11월 1일은 토요일 (6)
    1   // 12월 1일은 월요일 (1)
  ];

  // 각 달의 날짜 수 (2025년 기준)
  List<int> daysInMonth = [
    31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
  ];

  @override
  Widget build(BuildContext context) {
    int daysInMonthCurrent = daysInMonth[currentMonthIndex];
    int firstDayOfMonth = firstDaysOfMonth[currentMonthIndex];
    List<List<int?>> weeks = _generateWeeks(daysInMonthCurrent, firstDayOfMonth);

    return Column(
      children: [
        // 상단에 월 표시
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GestureDetector(
            onTap: _changeMonth, // 달 클릭 시 달 변경
            child: Text(
              months[currentMonthIndex], // 현재 달 표시
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // 날짜를 7일씩 표시, 페이지뷰로 스크롤할 수 있도록 설정
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: SizedBox(
            height: 70, // 한 페이지의 높이 설정 (요일 + 7일)
            child: PageView.builder(
              itemCount: weeks.length,
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, pageIndex) {
                List<int?> week = weeks[pageIndex];
                return Column(
                  children: [
                    // 요일을 표시하는 부분
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN']
                          .map((day) => Text(
                        day,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade600),
                      ))
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    // 날짜를 표시하는 부분
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: week.map((day) {
                        // null인 값은 표시하지 않도록 처리
                        if (day == null) {
                          return Container(); // null인 날짜는 빈 컨테이너로 처리
                        }
                        bool isSelected = day == selectedDay;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedDay = day;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              children: [
                                _buildDateCircle(day, isSelected),
                                const SizedBox(height: 6),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // 날짜 원을 그리는 메소드
  Widget _buildDateCircle(int day, bool isSelected) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF9D8CFF) : Colors.transparent,
        shape: BoxShape.circle,
        boxShadow: isSelected
            ? [BoxShadow(color: const Color(0xFF9D8CFF).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
            : null,
      ),
      child: Center(
        child: Text(
          '$day', // 빈 날짜는 표시하지 않음
          style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black),
        ),
      ),
    );
  }

  // 점을 표시하는 메소드
  Widget _buildDotMarker() {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(color: const Color(0xFF9D8CFF), shape: BoxShape.circle),
    );
  }

  // 달을 변경하는 메소드
  void _changeMonth() {
    setState(() {
      currentMonthIndex = (currentMonthIndex + 1) % 12; // 1월부터 12월까지 순차적으로 변경
    });
  }

  // 날짜를 주 단위로 분리하여 주 리스트 생성
  List<List<int?>> _generateWeeks(int totalDays, int firstDayOfMonth) {
    List<List<int?>> weeks = [];
    List<int?> currentWeek = [];

    // 첫 번째 주는 첫날부터 시작
    for (int i = 0; i < firstDayOfMonth; i++) {
      currentWeek.add(null); // 첫날 이전은 빈칸
    }

    // 날짜 배열 생성
    for (int day = 1; day <= totalDays; day++) {
      currentWeek.add(day);
      if (currentWeek.length == 7 || day == totalDays) {
        weeks.add(List.from(currentWeek));
        currentWeek.clear();
      }
    }

    // 마지막 주가 7일 미만일 경우 빈 날짜를 추가하여 7일로 맞추기
    if (currentWeek.isNotEmpty) {
      while (currentWeek.length < 7) {
        currentWeek.add(null); // null로 빈 칸을 의미
      }
      weeks.add(currentWeek);
    }

    return weeks;
  }
}
