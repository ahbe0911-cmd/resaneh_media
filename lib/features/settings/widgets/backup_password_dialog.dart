import 'package:flutter/material.dart';

class BackupPasswordDialog extends StatefulWidget {
  const BackupPasswordDialog({super.key, required this.confirmPassword});
  final bool confirmPassword;

  @override
  State<BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<BackupPasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _repeat = TextEditingController();

  @override
  void dispose() {
    _password.clear();
    _repeat.clear();
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState?.validate() == true) {
      Navigator.pop(context, _password.text);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.confirmPassword ? 'رمزگذاری نسخه پشتیبان' : 'رمز بکاپ'),
    content: Form(key: _form, child: SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.confirmPassword
          ? 'رمزی قوی و مستقل از PIN برنامه انتخاب کنید؛ در صورت فراموشی قابل بازیابی نیست.'
          : 'رمز عبوری را که هنگام ساخت بکاپ تعیین کردید وارد کنید.'),
        const SizedBox(height: 14),
        TextFormField(controller: _password, obscureText: true,
          enableSuggestions: false, autocorrect: false,
          maxLength: 256, textInputAction: widget.confirmPassword
            ? TextInputAction.next : TextInputAction.done,
          decoration: const InputDecoration(labelText: 'رمز عبور بکاپ'),
          validator: (value) {
            if (value == null || value.isEmpty) return 'رمز را وارد کنید.';
            if (widget.confirmPassword && value.runes.length < 8) {
              return 'حداقل ۸ نویسه وارد کنید.';
            }
            return null;
          },
          onFieldSubmitted: (_) { if (!widget.confirmPassword) _submit(); },
        ),
        if (widget.confirmPassword)
          TextFormField(controller: _repeat, obscureText: true,
            enableSuggestions: false, autocorrect: false, maxLength: 256,
            decoration: const InputDecoration(labelText: 'تکرار رمز عبور'),
            validator: (value) => value != _password.text ? 'رمزها یکسان نیستند.' : null,
            onFieldSubmitted: (_) => _submit()),
      ]),
    )),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
      FilledButton(onPressed: _submit, child: const Text('ادامه')),
    ],
  );
}
