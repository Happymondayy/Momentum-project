import 'package:flutter/material.dart';

class CustomDropdown extends StatefulWidget {
  final String prompt;
  final String value;
  final List<String> options;
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

    _expandAnimation = CurvedAnimation(
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

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    final height = size.height * widget.options.length;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height),
          child: AnimatedBuilder(
            animation: _expandAnimation,
            builder: (context, child) {
              return ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: _expandAnimation.value,
                  child: Material(
                    elevation: 4.0,
                    child: Container(
                      constraints: BoxConstraints(
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: widget.options.map((option) {
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _currentValue = option;
                              });
                              widget.onChanged(option);
                              _closeDropdown();
                            },
                            child: Container(
                              height: 60,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              color: _currentValue == option ? const Color(0xFFE6E6FA) : Colors.white,
                              alignment: Alignment.center,
                              child: Row(
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

  void _toggleDropdown() {
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
    _animationController.forward();
    setState(() {
      _isOpen = true;
    });
  }

  void _closeDropdown() {
    _animationController.reverse().then((value) {
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
                      turns: _isOpen ? 0.25 : -0.25,
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