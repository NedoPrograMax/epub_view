import 'dart:collection';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:epub_view/src/data/models/last_place_model.dart';
import 'package:epub_view/src/data/models/paragraph_progress_percent.dart';
import 'package:epub_view/src/helpers/utils.dart';
import 'package:html/dom.dart' as dom;

class Paragraph {
  Paragraph({
    required this.element,
    required this.chapterIndex,
    this.symbolsCount = 0,
    required SplayTreeSet<ParagraphProgressPercent> percents,
    required this.wordsBefore,
    this.whenEnteredScreen,
  })  : _percents = percents,
        _tempPercents = SplayTreeSet.from([]);

  final dom.Element element;
  final int chapterIndex;
  final int symbolsCount;
  final int wordsBefore;
  DateTime? whenEnteredScreen;
  final SplayTreeSet<ParagraphProgressPercent> _percents;
  final SplayTreeSet<ParagraphProgressPercent> _tempPercents;

  LastPlaceModel toLastPlace(int index) => LastPlaceModel(
        percent: percent,
        index: index + 1,
      );

  void setPercent(double percent) {
    _percents.clear();
    _percents.add(
      ParagraphProgressPercent(
        start: 0,
        end: min(1, percent),
      ),
    );
  }

  Duration setProgressAndReturnRestTimeLeft(
      Duration time, ParagraphProgressPercent seenPart) {
    if (seenPart.end - seenPart.start == 0) {
      return time;
    }
    if (symbolsCount == 0) {
      return time;
    }
    if (percent == 1.0) {
      return time;
    }
    late final SplayTreeSet<ParagraphProgressPercent> percents;
    //disabling the "fast scroll" flow, so it doesnt count anything
    final now = DateTime.now();
    if (whenEnteredScreen != null &&
        now
                .difference(whenEnteredScreen!)
                .compareTo(const Duration(milliseconds: 1000)) <
            0) {
      percents = _tempPercents;
    } else {
      if (_tempPercents.isNotEmpty) {
        _percents.clear();
        _percents.addAll(_tempPercents);
        _tempPercents.clear();
      }
      percents = _percents;
    }
    // setting start and end to closest existint ones for better results
    final lastLess = percents.lastWhere(
      (value) => value.end < seenPart.start,
      orElse: () => seenPart,
    );
    if (seenPart.start - lastLess.end < 0.01 && lastLess != seenPart) {
      seenPart = seenPart.copyWith(start: lastLess.end);
    }
    final firstMore = percents.firstWhere(
      (value) => value.start > seenPart.end,
      orElse: () => seenPart,
    );
    if (firstMore.start - seenPart.end < 0.01 && firstMore != seenPart) {
      seenPart = seenPart.copyWith(end: firstMore.start);
    }

    final intersections = percents
        .where((element) =>
            (element.start <= seenPart.end &&
                element.start >= seenPart.start) ||
            (element.end >= seenPart.start && element.end <= seenPart.end) ||
            (element.start <= seenPart.start && element.end >= seenPart.end))
        .toList();

    final instersectionsPercent = intersections.fold<double>(
        0.0,
        (previousValue, element) =>
            previousValue +
            ((element.start <= seenPart.end && element.start >= seenPart.start)
                ? min(element.end, seenPart.end) - element.start
                : (element.end >= seenPart.start && element.end <= seenPart.end)
                    ? element.end - max(element.start, seenPart.start)
                    : seenPart.end - seenPart.start));
    var seenPartPercent = seenPart.end - seenPart.start;
    seenPartPercent -= instersectionsPercent;
    seenPartPercent = max(0, seenPartPercent);
    final timeForParagraph = countReadDurationOfParagraph(this);

    final timeForPercentMilis =
        timeForParagraph.inMilliseconds * seenPartPercent;
    if (timeForPercentMilis == 0) {
      return time;
    }

    var ourPercent = time.inMilliseconds / timeForParagraph.inMilliseconds;

    var combinedArea = ParagraphProgressPercent(
      start: seenPart.start,
      end: seenPart.start,
    );
    var intersectionIndex = 0;

    while (ourPercent >= 0 && combinedArea.end < seenPart.end) {
      final firstStart = intersectionIndex < intersections.length
          ? intersections[intersectionIndex]
          : ParagraphProgressPercent(start: seenPart.end, end: seenPart.end);

      final distanceToFirstStart = firstStart.start - combinedArea.end;
      if (distanceToFirstStart <= 0) {
        combinedArea = ParagraphProgressPercent(
            start: min(combinedArea.start, firstStart.start),
            end: max(firstStart.end, combinedArea.end));
        percents.remove(firstStart);
      } else if (distanceToFirstStart <= ourPercent) {
        combinedArea = ParagraphProgressPercent(
            start: min(combinedArea.start, firstStart.start),
            end: max(firstStart.end, combinedArea.end));
        percents.remove(firstStart);
        ourPercent -= distanceToFirstStart;
      } else {
        combinedArea = ParagraphProgressPercent(
          start: combinedArea.start,
          end: combinedArea.end + ourPercent,
        );
        ourPercent = -1;
      }
      intersectionIndex++;
    }
    if (combinedArea.start != combinedArea.end) {
      percents.add(combinedArea);
    }
    final timeLeftMilis = max(timeForPercentMilis * ourPercent, 0.0);
    final leftDuration = Duration(milliseconds: timeLeftMilis.toInt());
    return leftDuration;
  }

  double get percent => min(
      1,
      _percents.fold(
        0,
        (previousValue, element) => previousValue + element.end - element.start,
      ));

  void enterScreen() {
    whenEnteredScreen = DateTime.now();
    _tempPercents.clear();
    _tempPercents.addAll(_percents);
  }

  void leaveScreen() {
    whenEnteredScreen = null;
    _tempPercents.clear();
  }
}

extension ParagraphsExtension on List<Paragraph> {
  LastPlaceModel binarySearchForPlaceByPercent(double percent) {
    var min = 0;
    var max = length;
    final wordsByPercent = (last.wordsBefore + last.symbolsCount) * percent;

    while (min < max) {
      var mid = min + ((max - min) >> 1);
      var element = this[mid];

      if (element.wordsBefore < wordsByPercent &&
          element.wordsBefore + element.symbolsCount >= wordsByPercent) {
        return LastPlaceModel(
          percent:
              (element.wordsBefore + element.symbolsCount - wordsByPercent) /
                  element.symbolsCount,
          index: mid,
        );
      } else if (element.wordsBefore < wordsByPercent &&
          element.wordsBefore + element.symbolsCount < wordsByPercent) {
        min = mid + 1;
      } else {
        max = mid;
      }
    }
    return const LastPlaceModel(
      percent: 0,
      index: 0,
    );
  }

  void countProgress(Duration time, List<ParagraphProgressPercent> seenParts) {
    var timeMillis = time.inMilliseconds;
    for (var i = 0; i < length; i++) {
      final timeLeft = this[i].setProgressAndReturnRestTimeLeft(
          Duration(milliseconds: timeMillis), seenParts[i]);
      timeMillis = timeLeft.inMilliseconds;
      if (timeMillis <= 0) {
        break;
      }
    }
  }
}
