import 'package:flutter/material.dart';
import '../models/diary_entry.dart';
import '../utils/date_formatter.dart';

class DiaryList extends StatelessWidget {
  final List<DiaryEntry> entries;
  final Function(DiaryEntry) onViewDiary;
  final Function(DiaryEntry) onEditDiary;
  final Function(DiaryEntry) onDeleteDiary;

  DiaryList({
    required this.entries,
    required this.onViewDiary,
    required this.onEditDiary,
    required this.onDeleteDiary,
  });

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
      onTap: () => onViewDiary(entry),
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단: 아이콘 + 날짜 + 메뉴
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(entry.mood.icon, color: entry.mood.color, size: 22),
                      SizedBox(width: 8),
                      Text(
                        DateFormatter.formatShortDate(entry.date),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  PopupMenuButton(
                    icon: Icon(Icons.more_vert, size: 20),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: Colors.blue, size: 20),
                            SizedBox(width: 8),
                            Text('수정'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text('삭제'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') onEditDiary(entry);
                      else if (value == 'delete') onDeleteDiary(entry);
                    },
                  ),
                ],
              ),
              SizedBox(height: 10),
              Divider(),
              SizedBox(height: 10),
              // 본문: 제한 없이 전체 출력
              Text(
                entry.content,
                style: TextStyle(fontSize: 15, color: Colors.black87, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
