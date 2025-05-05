import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/diary_entry.dart';
import '../utils/date_formatter.dart';
import '../widgets/mood_chart.dart';
import '../widgets/month_selector.dart';
import '../widgets/diary_list.dart';
import '../dialogs/diary_dialog.dart';
import 'package:momentum_planner/bottom_nav.dart';


class DiaryScreen extends StatefulWidget {
  final String userId;
  const DiaryScreen({Key? key, required this.userId}) : super(key: key); // 추가
  @override
  _DiaryScreenState createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  List<DiaryEntry> _diaryEntries = [];
  List<String> _availableMonths = [];
  String? _selectedMonth;
  bool _isLoading = true;
  String? _currentUserId; // 받은 userId 저장용

  // 주간 차트용 날짜 범위
  late DateTime _startOfWeek;
  late DateTime _endOfWeek;

  @override
  void initState() {
    super.initState();
    _currentUserId = widget.userId;
    print('✅ DiaryScreen에서 받은 userId = $_currentUserId');
    _initWeekRange();
    _loadData();
  }

  void _initWeekRange() {
    final weekRange = DateFormatter.getCurrentWeekRange(DateTime.now());
    _startOfWeek = weekRange['start']!;
    _endOfWeek = weekRange['end']!;
  }

  Future<void> _loadData() async {
    if (_currentUserId == null) {
      print('사용자 ID가 없습니다.');
      return;
    }

    try {
      // 현재 사용자의 일기만 가져오기 (복합 인덱스 요구 없이 수정)
      final QuerySnapshot diarySnapshot = await FirebaseFirestore.instance
          .collection('diaries')
          .where('userId', isEqualTo: _currentUserId) // userId가 같은 데이터만
          .get();

      // 가져온 데이터를 메모리에서 정렬 (Firestore에서 정렬하지 않음)
      final entries = diarySnapshot.docs
          .map((doc) => DiaryEntry.fromFirestore(doc))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date)); // 메모리에서 날짜 내림차순 정렬

      // 현재 연도 기준으로 1월~12월 리스트 생성
      final now = DateTime.now();
      final currentYear = now.year;

      final allMonths = List.generate(12, (i) {
        final month = i + 1;
        return '$currentYear-${month.toString().padLeft(2, '0')}';
      });

      // 상태 업데이트
      setState(() {
        _diaryEntries = entries;
        _availableMonths = allMonths; // 항상 12개월 다 표시
        _selectedMonth = DateFormatter.formatMonth(now); // 기본 선택 월: 현재 월
        _isLoading = false;
      });
    } catch (e) {
      print('일기 데이터 로딩 오류: $e');
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('데이터를 불러오는 중 오류가 발생했습니다.')),
      );
    }
  }

  // 선택된 월에 해당하는 일기만 필터링
  List<DiaryEntry> get _filteredEntries {
    if (_selectedMonth == null) return [];

    final parts = _selectedMonth!.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    return _diaryEntries.where((entry) {
      return entry.date.year == year && entry.date.month == month;
    }).toList();
  }

  // 이번 주의 일기만 필터링
  List<DiaryEntry> get _thisWeekEntries {
    return _diaryEntries.where((entry) {
      return entry.date.isAfter(_startOfWeek.subtract(Duration(days: 1))) &&
          entry.date.isBefore(_endOfWeek.add(Duration(days: 1)));
    }).toList();
  }

  void _showAddDiaryDialog() {
    // 일기 추가 팝업을 띄우는 함수
    showDialog(
      context: context,
      builder: (dialogContext) {
        return DiaryDialog(
          currentUserId: widget.userId,
          onSave: ({required DateTime date, required MoodState mood, required String content, required String userId}) async {
            try {
              final diaryData = {
                'userId': _currentUserId,
                'date': Timestamp.fromDate(date),
                'content': content,
                'mood': mood.index,
              };

              await FirebaseFirestore.instance.collection('diaries').add(diaryData);

              await _loadData();

            } catch (e) {
              print('일기 작성 오류: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('일기 작성 중 오류가 발생했습니다.')),
              );
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = _currentUserId ?? '알 수 없음';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(40.0),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            '일기',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDiaryDialog,
        backgroundColor: Color(0xFFB39DDB),
        child: Icon(Icons.add),
        tooltip: '새 일기 작성',
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 4),
                child: MoodChart(
                  entries: _thisWeekEntries,
                  startOfWeek: _startOfWeek,
                  endOfWeek: _endOfWeek,
                ),
              ),
              SizedBox(height: 8),
              MonthSelector(
                availableMonths: _availableMonths,
                selectedMonth: _selectedMonth,
                onMonthSelected: (month) {
                  setState(() {
                    _selectedMonth = month;
                  });
                },
              ),
              SizedBox(height: 16),
              _filteredEntries.isEmpty
                  ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    '이 달에는 작성된 일기가 없습니다.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              )
                  : ListView.builder(
                itemCount: _filteredEntries.length,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final entry = _filteredEntries[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      onTap: () {
                        // 일기 상세보기/수정 다이얼로그
                        showDialog(
                          context: context,
                          builder: (context) {
                            return DiaryDialog(
                              currentUserId: widget.userId,
                              isEditing: true,
                              diary: entry,
                              initialDate: entry.date,
                              initialMood: entry.mood,
                              initialContent: entry.content,
                              onSave: ({required DateTime date, required MoodState mood, required String content, required String userId}) async {
                                try {
                                  // Firestore 문서 ID를 통한 업데이트
                                  await FirebaseFirestore.instance
                                      .collection('diaries')
                                      .doc(entry.id)
                                      .update({
                                    'date': Timestamp.fromDate(date),
                                    'content': content,
                                    'mood': mood.index,
                                  });

                                  await _loadData();

                                } catch (e) {
                                  print('일기 수정 오류: $e');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('일기 수정 중 오류가 발생했습니다.')),
                                  );
                                }
                              },
                              onDelete: (diary) async {
                                try {
                                  await FirebaseFirestore.instance
                                      .collection('diaries')
                                      .doc(diary.id)
                                      .delete();

                                  await _loadData();

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('일기가 삭제되었습니다.')),
                                  );
                                } catch (e) {
                                  print('일기 삭제 오류: $e');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('일기 삭제 중 오류가 발생했습니다.')),
                                  );
                                }
                              },
                            );
                          },
                        );
                      },
                      leading: entry.mood.getGradientCircle(),
                      title: Text(
                        DateFormat('yyyy-MM-dd').format(entry.date),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        entry.content.length > 50
                            ? entry.content.substring(0, 50) + '...'
                            : entry.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              )
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNav(initialIndex: 2, userId: userId),
    );
  }
}