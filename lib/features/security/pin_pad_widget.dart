import 'package:flutter/material.dart';

import '../../core/utils/jalali_formatter.dart';

class PinPadWidget extends StatelessWidget {
  const PinPadWidget({super.key, required this.length, required this.onDigit,
    required this.onDelete, this.onBiometric, this.busy = false,
    this.hasError = false});

  final int length;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onBiometric;
  final bool busy, hasError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Semantics(label: '${JalaliFormatter.toPersianDigits('$length')} رقم وارد شده',
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < 4; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.symmetric(horizontal: 9),
              width: 15, height: 15,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: hasError ? scheme.error :
                  i < length ? scheme.primary : scheme.surfaceContainerHighest,
                border: Border.all(color: hasError ? scheme.error : scheme.outlineVariant)),
            ),
        ])),
      const SizedBox(height: 24),
      Directionality(textDirection: TextDirection.ltr, child: Column(children: [
        for (var row = 0; row < 3; row++)
          Padding(padding: const EdgeInsets.only(bottom: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              for (var n = row * 3 + 1; n <= row * 3 + 3; n++)
                _digit(context, '$n'),
            ])),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          SizedBox(width: 76, height: 60, child: onBiometric == null ? null :
            IconButton(tooltip: 'ورود با اثر انگشت یا چهره',
              onPressed: busy ? null : onBiometric,
              icon: const Icon(Icons.fingerprint_rounded, size: 34))),
          _digit(context, '0'),
          SizedBox(width: 76, height: 60, child: IconButton(
            tooltip: 'پاک کردن رقم', onPressed: busy || length == 0 ? null : onDelete,
            icon: const Icon(Icons.backspace_outlined))),
        ]),
      ])),
    ]);
  }

  Widget _digit(BuildContext context, String digit) => SizedBox(
    width: 76, height: 60,
    child: FilledButton.tonal(
      onPressed: busy ? null : () => onDigit(digit),
      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20))),
      child: Text(JalaliFormatter.toPersianDigits(digit),
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600)),
    ),
  );
}
