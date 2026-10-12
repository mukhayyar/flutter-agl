import 'dart:async';
import 'dart:convert';

import 'package:flutter_ics_homescreen/presentation/custom_icons/custom_icons.dart';
import 'package:new_virtual_keyboard/virtual_keyboard.dart';

import '../../../../../../export.dart';
import 'wifi.dart';

class WifiContent extends ConsumerStatefulWidget {
  const WifiContent({
    super.key,
  });

  @override
  WifiContentState createState() => WifiContentState();
}

/// WiFi settings page backed by connman.
///
/// Everything here shells out to `connmanctl`: scanning (`services`), connecting
/// (`connect <service>` and feeding the Passphrase prompt over stdin) and
/// polling the resulting service state. The target has no NetworkManager and no
/// `nmcli`, and the AGL images ship connman only.
class WifiContentState extends ConsumerState<WifiContent> {
  List<Wifi> wifiList = <Wifi>[];
  Wifi? currentWifi;

  /// Text shown by [_connectivityBanner]; empty hides the banner.
  String _banner = '';
  bool _bannerIsError = false;
  bool _connecting = false;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // First load, then keep the list (and the connected marker) fresh while the
    // page is open -- a connect started elsewhere still shows up.
    _updateConnectivity();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 20), (_) => _updateConnectivity());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ── connman helpers ──────────────────────────────────────────────────────

  /// Run `connmanctl <args>` and return stdout+stderr.
  Future<String> _connmanctl(String args) async {
    try {
      final res = await Process.run('connmanctl', args.split(' '));
      return '${res.stdout}\n${res.stderr}'.trim();
    } catch (e) {
      debugPrint('connmanctl $args failed: $e');
      return '';
    }
  }

  /// Run `connmanctl <args>` with [input] fed to its stdin.
  ///
  /// `connmanctl connect` registers its own agent and asks for the passphrase on
  /// stdin; feeding it that way keeps the secret out of the shell command line.
  Future<String> _connmanctlWithInput(String args, String input) async {
    try {
      final proc = await Process.start('connmanctl', args.split(' '));
      proc.stdin.writeln(input);
      await proc.stdin.flush();
      await proc.stdin.close();
      final out = await proc.stdout.transform(utf8.decoder).join();
      final err = await proc.stderr.transform(utf8.decoder).join();
      return '$out\n$err'.trim();
    } catch (e) {
      debugPrint('connmanctl $args (stdin) failed: $e');
      return '';
    }
  }

  /// Parse the output of `connmanctl services`.
  ///
  /// ```
  /// *AO Wired                ethernet_xxxx_cable
  ///  *AR My_Network          wifi_xxxx_managed_psk
  ///    Open_Network          wifi_yyyy_managed_none
  /// ```
  ///
  /// The leading flags are `*` (favourite) followed by the service state:
  /// `I` idle, `A` association, `C` configuration, `R` ready, `O` online,
  /// `D` disconnect, `F` failure. Only `R`/`O` mean "connected" -- the previous
  /// `prefix.contains('*A')` check matched networks that were merely *associating*
  /// and never matched a favourite WiFi that was idle.
  List<Wifi> _parseServices(String output) {
    final result = <Wifi>[];

    for (final rawLine in output.split('\n')) {
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) {
        continue;
      }

      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) {
        continue;
      }

      final service = parts.last;
      if (!service.startsWith('wifi_')) {
        // Wired / ethernet / bluetooth services are not shown on this page.
        continue;
      }

      final flags = parts.first;
      final name = parts.sublist(1, parts.length - 1).join(' ').trim();
      final connected = flags.contains('O') || flags.contains('R');
      final secured = !service.endsWith('_none');

      result.add(Wifi(
        icon: Icon(
          connected
              ? (secured
                  ? CustomIcons.wifi_4_bar_locked
                  : CustomIcons.wifi_4_bar_unlocked)
              : (secured
                  ? CustomIcons.wifi_3_bar_locked
                  : CustomIcons.wifi_3_bar_unlocked),
          size: 48,
        ),
        name: name.isEmpty ? service : name,
        isConnected: connected,
        service: service,
      ));
    }

    // Connected networks first, then alphabetically.
    result.sort((a, b) {
      if (a.isConnected != b.isConnected) {
        return a.isConnected! ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return result;
  }

  /// Rescan and refresh the list, the connected marker and the banner.
  Future<void> _updateConnectivity() async {
    final output = await _connmanctl('services');
    if (output.isEmpty) {
      if (mounted) {
        setState(() {
          _banner = 'WiFi unavailable (connmanctl not responding)';
          _bannerIsError = true;
        });
      }
      return;
    }

    final services = _parseServices(output);
    if (!mounted) {
      return;
    }

    Wifi? active;
    for (final service in services) {
      if (service.isConnected == true) {
        active = service;
        break;
      }
    }

    setState(() {
      wifiList = services;
      currentWifi = active;
      if (!_connecting) {
        _banner = currentWifi == null
            ? ''
            : 'Connected to ${currentWifi!.name}';
        _bannerIsError = false;
      }
    });
  }

  /// Poll `connmanctl services <service>` until it is connected (ready/online)
  /// or fails, so the UI can report the real outcome instead of assuming success.
  Future<String> _waitForServiceState(
    String service, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final deadline = DateTime.now().add(timeout);
    var state = '';

    while (DateTime.now().isBefore(deadline)) {
      final output = await _connmanctl('services $service');
      state = RegExp(r'State\s*=\s*(\w+)')
              .firstMatch(output)
              ?.group(1)
              ?.toLowerCase() ??
          '';

      if (state == 'ready' || state == 'online') {
        return state;
      }
      if (state == 'failure' || state == 'disconnect') {
        return state;
      }
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }

    return state;
  }

  /// Fold the outcome of a connect attempt into the UI state.
  Future<void> _applyConnectResult(Wifi wifi, String state, String output) async {
    final connected = state == 'ready' || state == 'online';

    await _updateConnectivity();

    if (!mounted) {
      return;
    }
    setState(() {
      _connecting = false;
      _bannerIsError = !connected;
      if (connected) {
        currentWifi = wifi;
        _banner = 'Connected to ${wifi.name}';
      } else if (state == 'failure') {
        _banner = 'Failed to connect to ${wifi.name} (wrong password?)';
      } else {
        final trimmed = output.trim();
        _banner = trimmed.isEmpty
            ? 'Could not connect to ${wifi.name}'
            : trimmed.split('\n').last;
      }
    });
  }

  /// The status strip above the network list.
  Widget _connectivityBanner() {
    final connected = currentWifi != null;
    final color = _bannerIsError
        ? const Color(0xFFFF5252)
        : (connected ? const Color(0xFF4CAF50) : Colors.white70);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 144),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _bannerIsError
                ? Icons.error_outline
                : (connected ? Icons.wifi : Icons.wifi_find),
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _connecting
                  ? 'Connecting…'
                  : (_banner.isEmpty ? 'Select a network' : _banner),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: color),
            ),
          ),
          if (_connecting)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  // ── actions ──────────────────────────────────────────────────────────────

  /// Connect to [wifi], or disconnect when it is already connected.
  Future<void> _connect(Wifi wifi) async {
    if (_connecting || wifi.service.isEmpty) {
      return;
    }

    if (wifi.isConnected == true) {
      setState(() {
        _connecting = true;
        _banner = 'Disconnecting from ${wifi.name}…';
        _bannerIsError = false;
      });
      await _connmanctl('disconnect ${wifi.service}');
      setState(() => _connecting = false);
      await _updateConnectivity();
      return;
    }

    String passphrase = '';
    if (!wifi.service.endsWith('_none')) {
      final entered = await _askPassphrase(wifi.name);
      if (entered == null || entered.isEmpty) {
        return;
      }
      passphrase = entered;
    }

    setState(() {
      _connecting = true;
      _banner = 'Connecting to ${wifi.name}…';
      _bannerIsError = false;
    });

    final output = passphrase.isEmpty
        ? await _connmanctl('connect ${wifi.service}')
        : await _connmanctlWithInput('connect ${wifi.service}', passphrase);

    final state = await _waitForServiceState(wifi.service);
    await _applyConnectResult(wifi, state, output);
  }

  /// Password dialog for WPA/WPA2 networks, using the on-screen keyboard the
  /// vehicle HMI ships (no physical keyboard on the target).
  Future<String?> _askPassphrase(String ssid) {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: Text(
            'Password for $ssid',
            style: Theme.of(dialogContext).textTheme.titleMedium,
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          content: SizedBox(
            width: 900,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  readOnly: true,
                  obscureText: false,
                  autofocus: false,
                  style: Theme.of(dialogContext).textTheme.titleMedium,
                  decoration: const InputDecoration(
                    hintText: 'Network password',
                  ),
                ),
                const SizedBox(height: 16),
                VirtualKeyboard(
                  type: VirtualKeyboardType.Alphanumeric,
                  textColor: Colors.white,
                  height: 260,
                  onKeyPress: (key) {
                    if (key.keyType == VirtualKeyboardKeyType.String) {
                      controller.text += key.capsText ?? key.text ?? '';
                    } else {
                      switch (key.action) {
                        case VirtualKeyboardKeyAction.Backspace:
                          if (controller.text.isNotEmpty) {
                            controller.text = controller.text
                                .substring(0, controller.text.length - 1);
                          }
                          break;
                        case VirtualKeyboardKeyAction.Space:
                          controller.text += ' ';
                          break;
                        case VirtualKeyboardKeyAction.Return:
                          Navigator.of(dialogContext).pop(controller.text);
                          break;
                        default:
                          break;
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Connect'),
            ),
          ],
        );
      },
    );
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CommonTitle(
          title: "Wifi",
          hasBackButton: true,
          onPressed: () {
            ref.read(appProvider.notifier).back();
          },
        ),
        const SizedBox(height: 8),
        _connectivityBanner(),
        Expanded(
          child: wifiList.isEmpty
              ? Center(
                  child: Text(
                    'No WiFi networks found',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 144),
                  itemCount: wifiList.length,
                  separatorBuilder: (context, index) {
                    return const SizedBox(
                      height: 8,
                    );
                  },
                  itemBuilder: (context, index) {
                    return Container(
                      height: 130,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            stops: wifiList[index].isConnected == true
                                ? [0, 0.01, 0.8]
                                : [0.1, 1],
                            colors: wifiList[index].isConnected == true
                                ? <Color>[
                                    Colors.white,
                                    Colors.blue,
                                    const Color.fromARGB(16, 41, 98, 255)
                                  ]
                                : <Color>[Colors.black, Colors.black12]),
                      ),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 41, horizontal: 24),
                        leading: wifiList[index].icon,
                        title: Text(
                          wifiList[index].name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        trailing: wifiList[index].isConnected == true
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                        onTap: () {
                          _connect(wifiList[index]);
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
