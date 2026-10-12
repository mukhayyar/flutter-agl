import '../../../../../../export.dart';

class Wifi {
  final Icon icon;
  final String name;
  final bool? isConnected;

  /// connman service id (e.g. `wifi_<mac>_<ssid>_managed_psk`) used to connect
  /// to, disconnect from and poll this network. Empty for entries that do not
  /// come from connman.
  final String service;

  Wifi({
    required this.icon,
    required this.name,
    this.isConnected = false,
    this.service = '',
  });
}
