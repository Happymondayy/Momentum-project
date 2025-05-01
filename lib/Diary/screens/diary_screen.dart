import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/diary_entry.dart';
import '../utils/date_formatter.dart';
import '../widgets/mood_chart.dart';
import '../widgets/month_selector.dart';
import '../dialogs/diary_dialog.dart'; // Import the new DiaryDialog
import 'package:momentum_planner/bottom_nav.dart';

class DiaryScreen extends StatefulWidget {
  @override
  _DiaryScreenState createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  List<DiaryEntry> _diaryEntries = [];
  List<String> _availableMonths = [];
  String? _selectedMonth;
  bool _isLoading = true;

  // 주간 차트용 날짜 범위
  late DateTime _startOfWeek;
  late DateTime _endOfWeek;

  @override
  void initState() {
    super.initState();
    _initWeekRange();
    _loadData();
  }

  void _initWeekRange() {
    final weekRange = DateFormatter.getCurrentWeekRange(DateTime.now());
    _startOfWeek = weekRange['start']!;
    _endOfWeek = weekRange['end']!;
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Firestore에서 모든 일기 데이터를 가져옴
      final QuerySnapshot diarySnapshot = await FirebaseFirestore.instance
          .collection('diaries')
          .orderBy('date', descending: false) // 오름차순 정렬
          .get();

      // 2. DiaryEntry 리스트 생성
      final entries = diarySnapshot.docs
          .map((doc) => DiaryEntry.fromFirestore(doc))
          .toList();

      // 3. 현재 연도 기준으로 1월~12월 리스트 생성
      final now = DateTime.now();
      final currentYear = now.year;

      final allMonths = List.generate(12, (i) {
        final month = i + 1;
        return '$currentYear-${month.toString().padLeft(2, '0')}';
      });

      // 4. 상태 업데이트
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

  void _navigateToDiaryDetail(DiaryEntry entry) {
    // 일기 상세 보기 화면으로 이동
    Navigator.pushNamed(
      context,
      '/diary_detail',
      arguments: entry,
    ).then((_) => _loadData()); // 돌아왔을 때 데이터 갱신
  }

  void _showAddDiaryDialog() {
    // 일기 추가 팝업을 띄우는 함수
    showDialog(
      context: context,
      builder: (context) {
        return DiaryDialog(
          onSave: ({required DateTime date, required MoodState mood, required String content}) async {
            try {
              final docRef = await FirebaseFirestore.instance
                  .collection('diaries')
                  .add({
                'date': Timestamp.fromDate(date),
                'content': content,
                'mood': mood.index,
              });

              _loadData();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('일기가 작성되었습니다.')),
              );
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

  void _navigateToEditDiary(DiaryEntry? entry) {
    // 일기 작성/수정 화면으로 이동
    Navigator.pushNamed(
      context,
      '/diary_edit',
      arguments: entry,
    ).then((_) {
      _loadData(); // Ensure data is reloaded after returning from edit screen
    });
  }

  Future<void> _deleteDiary(DiaryEntry entry) async {
    // 사용자 확인
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('일기 삭제'),
        content: Text('이 일기를 정말 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ??
        false;

    if (!confirm) return;

    try {
      // Firestore에서 삭제
      await FirebaseFirestore.instance
          .collection('diaries')
          .doc(entry.id)
          .delete();

      // 화면 갱신
      _loadData();

      // 성공 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일기가 삭제되었습니다.')),
      );
    } catch (e) {
      print('일기 삭제 오류: $e');

      // 오류 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일기 삭제 중 오류가 발생했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(30.0), // 원하는 높이 설정
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: Icon(Icons.menu, color: Colors.black),
            onPressed: () {
              print('Menu button pressed');
            },
          ),
        ),
      ),


      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDiaryDialog, // 일기 추가 팝업 띄우기
        backgroundColor: Color(0xFFB39DDB),
        child: Icon(Icons.add),
        tooltip: '새 일기 작성',
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(  // overflow 방지용
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 그래프를 전체 배경에 표시 (박스 제거)
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
              // 리스트뷰를 고정 높이로 제한해서 overflow 방지
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
                      onTap: () => _navigateToDiaryDetail(entry),
                      leading: Icon(entry.mood.icon, color: entry.mood.color),
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit, size: 20, color: Colors.blue),
                            onPressed: () => _navigateToEditDiary(entry),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, size: 20, color: Colors.red),
                            onPressed: () => _deleteDiary(entry),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNav(initialIndex: 2),
    );
  }
}