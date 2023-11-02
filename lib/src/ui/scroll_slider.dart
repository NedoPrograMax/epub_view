import 'package:easy_debounce/easy_debounce.dart';
import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';

class ScrollSlider extends StatefulWidget {
  final EpubController controller;
  final Color? backgroundColor;
  final ValueNotifier<double> currentPercent;
  const ScrollSlider({
    super.key,
    this.backgroundColor,
    required this.currentPercent,
    required this.controller,
  });

  @override
  State<ScrollSlider> createState() => _ScrollSliderState();
}

class _ScrollSliderState extends State<ScrollSlider> {
  DateTime lastScrollToPlace = DateTime.now();
  static const scrollSliderTag = "scrollSliderTag";

  @override
  void initState() {
    widget.currentPercent.value =
        widget.controller.currentValue?.lastProgress ?? 0;
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
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        border: const Border(
          top:
              BorderSide(color: Color.fromARGB(255, 170, 170, 181), width: 0.5),
        ),
      ),
      child: ValueListenableBuilder<double>(
        valueListenable: widget.currentPercent,
        builder: (context, percent, child) => Slider(
          value: percent,
          activeColor: const Color.fromRGBO(89, 53, 233, 1),
          inactiveColor: const Color.fromRGBO(215, 208, 245, 1),
          onChanged: (value) {
            widget.currentPercent.value = value;

            EasyDebounce.debounce(
              scrollSliderTag,
              const Duration(milliseconds: 100),
              () {
                lastScrollToPlace = DateTime.now();
                widget.controller
                    .jumpToPercent(percent: widget.currentPercent.value);
              },
            );
          },
        ),
      ),
    );
  }

  void controllerListener() {
    if (DateTime.now().difference(lastScrollToPlace).inSeconds >= 2) {
      widget.currentPercent.value =
          widget.controller.currentValueListenable.value?.lastProgress ?? 0;
    }
  }
}
