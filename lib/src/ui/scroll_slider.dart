import 'package:easy_debounce/easy_debounce.dart';
import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';

class ScrollSlider extends StatefulWidget {
  final EpubController controller;
  final Color? backgroundColor;
  const ScrollSlider({
    super.key,
    this.backgroundColor,
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
    widget.controller.currentValueListenable.addListener(controllerListener);
    super.initState();
  }

  @override
  void dispose() {
    EasyDebounce.cancel(scrollSliderTag);
    widget.controller.currentValueListenable.removeListener(controllerListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      color: widget.backgroundColor,
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

  void controllerListener() {
    setState(() {
      percent =
          widget.controller.currentValueListenable.value?.lastProgress ?? 0;
    });
  }
}
