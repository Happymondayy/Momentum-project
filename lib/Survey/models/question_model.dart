// lib/Survey/models/question_model.dart
class QuestionModel {
  final String prompt;
  String value;
  final List<String> options;
  bool state;
  bool isActive;

  QuestionModel({
    required this.prompt,
    required this.value,
    required this.options,
    this.state = false,
    this.isActive = false,
  });

  // 모델을 복사하는 메서드
  QuestionModel copyWith({
    String? prompt,
    String? value,
    List<String>? options,
    bool? state,
    bool? isActive,
  }) {
    return QuestionModel(
      prompt: prompt ?? this.prompt,
      value: value ?? this.value,
      options: options ?? this.options,
      state: state ?? this.state,
      isActive: isActive ?? this.isActive,
    );
  }
}