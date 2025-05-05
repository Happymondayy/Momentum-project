import 'package:flutter/material.dart';
import '../models/diary_entry.dart';
import '../utils/date_formatter.dart';
import '../dialogs/diary_dialog.dart';

class DiaryList extends StatelessWidget {
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

  void _showDiaryDialog(BuildContext context, DiaryEntry entry) {
    showDialog(
      context: context,
      builder: (context) => DiaryDialog(
        diary: entry,
        currentUserId: entry.userId,
        initialDate: entry.date,
        initialMood: entry.mood,
        initialContent: entry.content,
        onSave: ({required DateTime date, required MoodState mood, required String content, required String userId}) {
          onSaveDiary(userId: entry.userId, date: date, mood: mood, content: content);
        },
        onDelete: (diary) {
          onDeleteDiary(diary);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
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

    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: entries.length,
      separatorBuilder: (context, index) => SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _buildDiaryCard(context, entry);
      },
    );
  }

  Widget _buildDiaryCard(BuildContext context, DiaryEntry entry) {
    return InkWell(
      onTap: () => _showDiaryDialog(context, entry),
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단: 기분 원형 그라데이션 + 날짜
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      entry.mood.getGradientCircle(size: 24), // 새로운 기분 표시 방식
                      SizedBox(width: 10),
                      Text(
                        DateFormatter.formatShortDate(entry.date),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    entry.mood.koreanName,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Divider(),
              SizedBox(height: 10),
              // 본문 내용: 그라데이션으로 흐리게 처리
              Container(
                width: double.infinity,
                constraints: BoxConstraints(maxHeight: 100),
                child: Stack(
                  children: [
                    Text(
                      entry.content,
                      style: TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                          height: 1.4
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.fade,
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.0),
                              Colors.white.withOpacity(0.9),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
