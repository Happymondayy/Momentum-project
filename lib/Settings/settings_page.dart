import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:momentum_planner/Login/login_page.dart';

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
      DocumentSnapshot userDoc = await _firestore.collection('user').doc(widget.userId).get();
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

  Future<void> _showNicknameDialog() async {
    TextEditingController controller = TextEditingController(text: _nickname ?? '');
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
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
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
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
      builder: (context) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: const Text('정말 탈퇴하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              try {
                await _firestore.collection('user').doc(widget.userId).delete();
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('탈퇴하기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        children: [
          ListTile(
            title: Text('닉네임'),
            subtitle: Text(_nickname ?? '사용자'),
            trailing: const Icon(Icons.edit),
            onTap: _showNicknameDialog,
          ),
          ListTile(
            title: Text('이메일'),
            subtitle: Text(_email ?? ''),
          ),
          const Divider(),
          ListTile(
            title: const Text('로그아웃'),
            leading: const Icon(Icons.logout),
            onTap: _logout,
          ),
          ListTile(
            title: const Text('회원 탈퇴'),
            leading: const Icon(Icons.delete_forever),
            textColor: Colors.red,
            iconColor: Colors.red,
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }
}
