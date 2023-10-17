import 'package:epub_view/epub_view.dart';
import 'package:epub_view/src/data/models/chapter_view_value.dart';
import 'package:epub_view/src/ui/scroll_slider.dart';
import 'package:flutter/material.dart';

class EpubViewBottomBar extends StatefulWidget {
  final EpubController controller;
  final Widget Function(EpubChapterViewValue? data)? builder;
  final Color? backgroundColor;
  const EpubViewBottomBar({
    super.key,
    required this.controller,
    this.builder,
    this.backgroundColor,
  });

  @override
  State<EpubViewBottomBar> createState() => _EpubViewBottomBarState();
}

class _EpubViewBottomBarState extends State<EpubViewBottomBar> {
  bool showSlider = false;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 114,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AnimatedSlide(
            duration: const Duration(milliseconds: 200),
            offset: showSlider ? Offset.zero : const Offset(0, 1),
            child: ScrollSlider(
              controller: widget.controller,
              backgroundColor: widget.backgroundColor,
            ),
          ),
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              border: const Border(
                top: BorderSide(
                    color: Color.fromARGB(255, 170, 170, 181), width: 0.5),
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  showSlider = !showSlider;
                });
              },
              child: ValueListenableBuilder<EpubChapterViewValue?>(
                valueListenable: widget.controller.currentValueListenable,
                builder: (context, value, child) => widget.builder != null
                    ? widget.builder!(value)
                    : Center(
                        child: Text(
                          value?.lastProgress.toString() ?? "",
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
