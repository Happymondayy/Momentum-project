import 'package:flutter/material.dart';
import '../models/diary_entry.dart';
import '../utils/date_formatter.dart';
import '../dialogs/diary_dialog.dart';

class DiaryList extends StatefulWidget {
  final List<DiaryEntry> entries;
  final Function(DiaryEntry) onEditDiary;
  final Function(DiaryEntry) onDeleteDiary;
  final Function({required DateTime date, required MoodState mood, required String content, required String userId}) onSaveDiary;

  DiaryList({
    required this.entries,
    required this.onEditDiary,
    required this.onDeleteDiary,
    required this.onSaveDiary,
  });

  @override
  _DiaryListState createState() => _DiaryListState();
}

class _DiaryListState extends State<DiaryList> {
  Set<int> _expandedCards = <int>{};

  void _showDiaryDialog(BuildContext context, DiaryEntry entry) {
    showDialog(
      context: context,
      builder: (context) => DiaryDialog(
        diary: entry,
        currentUserId: entry.userId,
        initialDate: entry.date,
        initialMood: entry.mood,
        initialContent: entry.content,
        isEditing: true,
        onSave: ({required DateTime date, required MoodState mood, required String content, required String userId}) {
          // 수정된 일기 객체 생성
          final updatedEntry = DiaryEntry(
            id: entry.id,
            userId: entry.userId,
            date: date,
            content: content,
            mood: mood,
          );
          widget.onEditDiary(updatedEntry);
        },
        onDelete: (diary) {
          widget.onDeleteDiary(diary);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '아직 작성된 일기가 없어요',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '오늘의 기분과 생각을 기록해보세요',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.grey[50], // 배경을 약간 회색으로
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: widget.entries.length,
        itemBuilder: (context, index) {
          final entry = widget.entries[index];
          final isLast = index == widget.entries.length - 1;
          return _buildDiaryCard(context, entry, index, isLast);
        },
      ),
    );
  }

  Widget _buildDiaryCard(BuildContext context, DiaryEntry entry, int index, bool isLast) {
    final isExpanded = _expandedCards.contains(index);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: GestureDetector(
        onTap: () => _showDiaryDialog(context, entry),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white, // 카드 배경은 흰색으로
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더 (날짜, 요일, 기분)
                Row(
                  children: [
                    // 날짜와 요일 - 단순하게 변경
                    Text(
                      '${entry.date.month}월 ${entry.date.day}일',
                      style: TextStyle(
                        fontSize: 20, // 크기 키움
                        fontWeight: FontWeight.bold,
                        color: Colors.black, // 검은색으로
                      ),
                    ),
                    SizedBox(width: 3),
                    Text(
                      _getWeekday(entry.date),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Spacer(),
                    // 기분 상태
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: entry.mood.color,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: entry.mood.color.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        entry.mood.koreanName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // 일기 내용
                LayoutBuilder(
                  builder: (context, constraints) {
                    final textPainter = TextPainter(
                      text: TextSpan(
                        text: entry.content,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                          height: 1.6,
                        ),
                      ),
                      maxLines: 3,
                      textDirection: TextDirection.ltr,
                    );
                    textPainter.layout(maxWidth: constraints.maxWidth);
                    final shouldShowExpansion = textPainter.didExceedMaxLines;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedSize(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: Text(
                            entry.content,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                              height: 1.6,
                              letterSpacing: 0.3,
                            ),
                            maxLines: isExpanded ? null : 3,
                            overflow: isExpanded ? null : TextOverflow.ellipsis,
                          ),
                        ),

                        // 더보기/접기 버튼
                        if (shouldShowExpansion) ...[
                          SizedBox(height: 12),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isExpanded) {
                                  _expandedCards.remove(index);
                                } else {
                                  _expandedCards.add(index);
                                }
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isExpanded ? '접기' : '더보기',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    isExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    size: 18,
                                    color: Colors.grey[700],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getWeekday(DateTime date) {
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return weekdays[date.weekday - 1];
  }
}