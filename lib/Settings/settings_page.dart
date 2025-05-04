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

  // 디버깅을 위한 로그 출력
  @override
  void initState() {
    super.initState();
    print('SettingsPage 초기화: userId = ${widget.userId}');
    _loadUserData();
  }



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

  Future<void> _showNicknameDialog() async {
    String currentNickname = _nickname ?? '';
    TextEditingController nicknameController = TextEditingController(text: currentNickname);

    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('닉네임 변경', style: TextStyle(fontWeight: FontWeight.bold)),
              content: TextField(
                controller: nicknameController,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: '새 닉네임을 입력하세요',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: _accentColor, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                // autofocus 제거!
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('취소', style: TextStyle(color: Colors.grey[600])),
                ),
                ElevatedButton(
                  onPressed: () async {
                    String newNickname = nicknameController.text.trim();
                    if (newNickname.isNotEmpty) {
                      Navigator.pop(dialogContext);
                      await _updateNickname(newNickname);
                      await _loadUserData(); // UI 반영
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: const Text('변경', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }


  Future<void> _updateNickname(String newNickname) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // ✅ 문서 없을 경우에도 생성 + 병합 (update보다 안전)
      await _firestore.collection('user').doc(widget.userId).set({
        'nickname': newNickname,
      }, SetOptions(merge: true));

      setState(() {
        _nickname = newNickname;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('닉네임이 성공적으로 변경되었습니다.'),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('닉네임 업데이트 오류: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('닉네임 변경 중 오류가 발생했습니다.'),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }


  void _logout() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('로그아웃', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('정말 로그아웃하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('취소', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                      (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 0,
              ),
              child: const Text('로그아웃', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _deleteAccount() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('회원 탈퇴', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('정말 탈퇴하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('취소', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _firestore.collection('user').doc(widget.userId).delete();
                  Navigator.pop(context);

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => LoginPage()),
                        (route) => false,
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('회원 탈퇴가 완료되었습니다.'),
                      backgroundColor: Colors.green[600],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                } catch (e) {
                  print('회원 탈퇴 오류: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('회원 탈퇴 중 오류가 발생했습니다.'),
                      backgroundColor: Colors.red[600],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 0,
              ),
              child: const Text('탈퇴하기', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingsCard({
    required String title,
    required List<SettingItemData> items,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 16, bottom: 8),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1, indent: 20, endIndent: 20),
            for (int i = 0; i < items.length; i++) ...[
              _buildSettingItem(
                icon: items[i].icon,
                title: items[i].title,
                trailing: items[i].trailing,
                iconColor: items[i].iconColor,
                textColor: items[i].textColor,
                onTap: items[i].onTap,
              ),
              if (i < items.length - 1)
                const Divider(height: 1, thickness: 1, indent: 70, endIndent: 20),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    Widget? trailing,
    Color? iconColor,
    Color? textColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? _accentColor).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: iconColor ?? _accentColor,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textColor ?? Colors.black87,
        ),
      ),
      trailing: trailing ?? Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }

  void _launchURL(String url) async {
    // URL을 사용할 수 있는지 확인
    if (await canLaunch(url)) {
      // URL을 실행
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('설정', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _accentColor))
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로필 섹션
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryColor, _accentColor.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Hello, 닉네임! 텍스트
                  GestureDetector(
                    onTap: _showNicknameDialog,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Hello, ${_nickname ?? 'User'}!',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, size: 16, color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // What will you post today? 텍스트
                  Text(
                    'What will you post today?',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // 이메일
                  Text(
                    _email ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            // 지원 섹션
            _buildSettingsCard(
              title: '지원',
              items: [
                SettingItemData(
                  icon: Icons.campaign,
                  title: '공지사항',
                  onTap: () {
                    _launchURL('https://www.notion.so/FocusMate-1e95673b8f5780e0b121ca24bf21bd0b?pvs=4');
                  },
                ),
                SettingItemData(
                  icon: Icons.message,
                  title: '의견 보내기',
                  onTap: () {
                    // 의견 보내기 화면으로 이동
                  },
                ),
              ],
            ),

            // 정보 섹션
            _buildSettingsCard(
              title: '정보',
              items: [
                SettingItemData(
                  icon: Icons.info_outline,
                  title: '서비스 이용약관',
                  onTap: () {
                    // 이용약관 화면으로 이동
                  },
                ),
                SettingItemData(
                  icon: Icons.privacy_tip_outlined,
                  title: '개인정보 처리방침',
                  onTap: () {
                    // 개인정보 처리방침 화면으로 이동
                  },
                ),
                SettingItemData(
                  icon: Icons.verified_user_outlined,
                  title: '버전 정보',
                  trailing: Text('1.1.4', style: TextStyle(color: Colors.grey[600])),
                  onTap: null,
                ),
              ],
            ),

            // 계정 관리 섹션
            _buildSettingsCard(
              title: '계정 관리',
              items: [
                SettingItemData(
                  icon: Icons.logout,
                  iconColor: Colors.red[600],
                  title: '로그아웃',
                  textColor: Colors.red[600],
                  onTap: _logout,
                ),
                SettingItemData(
                  icon: Icons.delete_forever,
                  iconColor: Colors.red[600],
                  title: '회원 탈퇴',
                  textColor: Colors.red[600],
                  onTap: _deleteAccount,
                ),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: BottomNav(
        initialIndex: 3, // 프로필 탭 선택
        userId: widget.userId,
      ),
    );
  }
}

// 설정 항목 데이터 클래스
class SettingItemData {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final Color? iconColor;
  final Color? textColor;
  final VoidCallback? onTap;

  SettingItemData({
    required this.icon,
    required this.title,
    this.trailing,
    this.iconColor,
    this.textColor,
    this.onTap,
  });
}