import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CustomTimePickerWidget extends StatefulWidget {
  final TimeOfDay initialTime;
  final ValueChanged<TimeOfDay> onConfirmed;

  const CustomTimePickerWidget({
    Key? key,
    required this.initialTime,
    required this.onConfirmed,
  }) : super(key: key);

  @override
  State<CustomTimePickerWidget> createState() => _CustomTimePickerWidgetState();
}

class _CustomTimePickerWidgetState extends State<CustomTimePickerWidget> {
  int _amPmIndex = 0;
  int _hourIndex = 0;
  int _minuteIndex = 0;

  final List<String> amPm = ['AM', 'PM'];
  final List<String> hours = List.generate(12, (index) => '${index + 1}');
  final List<String> minutes = List.generate(60, (index) => index.toString().padLeft(2, '0'));

  @override
  void initState() {
    super.initState();
    _amPmIndex = widget.initialTime.period == DayPeriod.am ? 0 : 1;
    _hourIndex = (widget.initialTime.hourOfPeriod) % 12;
    _minuteIndex = widget.initialTime.minute;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      color: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _buildPicker(amPm, _amPmIndex, (index) => setState(() => _amPmIndex = index)),
                _buildPicker(hours, _hourIndex, (index) => setState(() => _hourIndex = index)),
                _buildPicker(minutes, _minuteIndex, (index) => setState(() => _minuteIndex = index)),
              ],
            ),
          ),
          CupertinoButton(
            child: Text('완료'),
            onPressed: () {
              final int hour = _amPmIndex == 0
                  ? (_hourIndex + 1) % 12
                  : (_hourIndex + 1) % 12 + 12;
              final selectedTime = TimeOfDay(hour: hour % 24, minute: _minuteIndex);
              widget.onConfirmed(selectedTime);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Expanded _buildPicker(List<String> items, int selectedIndex, ValueChanged<int> onSelectedItemChanged) {
    return Expanded(
      child: CupertinoPicker(
        scrollController: FixedExtentScrollController(initialItem: selectedIndex),
        itemExtent: 40,
        onSelectedItemChanged: onSelectedItemChanged,
        children: items.map((e) => Center(child: Text(e, style: TextStyle(fontSize: 20)))).toList(),
      ),
    );
  }
}
