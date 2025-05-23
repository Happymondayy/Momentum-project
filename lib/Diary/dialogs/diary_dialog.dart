import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/diary_entry.dart';

class DiaryDialog extends StatefulWidget {
  final Function(
      {required DateTime date,
      required MoodState mood,
      required String content,
      required String userId}) onSave;
  final DateTime? initialDate; // nullable로 변경
  final MoodState? initialMood; // nullable로 변경
  final String? initialContent; // nullable로 변경
  final Function(DiaryEntry diary)? onDelete;
  final DiaryEntry? diary;
  final bool isEditing;
  final String currentUserId;


  const DiaryDialog({
    Key? key,
    required this.onSave,
    this.initialDate,
    this.initialMood,
    this.initialContent,
    this.diary,
    this.onDelete,
    this.isEditing = false,
    required this.currentUserId,
  }) : super(key: key);

  @override
  _DiaryDialogState createState() => _DiaryDialogState();
}

class _DiaryDialogState extends State<DiaryDialog> {
  final TextEditingController _contentController = TextEditingController();
  late DateTime _selectedDate;
  late MoodState _selectedMood;
  bool _contentError = false;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _selectedMood = widget.initialMood ?? MoodState.neutral;
    _contentController.text = widget.initialContent ?? '';
    _editing = widget.isEditing;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  void _validateAndSave() {
    if (_contentController.text.trim().isEmpty) {
      setState(() {
        _contentError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('본문을 입력해주세요.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    widget.onSave(
      userId: widget.currentUserId,
      date: _selectedDate,
      mood: _selectedMood,
      content: _contentController.text,
    );

    Navigator.pop(context);
  }

  void _handleDelete() {
    if (widget.onDelete != null && widget.diary != null) {
      widget.onDelete!(widget.diary!);
      Navigator.pop(context);
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('일기 삭제'),
        content: Text('이 일기를 정말 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _handleDelete();
            },
            child: Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('날짜', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            SizedBox(width: 5),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        InkWell(
          onTap: () async {
            final DateTime? pickedDate = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (pickedDate != null) {
              setState(() {
                _selectedDate = pickedDate;
              });
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 15),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('yyyy-MM-dd').format(_selectedDate),
                  style: TextStyle(fontSize: 16),
                ),
                _editing ? Icon(Icons.calendar_today, size: 20) : SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMoodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('기분', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            SizedBox(width: 5),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<MoodState>(
              isExpanded: true,
              value: _selectedMood,
              hint: Text('기분 선택'),
              items: MoodState.values.map((MoodState mood) {
                return DropdownMenuItem<MoodState>(
                  value: mood,
                  child: Row(
                    children: [
                      mood.getGradientCircle(),
                      SizedBox(width: 8),
                      Text(mood.koreanName),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (MoodState? value) {
                if (value != null) {
                  setState(() {
                    _selectedMood = value;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 5,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: Icon(Icons.close, color: Colors.grey[700]),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Center(
                    child: Text(
                      _editing ? '일기 상세' : '새 일기 작성',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey[300]),
            Flexible(
              child: SingleChildScrollView(
                child: Container(
                  padding: EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _contentController,
                        decoration: InputDecoration(
                          hintText: '본문을 입력해주세요.',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          errorText: _contentError ? '본문을 입력해주세요.' : null,
                        ),
                        style: TextStyle(fontSize: 16),
                        maxLines: null,
                        autofocus: widget.isEditing,
                        onChanged: (_) => setState(() {
                          _contentError = false;
                        }),
                      ),
                      Divider(color: _contentError ? Colors.red : Colors.grey[300]),
                      SizedBox(height: 20),
                      _buildDateSelector(),
                      SizedBox(height: 20),
                      _buildMoodSelector(),
                      SizedBox(height: 30),
                  _editing
                      ? Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _validateAndSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple[300],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            '저장',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _confirmDelete,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: BorderSide(color: Colors.red),
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Text(
                            '삭제',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                      : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _validateAndSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple[300],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        '저장',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}