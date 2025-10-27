import 'package:flutter_ics_homescreen/export.dart';

class StorageClientConnectedNotifier extends Notifier<bool> {
  @override
  bool build() {
    return false;
  }

  void update(bool connected) {
    state = connected;
  }
}
