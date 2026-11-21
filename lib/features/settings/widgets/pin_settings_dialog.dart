import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum PinAction { enable, change, disable }

class PinFormResult {
  const PinFormResult({required this.currentPin, required this.newPin});
  final String currentPin;
  final String newPin;
}

class PinSettingsDialog extends StatefulWidget {
  const PinSettingsDialog({super.key, required this.action});
  final PinAction action;

  @override
  State<PinSettingsDialog> createState() => _PinSettingsDialogState();
}

class _PinSettingsDialogState extends State<PinSettingsDialog> {
  final _key = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _repeat = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Widget _pinField(TextEditingController controller, String title) =>
      TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 4,
        obscureText: true,
        enableSuggestions: false,
        autocorrect: false,
        decoration: InputDecoration(labelText: title, counterText: ''),
        validator: (value) => value == null || !RegExp(r'^\d{4}$').hasMatch(value)
            ? 'دقیقاً چهار رقم وارد کنید.' : null,
      );

  @override
  Widget build(BuildContext context) {
    final changing = widget.action == PinAction.change;
    final disabling = widget.action == PinAction.disable;
    return AlertDialog(
      title: Text(disabling ? 'غیرفعال کردن قفل' : changing ? 'تغییر رمز ورود' : 'فعال‌سازی رمز ورود'),
      content: Form(
        key: _key,
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (changing || disabling) ...[
              _pinField(_current, 'رمز فعلی'),
              const SizedBox(height: 12),
            ],
            if (!disabling) ...[
              _pinField(_next, 'رمز چهاررقمی جدید'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _repeat,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 4,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'تکرار رمز جدید', counterText: ''),
                validator: (value) => value != _next.text ? 'رمزهای جدید یکسان نیستند.' : null,
              ),
            ],
          ],
        )),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
        FilledButton(
          onPressed: () {
            if (_key.currentState?.validate() != true) return;
            Navigator.pop(context, PinFormResult(
              currentPin: _current.text,
              newPin: _next.text,
            ));
          },
          child: Text(disabling ? 'حذف قفل' : 'ثبت رمز'),
        ),
      ],
    );
  }
}
