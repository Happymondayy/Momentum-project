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
    String currentNickname = _nickname ?? '';
    TextEditingController nicknameController = TextEditingController(text: currentNickname);

    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('닉네임 변경',
              style: TextStyle(fontWeight: FontWeight.bold)
          ),
          content: TextField(
            controller: nicknameController,
            decoration: InputDecoration(
              hintText: '새 닉네임을 입력하세요',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFFCFCFFF), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                String newNickname = nicknameController.text.trim();
                if (newNickname.isNotEmpty) {
                  Navigator.pop(dialogContext);
                  await _updateNickname(newNickname);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCFCFFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
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
      // 로딩 표시
      setState(() {
        _isLoading = true;
      });

      await _firestore.collection('user').doc(widget.userId).update({
        'nickname': newNickname,
      });

      setState(() {
        _nickname = newNickname;
        _isLoading = false;
      });

      // 성공 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('닉네임이 성공적으로 변경되었습니다.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('닉네임 업데이트 오류: $e');

      // 오류 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('닉네임 변경 중 오류가 발생했습니다.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('로그아웃', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('정말 로그아웃하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // 다이얼로그 닫기
                // 로그인 페이지로 이동 (이전 스택 모두 제거)
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                      (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('회원 탈퇴', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('정말 탈퇴하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
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
                    SnackBar(
                      content: const Text('회원 탈퇴가 완료되었습니다.'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                } catch (e) {
                  print('회원 탈퇴 오류: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('회원 탈퇴 중 오류가 발생했습니다.'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('탈퇴하기'),
            ),
          ],
        );
      },
    );
  }

  // 설정 항목 위젯
  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    Widget? trailing,
    Color? iconColor,
    Color? textColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Colors.black87, size: 22),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textColor ?? Colors.black87,
        ),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  // 섹션 구분자 위젯
  Widget _buildSectionDivider({String? title}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
          ),
        const Divider(thickness: 1, height: 1),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFCFCFFF)))
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로필 섹션
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 프로필 이미지
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFCFCFFF), width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage: _profileImageUrl != null
                              ? NetworkImage(_profileImageUrl!)
                              : const AssetImage('assets/images/default_profile.png') as ImageProvider,
                          backgroundColor: Colors.grey[200],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          // 프로필 이미지 변경 기능 (필요시 구현)
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCFCFFF),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.3),
                                spreadRadius: 1,
                                blurRadius: 3,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 닉네임
                  GestureDetector(
                    onTap: _showNicknameDialog,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _nickname ?? 'User',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, size: 18, color: Color(0xFFCFCFFF)),
                      ],
                    ),
                  ),

                  // 이메일
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _email ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 커뮤니티 섹션
            _buildSectionDivider(title: '커뮤니티'),
            _buildSettingItem(
              icon: Icons.group,
              title: 'FocusMate 커뮤니티',
              onTap: () {
                // 커뮤니티 화면으로 이동
              },
            ),

            // 지원 섹션
            _buildSectionDivider(title: '지원'),
            _buildSettingItem(
              icon: Icons.campaign,
              title: '공지사항',
              onTap: () {
                // 공지사항 화면으로 이동
              },
            ),
            _buildSettingItem(
              icon: Icons.message,
              title: '의견 보내기',
              onTap: () {
                // 의견 보내기 화면으로 이동
              },
            ),

            // 정보 섹션
            _buildSectionDivider(title: '정보'),
            _buildSettingItem(
              icon: Icons.info_outline,
              title: '서비스 이용약관',
              onTap: () {
                // 이용약관 화면으로 이동
              },
            ),
            _buildSettingItem(
              icon: Icons.privacy_tip_outlined,
              title: '개인정보 처리방침',
              onTap: () {
                // 개인정보 처리방침 화면으로 이동
              },
            ),
            _buildSettingItem(
              icon: Icons.verified_user_outlined,
              title: '버전 정보',
              trailing: Text('1.1.4', style: TextStyle(color: Colors.grey[600])),
              onTap: null,
            ),

            // 계정 관리 섹션
            _buildSectionDivider(title: '계정 관리'),
            _buildSettingItem(
              icon: Icons.logout,
              iconColor: Colors.red,
              title: '로그아웃',
              textColor: Colors.red,
              onTap: _logout,
            ),
            _buildSettingItem(
              icon: Icons.delete_forever,
              iconColor: Colors.red,
              title: '회원 탈퇴',
              textColor: Colors.red,
              onTap: _deleteAccount,
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}