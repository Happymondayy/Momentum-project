// lib/Survey/components/progress_dots.dart
import 'package:flutter/material.dart';

class ProgressDots extends StatelessWidget {
  final int totalQuestions;
  final int currentQuestionIndex;
  final Color activeColor;
  final Color inactiveColor;
  final double activeDotSize;
  final double inactiveDotSize;
  final double spacing;

  const ProgressDots({
    Key? key,
    required this.totalQuestions,
    required this.currentQuestionIndex,
    this.activeColor = const Color(0xFF6200EE), // 기본 활성 색상 (보라색)
    this.inactiveColor = const Color(0xFFE0E0E0), // 기본 비활성 색상 (회색)
    this.activeDotSize = 12.0,
    this.inactiveDotSize = 8.0,
    this.spacing = 10.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalQuestions, (index) {
        final bool isActive = index <= currentQuestionIndex;
        final bool isCurrent = index == currentQuestionIndex;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing / 2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isCurrent ? activeDotSize : inactiveDotSize,
            height: isCurrent ? activeDotSize : inactiveDotSize,
            decoration: BoxDecoration(
              color: isActive ? activeColor : inactiveColor,
              borderRadius: BorderRadius.circular(activeDotSize / 2),
              boxShadow: isCurrent ? [
                BoxShadow(
                  color: activeColor.withOpacity(0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ] : null,
            ),
          ),
        );
      }),
    );
  }
}