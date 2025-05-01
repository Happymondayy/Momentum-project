import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/diary_entry.dart';

class DiaryDialog extends StatefulWidget {
  final Function(
      {required DateTime date,
      required MoodState mood,
      required String content}) onSave;
  final DateTime? initialDate; // nullable로 변경
  final MoodState? initialMood; // nullable로 변경
  final String? initialContent; // nullable로 변경

  const DiaryDialog({
    Key? key,
    required this.onSave,
    this.initialDate,
    this.initialMood,
    this.initialContent,
  }) : super(key: key);

  @override
  _DiaryDialogState createState() => _DiaryDialogState();
}

class _DiaryDialogState extends State<DiaryDialog> {
  final TextEditingController _contentController = TextEditingController();
  late DateTime _selectedDate;
  late MoodState _selectedMood;
  bool _contentError = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _selectedMood = widget.initialMood ?? MoodState.neutral;
    _contentController.text = widget.initialContent ?? '';

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
      date: _selectedDate,
      mood: _selectedMood,
      content: _contentController.text,
    );

    Navigator.pop(context);
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
                Icon(Icons.calendar_today, size: 20),
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
                      Icon(mood.icon, color: mood.color),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[700]),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    '새 일기 작성',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(width: 48),
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
                        maxLines: 5,
                        autofocus: true,
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
                      Center(
                        child: ElevatedButton(
                          onPressed: _validateAndSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple[300],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 50, vertical: 12),
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