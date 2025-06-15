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
  const DiaryScreen({Key? key, required this.userId}) : super(key: key);
  @override
  _DiaryScreenState createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  List<DiaryEntry> _diaryEntries = [];
  List<String> _availableMonths = [];
  String? _selectedMonth;
  bool _isLoading = true;
  String? _currentUserId;

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
      final QuerySnapshot diarySnapshot = await FirebaseFirestore.instance
          .collection('diaries')
          .where('userId', isEqualTo: _currentUserId)
          .get();

      final entries = diarySnapshot.docs
          .map((doc) => DiaryEntry.fromFirestore(doc))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      final now = DateTime.now();
      final currentYear = now.year;

      final allMonths = List.generate(12, (i) {
        final month = i + 1;
        return '$currentYear-${month.toString().padLeft(2, '0')}';
      });

      setState(() {
        _diaryEntries = entries;
        _availableMonths = allMonths;
        _selectedMonth = DateFormatter.formatMonth(now);
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

  List<DiaryEntry> get _filteredEntries {
    if (_selectedMonth == null) return [];

    final parts = _selectedMonth!.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    return _diaryEntries.where((entry) {
      return entry.date.year == year && entry.date.month == month;
    }).toList();
  }

  List<DiaryEntry> get _thisWeekEntries {
    return _diaryEntries.where((entry) {
      return entry.date.isAfter(_startOfWeek.subtract(Duration(days: 1))) &&
          entry.date.isBefore(_endOfWeek.add(Duration(days: 1)));
    }).toList();
  }

  void _showAddDiaryDialog() {
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

  // 일기 수정 함수 - 수정됨
  void _editDiary(DiaryEntry entry) async {
    try {
      await FirebaseFirestore.instance
          .collection('diaries')
          .doc(entry.id)
          .update({
        'date': Timestamp.fromDate(entry.date),
        'content': entry.content,
        'mood': entry.mood.index,
      });

      await _loadData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일기가 수정되었습니다.')),
      );
    } catch (e) {
      print('일기 수정 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일기 수정 중 오류가 발생했습니다.')),
      );
    }
  }

  // 일기 삭제 함수
  void _deleteDiary(DiaryEntry entry) async {
    try {
      await FirebaseFirestore.instance
          .collection('diaries')
          .doc(entry.id)
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
  }

  // 일기 저장 함수 (새 일기 작성용)
  Future<void> _saveDiary({required DateTime date, required MoodState mood, required String content, required String userId}) async {
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
      print('일기 저장 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일기 저장 중 오류가 발생했습니다.')),
      );
    }
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
          surfaceTintColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            '일기',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDiaryDialog,
        backgroundColor: Color(0xFFB39DDB).withOpacity(0.7),
        child: Icon(
          Icons.add,
          color: Colors.white,
        ),
        tooltip: '새 일기 작성',
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // 고정된 상단 부분
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            child: MoodChart(
              entries: _thisWeekEntries,
              startOfWeek: _startOfWeek,
              endOfWeek: _endOfWeek,
            ),
          ),
          MonthSelector(
            availableMonths: _availableMonths,
            selectedMonth: _selectedMonth,
            onMonthSelected: (month) {
              setState(() {
                _selectedMonth = month;
              });
            },
          ),
          SizedBox(height: 4),

          // 스크롤 가능한 일기 리스트 부분
          Expanded(
            child: DiaryList(
              entries: _filteredEntries,
              onEditDiary: _editDiary,
              onDeleteDiary: _deleteDiary,
              onSaveDiary: _saveDiary,
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNav(initialIndex: 2, userId: userId),
    );
  }
}