import 'package:flutter/material.dart';
import '../models/todo_item.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class TodoCard extends StatelessWidget {
  final TodoItem todo;
  final Function(bool?) onStatusChanged;
  final void Function() onMorePressed;
  final void Function()? onEdit;  // Make optional with nullable type
  final void Function()? onDelete;  // Make optional with nullable type

  const TodoCard({
    Key? key,
    required this.todo,
    required this.onStatusChanged,
    required this.onMorePressed,
    this.onEdit,
    this.onDelete,  // Optional parameter
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 마감일까지 남은 일수 계산
    int? daysUntilDue;
    Color? dueDateColor;
    String? dueDateText;

    if (todo.dueDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDate = DateTime(todo.dueDate!.year, todo.dueDate!.month, todo.dueDate!.day);

      daysUntilDue = dueDate.difference(today).inDays;

      if (daysUntilDue < 0) {
        dueDateColor = Colors.red;
        dueDateText = '${(-daysUntilDue)}일 지남';
      } else if (daysUntilDue == 0) {
        dueDateColor = Colors.orange;
        dueDateText = '오늘까지';
      } else if (daysUntilDue == 1) {
        dueDateColor = Colors.orange;
        dueDateText = '내일까지';
      } else if (daysUntilDue <= 3) {
        dueDateColor = Colors.amber;
        dueDateText = '${daysUntilDue}일 남음';
      } else {
        dueDateColor = Colors.grey;
        dueDateText = '${daysUntilDue}일 남음';
      }
    }

    return Card(
      color: const Color(0xFFFFFFFF),
      margin: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero, // 네모 모양으로 설정
      ),
      child: InkWell(
        onTap: onMorePressed,  // 카드 전체에 onTap 적용
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CheckboxTheme(
                data: CheckboxThemeData(
                  side: BorderSide(width: 1.0, color: Colors.grey), // 테두리 두께와 색상 설정
                ),
                child: Transform.scale(
                  scale: 0.8, // 0.8배 크기로 축소 (1.0이 기본 크기)
                  child: Checkbox(
                    value: todo.isCompleted,
                    onChanged: (value) => onStatusChanged(value!),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      todo.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: todo.isCompleted ? Colors.grey : Colors.black,
                        decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        if (!todo.isAllDay && todo.startTime != null)
                          Text(
                            todo.getFormattedStartTime(context),
                            style: TextStyle(
                              fontSize: 14,
                              color: todo.isCompleted ? Colors.grey : Colors.black54,
                            ),
                          ),

                        // 마감일 표시 추가
                        if (dueDateText != null)
                          Row(
                            children: [
                              if (todo.reminder != null)
                                Icon(Icons.notifications, color: Colors.grey[400], size: 16),
                              if (todo.isRepeating)
                                Icon(Icons.repeat, color: Colors.grey[400], size: 16),
                              SizedBox(width: 8),
                              Icon(Icons.schedule, size: 12, color: dueDateColor),
                              SizedBox(width: 2),
                              Text(
                                dueDateText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: todo.isCompleted ? Colors.grey : dueDateColor,
                                  fontWeight: daysUntilDue != null && daysUntilDue <= 1
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // 오른쪽 아이콘 영역
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [

                  buildBarLevelIndicator(level: todo.importance, fillColor: Color(0xFFAEDEFF)),
                  SizedBox(width: 8),
                  buildBarLevelIndicator(level: todo.urgency, fillColor: Color(0xFFFFD99F)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 신호, 안테나바
  Widget buildSignalLevelIndicator({
    required int level,
    required Color color,
    int maxLevel = 5,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end, // 중요! 아래 정렬
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxLevel, (index) {
        double height = (index + 1) * 3.0 + 4;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          width: 3,
          height: height,
          decoration: BoxDecoration(
            color: index < level ? color : color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }


  // 원형 인디케이터
  Widget buildCircularLevelIndicator({
    required int level,
    required Color color,
    double radius = 14.0,
  }) {
    return CircularPercentIndicator(
      radius: radius,
      lineWidth: 3.0,
      percent: (level.clamp(0, 5)) / 5,
      progressColor: color,
      backgroundColor: color.withOpacity(0.2),
      circularStrokeCap: CircularStrokeCap.round,
      center: Text(
        '$level',
        style: TextStyle(fontSize: radius * 0.7, fontWeight: FontWeight.bold),
      ),
    );
  }

  // 컬러, 태그 방식
  Widget buildLabelIndicator({
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  // 도트
  Widget buildDotLevelIndicator({
    required int level,
    required Color fillColor,
    int maxLevel = 5,
    double dotSize = 6.0,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxLevel, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: index < level ? fillColor : fillColor.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }

  Widget buildBarLevelIndicator({ // 세로 직사각형
    required int level,
    required Color fillColor,
    int maxLevel = 5,
    double width = 3,
    double height = 10,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxLevel, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          width: width,
          height: height * ((index < level) ? 1 : 0.4),
          decoration: BoxDecoration(
            color: index < level ? fillColor : fillColor.withOpacity(0.3),
            borderRadius: BorderRadius.circular(1.5),
          ),
        );
      }),
    );
  }

  Widget buildCapsuleLevelIndicator({ // 가로 직사각형
    required int level, // 0 ~ 5
    required Color fillColor,
    Color backgroundColor = const Color(0xFFEFEFEF),
  }) {
    return Container(
      width: 40,
      height: 3,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(9), // 높이의 절반으로 완전한 알약 모양
      ),
      child: Stack(
        children: [
          // 채워지는 부분
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: (40 * level / 5).clamp(0.0, 40.0), // 레벨에 따른 너비 계산
            height: 3,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(9),
                right: level == 5 ? Radius.circular(9) : Radius.zero,
              ),
            ),
          ),
          // 작은 구분선들 (선택사항)
          if (level > 0) // 채워진 부분이 있을 때만 표시
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (index) {
                double position = (index + 1) * 12.0; // 60 / 5 = 12씩 간격
                return Positioned(
                  left: position - 0.5,
                  child: Container(
                    width: 1,
                    height: 18,
                    color: backgroundColor.withOpacity(0.4),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  // 완전히 부드러운 버전 (구분선 없음)
  Widget buildSmoothCapsuleLevelIndicator({
    required int level, // 0 ~ 5
    required Color fillColor,
    Color backgroundColor = const Color(0xFFEFEFEF),
  }) {
    return Container(
      width: 60,
      height: 18,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: (60 * level / 5).clamp(0.0, 60.0),
          height: 18,
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(9),
          ),
        ),
      ),
    );
  }
}