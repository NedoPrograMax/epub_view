class LastPlaceModel {
  final int? index;
  final double? percent;

  const LastPlaceModel({
    required this.percent,
    required this.index,
  });

  bool isAfter(LastPlaceModel other) {
    if (index != null &&
        other.index != null &&
        percent != null &&
        other.percent != null) {
      if (index! < other.index!) {
        return false;
      } else if (index == other.index && percent! < other.percent!) {
        return false;
      } else {
        return true;
      }
    }
    return false;
  }

  LastPlaceModel copyWith({
    int? index,
    double? percent,
  }) =>
      LastPlaceModel(
        percent: percent ?? percent,
        index: index ?? index,
      );
}
