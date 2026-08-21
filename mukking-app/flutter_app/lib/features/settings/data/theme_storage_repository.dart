abstract class ThemeStorageRepository {
  Future<String?> readThemeId();

  Future<void> saveThemeId(String themeId);
}
