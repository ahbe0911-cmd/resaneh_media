import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/app_lock_controller.dart';

class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});
  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<AppLockController>().initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      context.read<AppLockController>().lock();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<AppLockController>();
    // Keep the Navigator mounted under the opaque lock screen. Replacing it
    // would destroy active routes when Android's document picker pauses us.
    return Stack(fit: StackFit.expand, children: [
      widget.child,
      if (!lock.isReady)
        const Positioned.fill(child: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        )),
      if (lock.isReady && !lock.unlocked)
        const Positioned.fill(child: _UnlockPage()),
    ]);
  }
}

class _UnlockPage extends StatefulWidget {
  const _UnlockPage();

  @override
  State<_UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends State<_UnlockPage> {
  final _pin = TextEditingController();
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_checking) return;
    if (!RegExp(r'^\d{4}$').hasMatch(_pin.text)) {
      setState(() => _error = 'رمز چهاررقمی را وارد کنید.');
      return;
    }
    setState(() { _checking = true; _error = null; });
    try {
      final ok = await context.read<AppLockController>().unlock(_pin.text);
      if (!ok && mounted) setState(() => _error = 'رمز نادرست است.');
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      _pin.clear();
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lock_rounded, size: 68, color: scheme.primary),
                const SizedBox(height: 20),
                Text('آرشیو خصوصی', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 10),
                const Text('برای ورود، رمز چهاررقمی برنامه را وارد کنید.'),
                const SizedBox(height: 24),
                TextField(
                  controller: _pin,
                  autofocus: true,
                  obscureText: true,
                  obscuringCharacter: '●',
                  enableSuggestions: false,
                  autocorrect: false,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(labelText: 'رمز ورود'),
                ),
                if (_error != null) ...[
                  Text(_error!, textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.error)),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  onPressed: _checking ? null : _submit,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: Text(_checking ? 'در حال بررسی...' : 'باز کردن برنامه'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
