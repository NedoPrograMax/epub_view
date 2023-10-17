import 'package:easy_debounce/easy_debounce.dart';
import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';

class ScrollSlider extends StatefulWidget {
  final EpubController controller;
  const ScrollSlider({
    super.key,
    required this.controller,
  });

  @override
  State<ScrollSlider> createState() => _ScrollSliderState();
}

class _ScrollSliderState extends State<ScrollSlider> {
  double percent = 0;
  static const scrollSliderTag = "scrollSliderTag";

  @override
  void initState() {
    percent = widget.controller.currentValue?.lastProgress ?? 0;
    super.initState();
  }

  @override
  void dispose() {
    EasyDebounce.cancel(scrollSliderTag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Slider(
        value: percent,
        activeColor: const Color.fromRGBO(89, 53, 233, 1),
        inactiveColor: const Color.fromRGBO(215, 208, 245, 1),
        onChanged: (value) {
          setState(() {
            percent = value;
          });
          EasyDebounce.debounce(
            scrollSliderTag,
            const Duration(milliseconds: 100),
            () => widget.controller.scrollToPercent(percent: percent),
          );
        },
      ),
    );
  }
}
