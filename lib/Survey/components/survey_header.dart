// lib/Survey/components/survey_header.dart
import 'package:flutter/material.dart';

class SurveyHeader extends StatelessWidget {
  const SurveyHeader({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32.0, bottom: 16.0),
      child: Column(
        children: [
          const Text(
            '사용자에 대해 알려주세요!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '답변을 입력하면 사용자의 하루 패턴을',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          Text(
            '상세하게 이용할 수 있어요!',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}