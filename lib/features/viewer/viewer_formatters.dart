import '../../core/utils/jalali_formatter.dart';

class ViewerFormatters {
  ViewerFormatters._();

  static String playbackTime(Duration value) {
    final seconds = value.inSeconds < 0 ? 0 : value.inSeconds;
    final h = seconds ~/ 3600;
    final m = (seconds ~/ 60 % 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return JalaliFormatter.toPersianDigits(h > 0 ? '$h:$m:$s' : '$m:$s');
  }

  static Duration clampPosition(Duration value, Duration duration) {
    if (value < Duration.zero || duration <= Duration.zero) return Duration.zero;
    return value > duration ? duration : value;
  }

  static String speed(double value) =>
      '${JalaliFormatter.toPersianDigits(value.toStringAsFixed(
        value == value.roundToDouble() ? 0 : 1,
      ))}×';
}
