import 'package:flutter/material.dart';

class ProgressSection extends StatelessWidget {
  const ProgressSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FFE8),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Progress Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          _buildProgressBar(context),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(5)),
                  ),
                  Container(
                    height: 10,
                    width: MediaQuery.of(context).size.width * 0.3,
                    decoration: BoxDecoration(
                        color: Color(0xFFECDBF9), borderRadius: BorderRadius.circular(5)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            const Text('50%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 6), // 여백 추가
        const Text('5/10 Task Complete', style: TextStyle(fontSize: 13, color: Colors.black)),
      ],
    );
  }
}
