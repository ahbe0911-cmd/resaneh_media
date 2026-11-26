import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/app_lock_controller.dart';
import 'pin_pad_widget.dart';

class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});
  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  late final AppLockController _lock;
  bool _covered = false;

  @override
  void initState() {
    super.initState();
    _lock = context.read<AppLockController>();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_lock.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _lock.onBackground();
    } else if (state == AppLifecycleState.resumed) {
      _lock.onForeground();
    }
    final covered = state != AppLifecycleState.resumed;
    if (_covered != covered && mounted) setState(() => _covered = covered);
    if (covered && _lock.enabled) FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<AppLockController>();
    final blocked = !lock.isReady || !lock.unlocked || (_covered && lock.enabled);
    return Stack(fit: StackFit.expand, children: [
      ExcludeSemantics(excluding: blocked, child: ExcludeFocus(
        excluding: blocked, child: AbsorbPointer(
          absorbing: blocked, child: widget.child,
        ),
      )),
      if (!lock.isReady)
        const Positioned.fill(child: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        )),
      if (lock.isReady && !lock.unlocked)
        const Positioned.fill(child: _UnlockPage()),
      if (_covered && lock.enabled)
        Positioned.fill(child: AbsorbPointer(child: ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Center(child: Icon(Icons.lock_rounded,
            color: Theme.of(context).colorScheme.primary, size: 48)),
        ))),
    ]);
  }
}

class _UnlockPage extends StatefulWidget {
  const _UnlockPage();

  @override
  State<_UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends State<_UnlockPage> {
  String _pin = '';
  bool _checking = false;
  String? _error;

  void _digit(String value) {
    if (_checking || _pin.length >= 4) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() { _pin += value; _error = null; });
    if (_pin.length == 4) unawaited(_submit());
  }

  Future<void> _submit({bool biometric = false}) async {
    if (_checking) return;
    if (!biometric && _pin.length != 4) return;
    final lock = context.read<AppLockController>();
    setState(() { _checking = true; _error = null; });
    try {
      final ok = biometric ? await lock.unlockBiometric() : await lock.unlock(_pin);
      if (!ok && mounted) {
        unawaited(HapticFeedback.heavyImpact());
        setState(() => _error = biometric
          ? 'احراز هویت انجام نشد؛ از PIN استفاده کنید.' : 'رمز نادرست است.');
      }
    } catch (error) {
      if (mounted) {
        unawaited(HapticFeedback.heavyImpact());
        setState(() => _error = biometric
          ? 'ورود بیومتریک در دسترس نیست؛ PIN را وارد کنید.' : '$error');
      }
    } finally {
      if (mounted) setState(() { _pin = ''; _checking = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lock = context.watch<AppLockController>();
    return PopScope(canPop: false, child: Scaffold(
      body: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 340),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 72, height: 72,
              decoration: BoxDecoration(color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(24)),
              child: Icon(Icons.lock_person_rounded, size: 36,
                color: scheme.onPrimaryContainer)),
            const SizedBox(height: 18),
            Text('آرشیو خصوصی', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('رمز چهاررقمی را وارد کنید', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            PinPadWidget(length: _pin.length, busy: _checking, hasError: _error != null,
              onDigit: _digit,
              onDelete: () => setState(() {
                if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
                _error = null;
              }),
              onBiometric: lock.biometricEnabled && lock.biometricAvailable
                ? () => unawaited(_submit(biometric: true)) : null,
            ),
            const SizedBox(height: 14),
            if (_checking) const LinearProgressIndicator(minHeight: 2),
            if (_error != null) Text(_error!, textAlign: TextAlign.center,
              style: TextStyle(color: scheme.error)),
          ]),
        ),
      ))),
    ));
  }
}
