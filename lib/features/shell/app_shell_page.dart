import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/flavor_config.dart';
import '../../providers/settings_provider.dart';
import '../archive/pages/archive_home_page.dart';
import '../clipbox/pages/clipbox_page.dart';
import '../settings/pages/settings_page.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key, required this.config});
  final FlavorConfig config;

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  final _clipKey = GlobalKey<ClipboxPageState>();
  int _index = 0;

  void _select(int value) {
    if (value == _index || context.read<SettingsProvider>().isBusy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _index = value);
  }

  void _receiveText(String value) {
    if (!mounted) return;
    if (context.read<SettingsProvider>().isBusy) {
      // Keep the received text available to the editor; maintenance stays modal.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('پس از پایان عملیات، متن را دوباره اشتراک‌گذاری کنید.'),
      ));
      return;
    }
    _select(1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _clipKey.currentState != null) {
        unawaited(_clipKey.currentState!.receiveText(value));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.select<SettingsProvider, bool>((s) => s.isBusy);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return PopScope(
      canPop: _index == 0 && !busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0 && !busy) _select(0);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: IndexedStack(
          index: _index,
          children: [
            HeroMode(enabled: _index == 0, child: ArchiveHomePage(
              config: widget.config, active: _index == 0,
              onReceivedText: _receiveText,
            )),
            HeroMode(enabled: _index == 1, child: ClipboxPage(key: _clipKey)),
            HeroMode(enabled: _index == 2, child: SettingsPage(
              flavor: widget.config, active: _index == 2,
              onReset: () => setState(() => _index = 0),
            )),
          ],
        ),
        bottomNavigationBar: keyboard ? null : NavigationBar(
          height: 64,
          selectedIndex: _index,
          onDestinationSelected: busy ? null : _select,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.folder_open_outlined),
              selectedIcon: Icon(Icons.folder_rounded), label: 'آرشیو'),
            NavigationDestination(icon: Icon(Icons.content_paste_outlined),
              selectedIcon: Icon(Icons.content_paste_rounded), label: 'کلیپ‌باکس'),
            NavigationDestination(icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded), label: 'تنظیمات'),
          ],
        ),
      ),
    );
  }
}
