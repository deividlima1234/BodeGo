import 'package:isar/isar.dart';

part 'app_settings.g.dart';

@collection
class AppSettings {
  Id id = Isar.autoIncrement;

  bool isFirstRun = true;

  String? businessName;

  String selectedTheme = 'moderno';
}
