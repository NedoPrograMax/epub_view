import 'package:epub_view/epub_view.dart';
import 'package:epub_view/src/data/models/chapter_view_value.dart';
import 'package:flutter/material.dart';

class EpubViewBottomBar extends StatelessWidget {
  final EpubController controller;
  final Widget Function(EpubChapterViewValue? data)? builder;
  const EpubViewBottomBar({
    super.key,
    required this.controller,
    this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color.fromARGB(1, 170, 160, 181), width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 16,
      ),
      child: ValueListenableBuilder<EpubChapterViewValue?>(
        valueListenable: controller.currentValueListenable,
        builder: (context, value, child) => builder != null
            ? builder!(value)
            : Center(
                child: Text(
                  value?.progress.toString() ?? "",
                ),
              ),
      ),
    );
  }
}
