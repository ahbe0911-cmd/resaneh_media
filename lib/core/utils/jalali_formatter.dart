import 'package:shamsi_date/shamsi_date.dart';

class JalaliFormatter {
  JalaliFormatter._();

  static String toPersianDigits(String value) {
    const digits = '۰۱۲۳۴۵۶۷۸۹';
    return value.replaceAllMapped(
      RegExp(r'[0-9]'),
      (match) => digits[int.parse(match.group(0)!)],
    );
  }

  static String formatDate(DateTime dateTime, {bool includeWeekday = true}) {
    final formatter = Jalali.fromDateTime(dateTime.toLocal()).formatter;
    final date = '${formatter.d} ${formatter.mN} ${formatter.yyyy}';
    return toPersianDigits(includeWeekday ? '${formatter.wN} $date' : date);
  }

  static String formatShortDate(DateTime dateTime) {
    final formatter = Jalali.fromDateTime(dateTime.toLocal()).formatter;
    return toPersianDigits('${formatter.yyyy}/${formatter.mm}/${formatter.dd}');
  }

  static String formatTime(DateTime dateTime, {bool withSeconds = false}) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = withSeconds ? ':${local.second.toString().padLeft(2, '0')}' : '';
    return toPersianDigits('$hour:$minute$suffix');
  }

  static String formatDateTime(DateTime dateTime) =>
      '${formatDate(dateTime)}، ساعت ${formatTime(dateTime)}';

  static String today() => formatDate(DateTime.now());
  static String currentTime() => formatTime(DateTime.now());
}
