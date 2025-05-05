class DateFormatter {
  // 상세한 날짜 형식 (YYYY년 MM월 DD일 요일)
  static String formatFullDate(DateTime date) {
    final List<String> weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    final String weekday = weekdays[date.weekday - 1]; // weekday는 1(월)~7(일)이므로 -1 필요

    return '${date.year}년 ${date.month}월 ${date.day}일 $weekday';
  }

  // 짧은 날짜 형식 (MM/DD 요일)
  static String formatShortDate(DateTime date) {
    final List<String> weekdayShort = ['월', '화', '수', '목', '금', '토', '일'];
    final String weekday = weekdayShort[date.weekday - 1];

    return '${date.month}/${date.day} ($weekday)';
  }

  // 월 형식 (YYYY-MM)
  static String formatMonth(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  // 월 형식 (YYYY-MM)
  static String formatMonthOnly(String yearMonth) {
    final parts = yearMonth.split('-');
    if (parts.length == 2) {
      return '${parts[1]}';
    }
    return yearMonth; // 예외 처리
  }

  // 년월 형식 (YYYY년 MM월)
  static String formatYearMonth(String yearMonth) {
    final parts = yearMonth.split('-');
    return '${parts[0]}년 ${parts[1]}월';
  }

  // 주 범위 형식 (YYYY.MM.DD ~ YYYY.MM.DD)
  static String formatWeekRange(DateTime startOfWeek, DateTime endOfWeek) {
    String formatDate(DateTime date) {
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    }

    return '${formatDate(startOfWeek)} ~ ${formatDate(endOfWeek)}';
  }

  // 현재 주의 시작(월요일)과 끝(일요일) 구하기
  static Map<String, DateTime> getCurrentWeekRange(DateTime date) {
    // 현재 날짜의 요일 (1: 월요일, 7: 일요일)
    final int currentWeekday = date.weekday;

    // 이번 주 월요일 계산
    final DateTime startOfWeek = date.subtract(Duration(days: currentWeekday - 1));

    // 이번 주 일요일 계산
    final DateTime endOfWeek = startOfWeek.add(Duration(days: 6));

    return {
      'start': DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
      'end': DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day, 23, 59, 59),
    };
  }
}