import 'package:flutter_ics_homescreen/export.dart';
import 'package:protos/applauncher_api.dart';
import 'package:protos/agl_shell_api.dart';

class AppLauncher {
  final Ref ref;

  late ClientChannel aglShellChannel;
  late AglShellManagerServiceClient aglShell;
  late ClientChannel appLauncherChannel;
  late AppLauncherClient appLauncher;

  List<String> appStack = ['homescreen'];

  // agl-shell output to activate surfaces on (e.g. "HDMI-A-1"). Discovered once
  // via GetOutputs and cached. ActivateApp needs a valid output_name; without it
  // the compositor cannot place the surface, so the activate is a silent no-op.
  String _outputName = '';

  AppLauncher({required this.ref}) {
    aglShellChannel = ClientChannel('localhost',
        port: 14005,
        options: const ChannelOptions(credentials: ChannelCredentials.insecure()));

    aglShell = AglShellManagerServiceClient(aglShellChannel);

    appLauncherChannel = ClientChannel('localhost',
        port: 50052,
        options: const ChannelOptions(credentials: ChannelCredentials.insecure()));
    appLauncher = AppLauncherClient(appLauncherChannel);
  }

  run() async {
    getAppList();

    try {
      var response = appLauncher.getStatusEvents(StatusRequest());
      await for (var event in response) {
        if (event.hasApp()) {
          AppStatus appStatus = event.app;
          debugPrint("Got app status:");
          debugPrint("$appStatus");
          if (appStatus.hasId() && appStatus.hasStatus()) {
            if (appStatus.status == "started") {
              activateApp(appStatus.id);
            } else if (appStatus.status == "terminated") {
              deactivateApp(appStatus.id);
            }
          }
        }
      }
    } catch (e) {
      print(e);
    }
  }

  getAppList() async {
    try {
      var response = await appLauncher.listApplications(ListRequest());
      List<AppLauncherInfo> apps = [];
      for (AppInfo info in response.apps) {
        debugPrint("Got app:");
        debugPrint("$info");
        // Existing icons are currently not usable, so leave blank for now
        apps.add(AppLauncherInfo(
            id: info.id, name: info.name, icon: info.iconPath, internal: false));
      }
      apps.sort((a, b) => a.name.compareTo(b.name));

      // Add built-in app widgets
      apps.insert(
          0,
          AppLauncherInfo(
              id: "clock", name: "Clock", icon: "clock.svg", internal: true));
      apps.insert(
          0,
          AppLauncherInfo(
              id: "weather",
              name: "Weather",
              icon: "weather.svg",
              internal: true));

      ref.read(appLauncherListProvider.notifier).update(apps);
    } catch (e) {
      print(e);
    }
  }

  void startApp(String id) async {
    await appLauncher.startApplication(StartRequest(id: id));
  }

  /// Launch (or re-foreground) an application.
  ///
  /// [startApp] is the wrong call for an app that is already running:
  /// applaunchd treats it as a no-op, so the app the user just tapped stays
  /// behind whatever is on screen. Anything already in the stack is activated
  /// through agl-shell instead, which also makes [activateApp] pass the
  /// compositor output it needs.
  void launchApp(String id) async {
    if (appStack.contains(id)) {
      await activateApp(id);
    } else {
      startApp(id);
    }
  }

  addAppToStack(String id) {
    if (!appStack.contains(id)) {
      appStack.add(id);
    } else {
      int current = appStack.indexOf(id);
      if (current != (appStack.length - 1)) {
        appStack.removeAt(current);
        appStack.add(id);
      }
    }
  }

  /// Resolve the compositor output used for [ActivateRequest].
  ///
  /// ActivateApp needs a valid `output_name`: without it the compositor cannot
  /// place the surface and the request is a silent no-op, which is what made
  /// "come back to the store" do nothing after another app was launched. The
  /// output list is queried once and cached; with several outputs the first one
  /// is used.
  Future<String> _getOutputName() async {
    if (_outputName.isNotEmpty) {
      return _outputName;
    }

    try {
      var response = await aglShell.getOutputs(OutputRequest());
      if (response.outputs.isNotEmpty) {
        _outputName = response.outputs.first.name;
        debugPrint("agl-shell activation output: $_outputName");
      } else {
        debugPrint("agl-shell reports no output to activate on");
      }
    } catch (e) {
      debugPrint("getOutputs failed: $e");
    }

    return _outputName;
  }

  activateApp(String id) async {
    if (appStack.last != id) {
      var outputName = await _getOutputName();
      var req = ActivateRequest(appId: id, outputName: outputName);
      aglShell.activateApp(req);
      addAppToStack(id);
    }
  }

  deactivateApp(String id) async {
    if (appStack.contains(id)) {
      appStack.remove(id);
      if (appStack.isNotEmpty) {
        activateApp(appStack.last);
      }
    }
  }
}
