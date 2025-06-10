// lib/widgets/ai_schedule_card.dart
import 'package:flutter/material.dart';
import 'package:momentum_planner/AI/ai_scheduling_service.dart';

/// AI 추천 스케줄 카드
class AIScheduleCard extends StatefulWidget {
  final TaskRecommendation recommendation;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final Function(String)? onTimeChange;

  const AIScheduleCard({
    Key? key,
    required this.recommendation,
    this.onAccept,
    this.onReject,
    this.onTimeChange,
  }) : super(key: key);

  @override
  _AIScheduleCardState createState() => _AIScheduleCardState();
}

class _AIScheduleCardState extends State<AIScheduleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.elasticOut)
    );

    // 카드 등장 애니메이션
    Future.delayed(Duration(milliseconds: 100), () {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  Color(0xFF667eea),
                  Color(0xFF764ba2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                _buildHeader(),
                _buildTaskInfo(),
                _buildAIInsight(),
                if (_isExpanded) _buildAlternatives(),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.psychology,
              color: Colors.white,
              size: 24,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI 추천',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  widget.recommendation.taskTitle,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          _buildConfidenceBadge(),
        ],
      ),
    );
  }

  Widget _buildConfidenceBadge() {
    final confidence = widget.recommendation.confidence;
    Color badgeColor;
    String confidenceText;

    if (confidence >= 0.8) {
      badgeColor = Colors.green;
      confidenceText = '높음';
    } else if (confidence >= 0.6) {
      badgeColor = Colors.orange;
      confidenceText = '보통';
    } else {
      badgeColor = Colors.red.shade300;
      confidenceText = '낮음';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 4),
          Text(
            confidenceText,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskInfo() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildTimeChip(),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.recommendation.reason,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule,
            color: Colors.white,
            size: 16,
          ),
          SizedBox(width: 6),
          Text(
            widget.recommendation.recommendedTime,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIInsight() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: Colors.yellow.shade300,
            size: 20,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.recommendation.reason,
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlternatives() {
    if (widget.recommendation.alternatives.isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '다른 시간대 추천',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: widget.recommendation.alternatives.map((alt) {
              return Container(
                margin: EdgeInsets.only(right: 8),
                child: _buildAlternativeChip(alt),
              );
            }).toList(),
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildAlternativeChip(AlternativeTime alternative) {
    return GestureDetector(
      onTap: () {
        if (widget.onTimeChange != null) {
          widget.onTimeChange!(alternative.time);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              alternative.time,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 2),
            Container(
              width: 30,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(alternative.confidence),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          // 거부 버튼
          Expanded(
            child: ElevatedButton.icon(
              onPressed: widget.onReject,
              icon: Icon(Icons.close, size: 18),
              label: Text('다시 추천'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          SizedBox(width: 12),
          // 수락 버튼
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: widget.onAccept,
              icon: Icon(Icons.check, size: 18),
              label: Text('스케줄 적용'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Color(0xFF667eea),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// AI 피드백 다이얼로그
class AIFeedbackDialog extends StatefulWidget {
  final String userId;
  final List<TaskRecommendation> recommendations;
  final Function(String feedback, String comment)? onSubmit;

  const AIFeedbackDialog({
    Key? key,
    required this.userId,
    required this.recommendations,
    this.onSubmit,
  }) : super(key: key);

  @override
  _AIFeedbackDialogState createState() => _AIFeedbackDialogState();
}

class _AIFeedbackDialogState extends State<AIFeedbackDialog> {
  String _selectedFeedback = 'neutral';
  final TextEditingController _commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Row(
              children: [
                Icon(Icons.feedback, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'AI 추천 어떠셨나요?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),

            // 피드백 선택
            Text(
              '오늘의 AI 스케줄 추천이 도움이 되었나요?',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildFeedbackButton(
                  icon: Icons.thumb_up,
                  text: '좋아요',
                  value: 'thumbs_up',
                  color: Colors.green,
                ),
                _buildFeedbackButton(
                  icon: Icons.thumb_down,
                  text: '별로예요',
                  value: 'thumbs_down',
                  color: Colors.red,
                ),
                _buildFeedbackButton(
                  icon: Icons.sentiment_neutral,
                  text: '보통이에요',
                  value: 'neutral',
                  color: Colors.orange,
                ),
              ],
            ),

            SizedBox(height: 24),

            // 코멘트 입력
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: '개선사항이나 의견을 알려주세요 (선택사항)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: EdgeInsets.all(12),
              ),
              maxLines: 3,
            ),

            SizedBox(height: 24),

            // 버튼
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('나중에'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (widget.onSubmit != null) {
                        widget.onSubmit!(_selectedFeedback, _commentController.text);
                      }
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('제출', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackButton({
    required IconData icon,
    required String text,
    required String value,
    required Color color,
  }) {
    final isSelected = _selectedFeedback == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFeedback = value;
        });
      },
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.2) : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? color : Colors.grey[300]!,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: isSelected ? color : Colors.grey[600],
              size: 28,
            ),
          ),
          SizedBox(height: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? color : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}

/// 사용자 인사이트 위젯
class UserInsightsCard extends StatelessWidget {
  final UserInsights insights;

  const UserInsightsCard({Key? key, required this.insights}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.purple.shade400,
              Colors.blue.shade500,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: Colors.white, size: 24),
                SizedBox(width: 8),
                Text(
                  '나의 생산성 분석',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            _buildInsightRow(
              icon: Icons.check_circle,
              title: '완료율',
              value: '${insights.completionRate.toStringAsFixed(1)}%',
            ),

            _buildInsightRow(
              icon: Icons.access_time,
              title: '최고 집중 시간',
              value: '${insights.bestProductiveHour}시',
            ),

            _buildInsightRow(
              icon: Icons.calendar_today,
              title: '선호 요일',
              value: insights.favoriteDay,
            ),

            if (insights.averageDelay > 0)
              _buildInsightRow(
                icon: Icons.schedule,
                title: '평균 지연',
                value: '${insights.averageDelay.toStringAsFixed(0)}분',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
          SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}