class VersionUtils {
  static int compareVersions(String version1, String version2) {
    final v1Parts = version1.split('.').map(int.parse).toList();
    final v2Parts = version2.split('.').map(int.parse).toList();
    
    // Pad shorter version with zeros
    while (v1Parts.length < v2Parts.length) v1Parts.add(0);
    while (v2Parts.length < v1Parts.length) v2Parts.add(0);
    
    for (int i = 0; i < v1Parts.length; i++) {
      if (v1Parts[i] != v2Parts[i]) {
        return v1Parts[i] - v2Parts[i];
      }
    }
    return 0;
  }
  
  /// Check if app update is required
  static bool isUpdateRequired(String currentVersion, String requiredVersion) {
    try {
      return compareVersions(currentVersion, requiredVersion) < 0;
    } catch (e) {
      // If version parsing fails, assume no update required
      return false;
    }
  }
  
  /// Format version info for display
  static String formatVersionInfo(String current, String required) {
    return 'Current: v$current → Required: v$required';
  }
}