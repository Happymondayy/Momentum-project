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
          widget.onSaveDiary(userId: entry.userId, date: date, mood: mood, content: content);
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
            Icon(Icons.book_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '작성된 일기가 없습니다.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: widget.entries.length,
      itemBuilder: (context, index) {
        final entry = widget.entries[index];
        final isLast = index == widget.entries.length - 1;
        return _buildTimelineItem(context, entry, index, isLast);
      },
    );
  }

  Widget _buildTimelineItem(BuildContext context, DiaryEntry entry, int index, bool isLast) {
    final isExpanded = _expandedCards.contains(index);
    final shouldShowExpansion = entry.content.length > 110;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타임라인 왼쪽 (색깔 네모 + 세로선)
          Column(
            children: [
              // 상단 헤더 (색깔 네모, 날짜, 요일, 기분)
              Row(
                children: [
                  // 색깔 직사각형
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: entry.mood.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: 12),
                  // 날짜
                  Text(
                    '${entry.date.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(width: 8),
                  // 요일
                  Text(
                    _getWeekday(entry.date),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4,),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: entry.mood.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: entry.mood.color.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  entry.mood.koreanName,
                  style: TextStyle(
                    fontSize: 10,
                    color: entry.mood.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 8),
              // 세로선 (마지막이 아닐 때만)
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.grey[300]!,
                          Colors.grey[200]!.withOpacity(0.3),
                        ],
                      ),
                    ),
                    margin: EdgeInsets.only(left: 2),
                  ),
                ),
            ],
          ),
          SizedBox(width: 16),

          // 오른쪽 카드 내용
          Expanded(
            child: Column(
              children: [
                InkWell(
                  onTap: () => _showDiaryDialog(context, entry),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFFFBFBFB), // 눈이 편한 흰색
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 일기 내용
                        AnimatedSize(
                          duration: Duration(milliseconds: 300),
                          child: Text(
                            isExpanded
                                ? entry.content
                                : (shouldShowExpansion
                                ? entry.content.substring(0, 110) + '...'
                                : entry.content),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                        ),

                        // 더보기/접기 버튼
                        if (shouldShowExpansion) ...[
                          SizedBox(height: 8),
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
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isExpanded ? '접기' : '더보기',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: entry.mood.color,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    isExpanded
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    size: 16,
                                    color: entry.mood.color,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (!isLast) SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getWeekday(DateTime date) {
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return weekdays[date.weekday - 1];
  }
}