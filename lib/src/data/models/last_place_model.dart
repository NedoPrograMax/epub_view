class LastPlaceModel {
  final int? index;
  final double? percent;

  const LastPlaceModel({
    required this.percent,
    required this.index,
  });

  LastPlaceModel copyWith({
    String? chapterTitle,
    int? chapterIndex,
    double? chapterPercent,
  }) =>
      LastPlaceModel(
        percent: chapterPercent ?? percent,
        index: chapterIndex ?? index,
      );
}
