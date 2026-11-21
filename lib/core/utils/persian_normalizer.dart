class PersianNormalizer {
  PersianNormalizer._();

  static String normalize(String input) {
    var value = input.toLowerCase()
        .replaceAll('ي', 'ی')
        .replaceAll('ى', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll('ۀ', 'ه')
        .replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و')
        .replaceAll('إ', 'ا')
        .replaceAll('أ', 'ا')
        .replaceAll('ٱ', 'ا')
        .replaceAll('\u0640', '');

    value = value.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');
    value = value.replaceAllMapped(RegExp(r'[۰-۹٠-٩]'), (match) {
      final code = match.group(0)!.codeUnitAt(0);
      return (code >= 0x06F0 ? code - 0x06F0 : code - 0x0660).toString();
    });
    return value
        .replaceAll('\u200c', ' ')
        .replaceAll(RegExp(r'[\s\u00A0]+'), ' ')
        .trim();
  }

  static String compact(String input) =>
      normalize(input).replaceAll(RegExp(r'\s+'), '');

  static String escapeLike(String input) => input
      .replaceAll('!', '!!')
      .replaceAll('%', '!%')
      .replaceAll('_', '!_');

  static String searchPattern(String input) => '%${escapeLike(normalize(input))}%';

  static bool isEmpty(String input) => normalize(input).isEmpty;
}
