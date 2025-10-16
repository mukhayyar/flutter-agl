import 'package:flutter_ics_homescreen/export.dart';
import 'package:toml/toml.dart';

class RadioPreset {
  final int frequency;
  final String name;

  RadioPreset({required this.frequency, required this.name});
}

class RadioPresets {
  final List<RadioPreset> fmPresets;

  RadioPresets({required this.fmPresets});
}

final radioPresetsProvider = Provider((ref) {
  final presetsFilename = ref.read(appConfigProvider).radioConfig.presets;
  if (presetsFilename.isEmpty) {
    return RadioPresets(fmPresets: []);
  }
  try {
    print("Reading radio presets $presetsFilename");
    var presetsFile = File(presetsFilename);
    String content = presetsFile.readAsStringSync();
    final configMap = TomlDocument.parse(content).toMap();

    List<RadioPreset> presets = [];
    if (configMap.containsKey('fm') && configMap['fm'] is List) {
      List presetList = configMap['fm'];
      for (var element in presetList) {
        if ((element is Map) &&
            element.containsKey('frequency') &&
            element.containsKey('name')) {
          presets.add(RadioPreset(
              frequency: element['frequency'].toInt(),
              name: element['name'].toString()));
        }
      }
    }
    return RadioPresets(fmPresets: presets);
  } catch (_) {
    debugPrint("Exception reading presets!");
    return RadioPresets(fmPresets: []);
  }
});
