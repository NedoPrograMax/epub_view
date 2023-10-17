import 'package:epub_view/epub_view.dart';
import 'package:epub_view/src/data/models/chapter_view_value.dart';
import 'package:epub_view/src/ui/scroll_slider.dart';
import 'package:flutter/material.dart';

class EpubViewBottomBar extends StatefulWidget {
  final EpubController controller;
  final Widget Function(EpubChapterViewValue? data)? builder;
  const EpubViewBottomBar({
    super.key,
    required this.controller,
    this.builder,
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
      child: Stack(
        children: [
          if (showSlider) ScrollSlider(controller: widget.controller),
          Container(
            height: 56,
            decoration: const BoxDecoration(
              border: Border(
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
                          value?.progress.toString() ?? "",
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
