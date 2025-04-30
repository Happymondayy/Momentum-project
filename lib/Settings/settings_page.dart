import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:momentum_planner/Login/login_page.dart';

class SettingsPage extends StatefulWidget {
  final String userId; // 현재 로그인한 사용자 ID

  const SettingsPage({Key? key, required this.userId}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _nickname;
  String? _email;
  String? _profileImageUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // 사용자 데이터 불러오기
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      DocumentSnapshot userDoc = await _firestore.collection('user').doc(widget.userId).get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _nickname = userData['nickname'] ?? '사용자';
          _email = userData['email'] ?? '';
          _profileImageUrl = userData['profileImageUrl'];
        });
      }
    } catch (e) {
      print('사용자 데이터 로드 오류: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  // 닉네임 변경 다이얼로그
  Future<void> _showNicknameDialog() async {
    TextEditingController nicknameController = TextEditingController(text: _nickname);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('닉네임 변경'),
          content: TextField(
            controller: nicknameController,
            decoration: const InputDecoration(
              hintText: '새 닉네임을 입력하세요',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                if (nicknameController.text.trim().isNotEmpty) {
                  await _updateNickname(nicknameController.text.trim());
                  Navigator.pop(context);
                }
              },
              child: const Text('변경'),
            ),
          ],
        );
      },
    );
  }

  // 닉네임 업데이트
  Future<void> _updateNickname(String newNickname) async {
    try {
      await _firestore.collection('user').doc(widget.userId).update({
        'nickname': newNickname,
      });

      setState(() {
        _nickname = newNickname;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임이 업데이트되었습니다.')),
      );
    } catch (e) {
      print('닉네임 업데이트 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임 업데이트 중 오류가 발생했습니다.')),
      );
    }
  }

  // 로그아웃
  void _logout() {
    // 로그아웃 확인 다이얼로그
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('정말 로그아웃하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // 다이얼로그 닫기
                // 로그인 페이지로 이동 (이전 스택 모두 제거)
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                      (route) => false,
                );
              },
              child: const Text('로그아웃'),
            ),
          ],
        );
      },
    );
  }

  // 회원 탈퇴
  void _deleteAccount() {
    // 회원 탈퇴 확인 다이얼로그
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('회원 탈퇴'),
          content: const Text('정말 탈퇴하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  // 사용자 데이터 삭제
                  await _firestore.collection('user').doc(widget.userId).delete();


                  Navigator.pop(context); // 다이얼로그 닫기

                  // 로그인 페이지로 이동
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => LoginPage()),
                        (route) => false,
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('회원 탈퇴가 완료되었습니다.')),
                  );
                } catch (e) {
                  print('회원 탈퇴 오류: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('회원 탈퇴 중 오류가 발생했습니다.')),
                  );
                }
              },
              child: const Text('탈퇴하기', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        //title: const Text('설정'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            // 프로필 섹션
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // 프로필 이미지
                  GestureDetector(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: const AssetImage('assets/images/default_profile.png'),
                        ),

                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCFCFFF),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 닉네임
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _nickname ?? 'User',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 16),
                        onPressed: _showNicknameDialog,
                      ),
                    ],
                  ),
                  // 이메일
                  Text(
                    _email ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 티밍 커뮤니티 섹션
            ListTile(
              leading: const Icon(Icons.group, color: Colors.black87),
              title: const Text('FocusMate 커뮤니티'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // 커뮤니티 화면으로 이동
              },
            ),

            const Divider(height: 1),

            // 공지사항
            ListTile(
              leading: const Icon(Icons.campaign, color: Colors.black87),
              title: const Text('공지사항'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // 공지사항 화면으로 이동
              },
            ),

            // 의견 보내기
            ListTile(
              leading: const Icon(Icons.message, color: Colors.black87),
              title: const Text('의견 보내기'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // 의견 보내기 화면으로 이동
              },
            ),

            const Divider(height: 1),

            // 서비스 정보 섹션
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.black87),
              title: const Text('서비스 이용약관'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // 이용약관 화면으로 이동
              },
            ),

            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined, color: Colors.black87),
              title: const Text('개인정보 처리방침'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // 개인정보 처리방침 화면으로 이동
              },
            ),

            ListTile(
              leading: const Icon(Icons.verified_user_outlined, color: Colors.black87),
              title: const Text('버전 정보'),
              trailing: const Text('1.1.4'),
            ),

            const Divider(height: 1),

            // 로그아웃
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('로그아웃', style: TextStyle(color: Colors.red)),
              onTap: _logout,
            ),

            // 회원 탈퇴
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('회원 탈퇴', style: TextStyle(color: Colors.red)),
              onTap: _deleteAccount,
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}