import 'export.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The target has no internet access at boot, and a runtime Google Fonts fetch
  // makes the first frame wait on a failing HTTP request (and floods the log).
  // The bundled fonts are enough.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Start asynchronously connecting to API provider backends
  final container = ProviderContainer();
  container.read(storageClientProvider).connect();
  container.read(valClientProvider).connect();
  container.read(radioClientProvider).connect();
  container.read(mpdClientProvider).connect();

  // Pass the container to ProviderScope and then run the app.
  runApp(ProviderScope(parent: container, child: const App()));
}
