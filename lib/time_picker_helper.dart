import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'custom_time_picker_widget.dart'; // 경로는 프로젝트 구조에 따라 조정

Future<TimeOfDay?> showCustomTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) async {
  TimeOfDay? selectedTime;

  await showCupertinoModalPopup(
    context: context,
    builder: (_) => CustomTimePickerWidget(
      initialTime: initialTime,
      onConfirmed: (TimeOfDay time) {
        selectedTime = time;
      },
    ),
  );

  return selectedTime;
}
