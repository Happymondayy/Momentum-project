import 'package:flutter/material.dart';

class CustomDropdown extends StatefulWidget {
  final String prompt;
  final String value;
  final List<String> options; // 선택지
  final Function(String) onChanged;
  final bool state;
  final bool isActive; // 활성화된 질문인지 여부
  final Duration animationDuration; // 애니메이션 시간 추가

  const CustomDropdown({
    Key? key,
    required this.prompt,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.state,
    this.isActive = true, // 기본값은 활성화
    this.animationDuration = const Duration(milliseconds: 300), // 기본 애니메이션 시간
  }) : super(key: key);

  @override
  _CustomDropdownState createState() => _CustomDropdownState();
}

class _CustomDropdownState extends State<CustomDropdown> with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  late String _currentValue;

  // 애니메이션 컨트롤러 추가
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;

    // 애니메이션 컨트롤러 초기화
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _expandAnimation = CurvedAnimation( // 애니메이션에 곡선 효과를 적용
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didUpdateWidget(CustomDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 위젯이 업데이트될 때 현재 값도 업데이트
    if (oldWidget.value != widget.value) {
      _currentValue = widget.value;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    if (_isOpen) {
      _overlayEntry?.remove();
    }
    super.dispose();
  }

  // 드롭다운 메뉴 생성 및 배치하는 함수
  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox; // 현재 위젯의 위치와 크기 정보를 가져옴
    var size = renderBox.size;
    final height = size.height * widget.options.length; //드롭다운 메뉴의 총 높이 계산

    return OverlayEntry( // 화면에 드롭다운 추가
      builder: (context) => Positioned(
        width: size.width,

        child: CompositedTransformFollower(// 드롭다운 위치를 헤더와 동기화
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height),

          child: AnimatedBuilder( //애니메이션 변화 반영
            animation: _expandAnimation,
            builder: (context, child) {
              return ClipRect(//드롭다운의 잘리는 부분 관리
                child: Align(// 드롭다운 높이 조정
                  alignment: Alignment.topCenter,
                  heightFactor: _expandAnimation.value,

                  child: Material( // 스타일 입히고 그림자 추가
                    elevation: 4.0,

                    child: Container( //드롭다운 스타일
                      constraints: BoxConstraints( // 드롭다운 최대 높이 제한
                        maxHeight: 60.0 * widget.options.length,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),

                      child: Column( // 선택지들 나열
                        mainAxisSize: MainAxisSize.min,

                        children: widget.options.map((option) { // 리스트 안의 데이터를 반복하며 각 항목(option)을 처리
                          return InkWell( // 개별 선택 항목(클릭 가능)
                            onTap: () {
                            setState(() {
                              _currentValue = option; //현재 선택된 값을 업데이트
                            });
                            widget.onChanged(option); // 선택된 값을 부모 위젯으로 전달
                            _closeDropdown(); // 드롭다운 메뉴를 닫음
                          },

                            child: Container( // 항목의 스타일
                              height: 60,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              color: _currentValue == option ? const Color(0xFFE6E6FA) : Colors.white,
                              alignment: Alignment.center,

                              child: Row( // 항목과 아이콘을 가로로 배치

                                children: [
                                  Expanded(
                                    child: Text(
                                      option,
                                      textAlign: TextAlign.center, // 드롭다운 메뉴 텍스트 가운데 정렬
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 16,
                                        fontWeight: _currentValue == option ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (_currentValue == option)
                                    const Icon(
                                      Icons.check,
                                      color: Colors.black,
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _toggleDropdown() { // 드롭다운 클릭시 열고 닫는 동작
    if (!widget.isActive) return; // 비활성화된 질문이면 드롭다운을 열지 않음

    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _animationController.forward(); // expandAnimation.value를 0에서 1로 증가
    setState(() {
      _isOpen = true;
    });
  }

  void _closeDropdown() {
    _animationController.reverse().then((value) { // 애니메이션을 반대로 실행해서 expandAnimation.value를 1에서 0으로 감소
      _overlayEntry?.remove();
      _overlayEntry = null;
      setState(() {
        _isOpen = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // 배경색 결정 - 답변 선택 후 회색으로 변경
    Color backgroundColor;
    if (!widget.isActive) {
      backgroundColor = const Color(0xFFF5F5F5); // 비활성화 상태일 때 연한 회색
    } else if (widget.state) {
      backgroundColor = const Color(0xFFE0E0E0); // 답변 선택 후 회색
    } else {
      backgroundColor = const Color(0xFFE6E6FA); // 활성화 상태일 때 연한 보라색
    }

    return AnimatedContainer(
      duration: widget.animationDuration, // 부드러운 전환을 위한 애니메이션 추가
      curve: Curves.easeInOut,

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center, // 전체를 가운데 정렬로 변경

        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),

            child: Text(
              widget.prompt,
              textAlign: TextAlign.center, // 질문 텍스트 가운데 정렬
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: widget.isActive ? Colors.black : Colors.grey,
              ),
            ),

          ),
          CompositedTransformTarget(
            link: _layerLink,

            child: GestureDetector(
              onTap: _toggleDropdown,

              child: Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(20),
                  color: backgroundColor,
                ),

                child: Row(

                  children: [
                    Expanded(

                      child: Text(
                        _currentValue,
                        textAlign: TextAlign.center, // 선택된 값 텍스트 가운데 정렬
                        style: TextStyle(
                          fontSize: 16,
                          color: widget.isActive ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                    // 드롭다운 아이콘이 부드럽게 회전하도록 AnimatedRotation 추가
                    AnimatedRotation(
                      turns: _isOpen ? 0.25 : -0.25, // 열릴 때는 시계 방향 90도 회전
                      duration: const Duration(milliseconds: 200),

                      child: Icon(
                        Icons.chevron_right,
                        color: widget.isActive ? Colors.black : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}