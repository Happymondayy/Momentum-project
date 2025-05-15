import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:momentum_planner/Login/login_page.dart';
import 'package:momentum_planner/bottom_nav.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  final String userId;

  const SettingsPage({Key? key, required this.userId}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color _primaryColor = const Color(0xFFCFCFFF);
  final Color _accentColor = const Color(0xFF9191FF);

  String? _nickname;
  String? _email;
  bool _isLoading = true;
  final String _version = "1.1.4";

  @override
  void initState() {
    super.initState();
    if (widget.userId.isNotEmpty) {
      _loadUserData();
    } else {
      setState(() {
        _nickname = '사용자';
        _email = '';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      DocumentSnapshot userDoc = await _firestore.collection('user').doc(
          widget.userId).get();
      if (userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _nickname = data['nickname'] ?? '사용자';
            _email = data['email'] ?? '';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _nickname = '사용자';
          _email = '';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _nickname = '사용자';
        _email = '';
        _isLoading = false;
      });
    }
  }

  void _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }


  Future<void> _showNicknameDialog() async {
    TextEditingController controller = TextEditingController(
        text: _nickname ?? '');
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('닉네임 변경'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: '새 닉네임 입력'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                String newNickname = controller.text.trim();
                if (newNickname.isNotEmpty) {
                  bool isDuplicate = await _checkNicknameDuplicate(newNickname);
                  if (isDuplicate) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('이미 사용 중인 닉네임입니다. 다른 닉네임을 입력해주세요.')),
                      );
                    }
                    return; // 닉네임 중복이면 변경 안 함
                  }
                  Navigator.pop(context);
                  await _updateNickname(newNickname);
                }
              },
              child: const Text('변경'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _checkNicknameDuplicate(String nickname) async {
    final querySnapshot = await _firestore
        .collection('user')
        .where('nickname', isEqualTo: nickname)
        .get();

    // 현재 로그인한 사용자의 닉네임는 중복 체크 제외 (닉네임 변경 중일 때 자기 자신의 닉네임이면 중복 아님)
    if (querySnapshot.docs.isEmpty) return false; // 중복 없음

    // 중복이 있으면 중복 체크를 통과하지 못함
    // 같은 닉네임 가진 문서가 자기 자신이라면 중복 아님
    for (var doc in querySnapshot.docs) {
      if (doc.id != widget.userId) {
        return true; // 중복 있음
      }
    }
    return false; // 중복 없음
  }


  Future<void> _updateNickname(String newNickname) async {
    try {
      setState(() => _isLoading = true);
      await _firestore.collection('user').doc(widget.userId).set(
        {'nickname': newNickname},
        SetOptions(merge: true),
      );
      setState(() {
        _nickname = newNickname;
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('닉네임이 변경되었습니다.')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('닉네임 변경 실패')),
        );
      }
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            backgroundColor: Colors.white,
            content: const Text('로그아웃하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => LoginPage()),
                        (route) => false,
                  );
                },
                child: const Text('로그아웃'),
              ),
            ],
          ),
    );
  }

  void _deleteAccount() {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            backgroundColor: Colors.white,
            content: const Text('회원 탈퇴하시겠습니까?\n복구하실 수 없습니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await _firestore
                        .collection('user')
                        .doc(widget.userId)
                        .delete();
                    if (mounted) {
                      Navigator.pop(context);
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => LoginPage()),
                            (route) => false,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('회원 탈퇴 완료')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('탈퇴 중 오류 발생')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white70),
                child: const Text('탈퇴하기'),
              ),
            ],
          ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20.0, top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '설정',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFD8B5FF), // 더 진한 연보라색
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFD8B5FF).withOpacity(0.4),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, ${_nickname ?? "사용자"}!',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'What will you post today?',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                          onPressed: _showNicknameDialog,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildSectionHeader('정보'),
            _buildCard([
              ListTile(
                leading: Icon(Icons.announcement_outlined, color: Colors.black45),
                title: const Text('공지사항'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _launchURL('https://www.notion.so/FocusMate-1e95673b8f5780e0b121ca24bf21bd0b?pvs=4');
                },
              ),
              Divider(height: 1, thickness: 0.5, color: Colors.grey.withOpacity(0.2)),
              ListTile(
                leading: Icon(Icons.description_outlined, color: Colors.black45),
                title: const Text('서비스 이용약관'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _launchURL('https://www.notion.so/FocusMate-1e95673b8f5780edaf17d3835e03a8b4?pvs=4');
                },
              ),
              Divider(height: 1, thickness: 0.5, color: Colors.grey.withOpacity(0.2)),
              ListTile(
                leading: Icon(Icons.security_outlined, color: Colors.black45),
                title: const Text('개인 정보 처리방침'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _launchURL('https://www.notion.so/FocusMate-1e95673b8f57807eb687dc8471ac98a8?pvs=4');
                },
              ),
              Divider(height: 1, thickness: 0.5, color: Colors.grey.withOpacity(0.2)),
              ListTile(
                leading: Icon(Icons.message, color: Colors.black45),
                title: const Text('의견보내기'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _launchURL('https://www.notion.so/FocusMate-1e95673b8f578022b8fac584aa328bfe?pvs=4');
                },
              ),
            ]),

            const SizedBox(height: 8),
            _buildSectionHeader('계정 관리'),
            _buildCard([
              ListTile(
                leading: Icon(Icons.info_outline, color: Colors.black45),
                title: const Text('버전 정보'),
                trailing: Text(
                    _version, style: TextStyle(color: Colors.grey[600])),
              ),
              Divider(height: 1, thickness: 0.5, color: Colors.grey.withOpacity(0.2)),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('로그아웃'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _logout,
              ),
              Divider(height: 1, thickness: 0.5, color: Colors.grey.withOpacity(0.2)),
              ListTile(
                leading: const Icon(Icons.delete_outlined, color: Colors.red),
                title: const Text('회원 탈퇴'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _deleteAccount,
              ),
            ]),
          ],
        ),
      ),
      bottomNavigationBar: BottomNav(initialIndex: 3, userId: widget.userId),
    );
  }
}