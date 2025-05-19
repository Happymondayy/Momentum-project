import 'package:flutter/material.dart';
import 'package:momentum_planner/Planner/DailyPlannerPage.dart';
import 'package:momentum_planner/Settings/settings_page.dart';
import 'package:momentum_planner/AI/chat_screen.dart'; // ChatScreen import 추가
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore import 추가

class BottomNav extends StatefulWidget {
  // 현재 화면에 따라 초기 인덱스를 설정하기 위한 생성자 추가
  final int initialIndex;
  final String userId; // 사용자 ID 추가

  const BottomNav({Key? key, this.initialIndex = 0, required this.userId}) : super(key: key);

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  late int _selectedIndex;
  // 데이터 상태를 관리하기 위한 변수 추가
  List<Map<String, dynamic>> _calendarData = [];
  List<Map<String, dynamic>> _todoData = [];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    print('BottomNav 초기화: userId = ${widget.userId}, initialIndex = ${widget.initialIndex}');
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0: // Calendar
        print('Calendar 탭으로 이동: userId = ${widget.userId}');
        Navigator.pushReplacementNamed(
          context,
          'Calendar/screens/calendar_screen',
          arguments: {'userId': widget.userId},
        );
        break;

      case 1: // Planner
        print('Planner 탭으로 이동: userId = ${widget.userId}');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DailyPlannerPage(
              userId: widget.userId,
              calendarData: _calendarData,
            ),
          ),
        );
        break;

      case 2: // Chat (새로 추가된 탭)
        print('Chat 탭으로 이동: userId = ${widget.userId}');

        // 로딩 인디케이터 표시
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
              ),
            );
          },
        );

        // Firestore에서 데이터 가져오기
        _fetchDataAndNavigateToChatScreen(context);
        break;

      case 3: // Diary (인덱스 변경됨)
        print('Diary 탭으로 이동: userId = ${widget.userId}');
        Navigator.pushReplacementNamed(
          context,
          'Diary/screens/diary_screen',
          arguments: {'userId': widget.userId},
        );
        break;

      case 4: // Settings (인덱스 변경됨)
        print('Settings 탭으로 이동: userId = ${widget.userId}');
        if (widget.userId.isNotEmpty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SettingsPage(userId: widget.userId),
            ),
          );
        } else {
          print('경고: userId가 비어 있습니다. Settings 페이지로 이동할 수 없습니다.');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('사용자 정보를 찾을 수 없습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        break;
    }
  }

  Future<void> _fetchDataAndNavigateToChatScreen(BuildContext context) async {
    try {
      // 1. 캘린더 데이터 가져오기
      final calendarSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('userId', isEqualTo: widget.userId)
          .get();

      _calendarData = calendarSnapshot.docs.map((doc) {
        final data = doc.data();

        // 날짜 데이터 형식 처리
        String dateStr = '';
        if (data['date'] is Timestamp) {
          dateStr = data['date'].toDate().toString().split(' ')[0];
        } else if (data['date'] is String) {
          dateStr = data['date'];
        } else if (data['startDate'] is Timestamp) {
          dateStr = data['startDate'].toDate().toString().split(' ')[0];
        } else if (data['startDate'] is String) {
          dateStr = data['startDate'];
        }

        return {
          'id': doc.id,
          'title': data['title'] ?? '',
          'description': data['description'] ?? '',
          'date': dateStr,
          'startTime': data['startTime'] ?? '',
          'endTime': data['endTime'] ?? '',
          'location': data['location'] ?? '',
          'isCompleted': data['isCompleted'] ?? false,
        };
      }).toList();

      // 2. 할 일 데이터 가져오기
      final todoSnapshot = await FirebaseFirestore.instance
          .collection('todos')
          .where('userId', isEqualTo: widget.userId)
          .get();

      _todoData = todoSnapshot.docs.map((doc) {
        final data = doc.data();

        // 날짜 데이터 형식 처리
        String dateStr = '';
        if (data['date'] is Timestamp) {
          dateStr = data['date'].toDate().toString().split(' ')[0];
        } else if (data['date'] is String) {
          dateStr = data['date'];
        }

        return {
          'id': doc.id,
          'title': data['title'] ?? '',
          'description': data['description'] ?? '',
          'date': dateStr,
          'time': data['time'] ?? '',
          'endTime': data['endTime'] ?? '',
          'importance': data['importance'] ?? 1,
          'urgency': data['urgency'] ?? 1,
          'isCompleted': data['isCompleted'] ?? false,
          'memo': data['memo'] ?? '',
          'location': data['location'] ?? '',
        };
      }).toList();

      // 3. 로딩 다이얼로그 닫기
      Navigator.pop(context);

      // 4. 채팅 화면으로 이동
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            userId: widget.userId,
            calendarData: _calendarData,
            todoData: _todoData,
            onEventAdded: (Map<String, dynamic> eventData) async {
              // 새 일정이 추가됨 - 라이브 업데이트
              try {
                // 상태 업데이트
                setState(() {
                  _calendarData.add(eventData);
                });

                // 실제 캘린더 또는 홈 화면 갱신을 위한 추가 로직
                print('AI 비서에서 새 일정 추가됨: ${eventData['title']}');

                // Firestore와 동기화가 필요한 경우 서버에서 새로 가져오기
                final newSnapshot = await FirebaseFirestore.instance
                    .collection('events')
                    .where('userId', isEqualTo: widget.userId)
                    .get();

                setState(() {
                  _calendarData = newSnapshot.docs.map((doc) {
                    final data = doc.data();
                    String dateStr = '';
                    if (data['date'] is Timestamp) {
                      dateStr = data['date'].toDate().toString().split(' ')[0];
                    } else if (data['date'] is String) {
                      dateStr = data['date'];
                    } else if (data['startDate'] is Timestamp) {
                      dateStr = data['startDate'].toDate().toString().split(' ')[0];
                    } else if (data['startDate'] is String) {
                      dateStr = data['startDate'];
                    }

                    return {
                      'id': doc.id,
                      'title': data['title'] ?? '',
                      'description': data['description'] ?? '',
                      'date': dateStr,
                      'startTime': data['startTime'] ?? '',
                      'endTime': data['endTime'] ?? '',
                      'location': data['location'] ?? '',
                      'isCompleted': data['isCompleted'] ?? false,
                    };
                  }).toList();
                });
              } catch (e) {
                print('일정 추가 후 데이터 갱신 오류: $e');
              }
            },
            onEventDeleted: (String eventId) async {
              // 일정이 삭제됨 - 라이브 업데이트
              try {
                // 상태 업데이트
                setState(() {
                  _calendarData.removeWhere((event) => event['id'] == eventId);
                });

                print('AI 비서에서 일정 삭제됨: $eventId');

                // Firestore와 동기화가 필요한 경우 서버에서 새로 가져오기
                final newSnapshot = await FirebaseFirestore.instance
                    .collection('events')
                    .where('userId', isEqualTo: widget.userId)
                    .get();

                setState(() {
                  _calendarData = newSnapshot.docs.map((doc) {
                    final data = doc.data();
                    String dateStr = '';
                    if (data['date'] is Timestamp) {
                      dateStr = data['date'].toDate().toString().split(' ')[0];
                    } else if (data['date'] is String) {
                      dateStr = data['date'];
                    } else if (data['startDate'] is Timestamp) {
                      dateStr = data['startDate'].toDate().toString().split(' ')[0];
                    } else if (data['startDate'] is String) {
                      dateStr = data['startDate'];
                    }

                    return {
                      'id': doc.id,
                      'title': data['title'] ?? '',
                      'description': data['description'] ?? '',
                      'date': dateStr,
                      'startTime': data['startTime'] ?? '',
                      'endTime': data['endTime'] ?? '',
                      'location': data['location'] ?? '',
                      'isCompleted': data['isCompleted'] ?? false,
                    };
                  }).toList();
                });
              } catch (e) {
                print('일정 삭제 후 데이터 갱신 오류: $e');
              }
            },
          ),
        ),
      );
    } catch (e) {
      // 오류 발생 시 로딩 다이얼로그 닫기
      if (context.mounted) {
        Navigator.pop(context);
      }

      print('데이터 가져오기 오류: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('데이터를 불러오는 중 오류가 발생했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }

      // 오류 발생 시에도 빈 데이터로 채팅 화면 이동
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              userId: widget.userId,
              calendarData: [],
              todoData: [],
              onEventAdded: (Map<String, dynamic> eventData) async {
                print('이벤트 추가됨 (빈 데이터): ${eventData['title']}');

                // 데이터 새로고침 시도
                try {
                  final newSnapshot = await FirebaseFirestore.instance
                      .collection('events')
                      .where('userId', isEqualTo: widget.userId)
                      .get();

                  setState(() {
                    _calendarData = newSnapshot.docs.map((doc) {
                      final data = doc.data();
                      return {
                        'id': doc.id,
                        'title': data['title'] ?? '',
                        'description': data['description'] ?? '',
                        'date': data['date'] ?? data['startDate'] ?? '',
                        'startTime': data['startTime'] ?? '',
                        'endTime': data['endTime'] ?? '',
                        'location': data['location'] ?? '',
                        'isCompleted': data['isCompleted'] ?? false,
                      };
                    }).toList();
                  });
                } catch (e) {
                  print('데이터 새로고침 오류: $e');
                }
              },
              onEventDeleted: (String eventId) {
                print('이벤트 삭제됨 (빈 데이터): $eventId');
                // 오류 상황이므로 별도 처리 없음
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: Colors.white,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.indigo,
      unselectedItemColor: Colors.grey.shade400,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_month),
          label: '캘린더',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.view_list),
          label: '플래너',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline),
          label: '채팅',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.article_outlined),
          label: '일기',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: '설정',
        ),
      ],
    );
  }
}