import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DiaryPage extends StatefulWidget {
  @override
  _DiaryPageState createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 월별 필터링을 위한 변수
  String? selectedMonth;
  List<String> availableMonths = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableMonths();
  }

  // 데이터베이스에서 사용 가능한 월 목록 로드
  Future<void> _loadAvailableMonths() async {
    QuerySnapshot snapshot = await _firestore.collection('diary').get();
    Set<String> months = {};

    for (var doc in snapshot.docs) {
      Timestamp timestamp = doc['date'];
      DateTime date = timestamp.toDate();
      String yearMonth = "${date.year}-${date.month.toString().padLeft(2, '0')}";
      months.add(yearMonth);
    }

    setState(() {
      availableMonths = months.toList()..sort((a, b) => b.compareTo(a)); // 최신 월이 먼저 오도록 정렬
      if (availableMonths.isNotEmpty) {
        selectedMonth = availableMonths.first; // 기본값으로 가장 최근 달 선택
      }
    });
  }

  // 일기 작성 또는 수정 대화상자
  Future<void> _showDiaryDialog({DocumentSnapshot? existingEntry}) async {
    bool isEditing = existingEntry != null;

    TextEditingController titleController = TextEditingController(
        text: isEditing ? existingEntry['title'] : ''
    );
    TextEditingController contentController = TextEditingController(
        text: isEditing ? existingEntry['content'] : ''
    );

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? '일기 수정' : '새 일기 작성'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: titleController, decoration: InputDecoration(hintText: '제목')),
                SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  decoration: InputDecoration(hintText: '본문'),
                  maxLines: 5,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                if (titleController.text.isEmpty || contentController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('제목과 본문을 모두 입력해주세요.'))
                  );
                  return;
                }

                final Map<String, dynamic> diaryData = {
                  'title': titleController.text,
                  'content': contentController.text,
                };

                if (isEditing) {
                  // 기존 일기 수정
                  await _firestore.collection('diary').doc(existingEntry.id).update(diaryData);
                } else {
                  // 새 일기 추가
                  diaryData['date'] = Timestamp.now();
                  await _firestore.collection('diary').add(diaryData);
                  _loadAvailableMonths(); // 새 일기가 추가된 후 월 목록 갱신
                }

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isEditing ? '일기가 수정되었습니다.' : '일기가 저장되었습니다.'))
                );
              },
              child: Text('저장'),
            )
          ],
        );
      },
    );
  }

  // 일기 삭제 확인 대화상자
  Future<void> _confirmDeleteDiary(DocumentSnapshot doc) async {
    bool confirmDelete = false;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('일기 삭제'),
          content: Text('정말 이 일기를 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('취소'),
            ),
            TextButton(
              onPressed: () {
                confirmDelete = true;
                Navigator.pop(context);
              },
              child: Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmDelete) {
      await _firestore.collection('diary').doc(doc.id).delete();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('일기가 삭제되었습니다.'))
      );
      _loadAvailableMonths(); // 일기가 삭제된 후 월 목록 갱신
    }
  }

  // 일기 상세 보기
  void _viewDiaryDetail(DocumentSnapshot doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        Timestamp timestamp = doc['date'];
        DateTime date = timestamp.toDate();
        String formattedDate = _formatDate(date); // 자체 날짜 형식 함수 사용

        return Container(
          padding: EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formattedDate,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          Navigator.pop(context);
                          _showDiaryDialog(existingEntry: doc);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          Navigator.pop(context);
                          _confirmDeleteDiary(doc);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                doc['title'],
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    doc['content'],
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('닫기'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // intl 패키지 대신 간단한 날짜 형식 함수 구현
  String _formatDate(DateTime date) {
    final List<String> weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    final String weekday = weekdays[date.weekday - 1]; // weekday는 1(월)~7(일)이므로 -1 필요

    return '${date.year}년 ${date.month}월 ${date.day}일 $weekday';
  }

  // 간단한 짧은 날짜 형식 함수
  String _formatShortDate(DateTime date) {
    final List<String> weekdayShort = ['월', '화', '수', '목', '금', '토', '일'];
    final String weekday = weekdayShort[date.weekday - 1];

    return '${date.month}/${date.day} ($weekday)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('내 일기장'),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_month),
            onPressed: () {
              _showMonthFilterDialog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 월 필터 표시 영역
          if (selectedMonth != null)
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Chip(
                    label: Text('$selectedMonth'),
                    deleteIcon: Icon(Icons.close, size: 18),
                    onDeleted: () {
                      setState(() {
                        selectedMonth = null;
                      });
                    },
                  ),
                ],
              ),
            ),

          // 일기 목록
          Expanded(
            child: StreamBuilder(
              stream: _buildDiaryStream(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.book, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          selectedMonth == null
                              ? '작성된 일기가 없습니다.'
                              : '$selectedMonth에 작성된 일기가 없습니다.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.all(8),
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (context, index) => Divider(),
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    Timestamp timestamp = doc['date'];
                    DateTime date = timestamp.toDate();
                    String formattedDate = _formatShortDate(date);

                    return Card(
                      elevation: 2,
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              formattedDate,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        title: Text(
                          doc['title'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          doc['content'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _viewDiaryDetail(doc),
                        trailing: PopupMenuButton(
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
                            if (value == 'edit') {
                              _showDiaryDialog(existingEntry: doc);
                            } else if (value == 'delete') {
                              _confirmDeleteDiary(doc);
                            }
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDiaryDialog(),
        child: Icon(Icons.add),
        tooltip: '새 일기 작성',
      ),
    );
  }

  // 월별 필터링 다이얼로그
  void _showMonthFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('월별 일기 보기'),
          content: Container(
            width: double.maxFinite,
            child: availableMonths.isEmpty
                ? Text('작성된 일기가 없습니다.')
                : ListView.builder(
              shrinkWrap: true,
              itemCount: availableMonths.length,
              itemBuilder: (context, index) {
                final month = availableMonths[index];
                return ListTile(
                  title: Text(month),
                  leading: Radio<String>(
                    value: month,
                    groupValue: selectedMonth,
                    onChanged: (value) {
                      setState(() {
                        selectedMonth = value;
                      });
                      Navigator.pop(context);
                    },
                  ),
                  onTap: () {
                    setState(() {
                      selectedMonth = month;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  selectedMonth = null; // 모든 월 보기
                });
                Navigator.pop(context);
              },
              child: Text('모든 월 보기'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('닫기'),
            ),
          ],
        );
      },
    );
  }

  // 선택된 월에 따라 다른 쿼리 스트림 생성
  Stream<QuerySnapshot> _buildDiaryStream() {
    Query query = _firestore.collection('diary').orderBy('date', descending: true);

    if (selectedMonth != null) {
      // 선택된 월의 시작과 끝 날짜 계산
      final parts = selectedMonth!.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);

      // 해당 월의 시작 날짜
      final startDate = DateTime(year, month, 1);
      // 해당 월의 마지막 날짜 (다음 달의 첫날 - 1초)
      final endDate = month < 12
          ? DateTime(year, month + 1, 1).subtract(Duration(seconds: 1))
          : DateTime(year + 1, 1, 1).subtract(Duration(seconds: 1));

      query = query
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    return query.snapshots();
  }
}