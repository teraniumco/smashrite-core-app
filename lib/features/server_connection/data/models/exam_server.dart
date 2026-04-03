import 'package:equatable/equatable.dart';

/// Represents an exam server
class ExamServer extends Equatable {
  final String name;
  final String smashriteDomain;
  final int port;
  final int? signalStrength; // For auto-discovered servers
  final String? authCode; // 6-digit authentication code
  final String? requiredAppVersion; // 
  
  // Institution branding
  final String? institutionName;
  final String? institutionLogoUrl;

  const ExamServer({
    required this.name,
    required this.smashriteDomain,
    required this.port,
    this.signalStrength,
    this.authCode,
    this.requiredAppVersion,
    this.institutionName,
    this.institutionLogoUrl,
  });

  /// Full server URL
  String get url => 'https://$smashriteDomain/api/v1';

  /// Server display name with IP
  String get displayInfo => '$name ($smashriteDomain)';

  /// Copy with method
  ExamServer copyWith({
    String? name,
    String? smashriteDomain,
    int? port,
    int? signalStrength,
    String? authCode,
    String? requiredAppVersion,
    String? institutionName,
    String? institutionLogoUrl,
  }) {
    return ExamServer(
      name: name ?? this.name,
      smashriteDomain: smashriteDomain ?? this.smashriteDomain,
      port: port ?? this.port,
      signalStrength: signalStrength ?? this.signalStrength,
      authCode: authCode ?? this.authCode,
      requiredAppVersion: requiredAppVersion ?? this.requiredAppVersion,
      institutionName: institutionName ?? this.institutionName,
      institutionLogoUrl: institutionLogoUrl ?? this.institutionLogoUrl,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'smashriteDomain': smashriteDomain,
      'port': port,
      'signalStrength': signalStrength,
      'authCode': authCode,
      'requiredAppVersion': requiredAppVersion,
      'institutionName': institutionName,
      'institutionLogoUrl': institutionLogoUrl,
    };
  }

  /// Create from JSON
  factory ExamServer.fromJson(Map<String, dynamic> json) {
    return ExamServer(
      name: json['name'] as String,
      smashriteDomain: json['smashriteDomain'] as String,
      port: json['port'] as int,
      signalStrength: json['signalStrength'] as int?,
      authCode: json['authCode'] as String?,
      requiredAppVersion: json['requiredAppVersion'] as String?,
      institutionName: json['institutionName'] as String?,
      institutionLogoUrl: json['institutionLogoUrl'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        name,
        smashriteDomain,
        port,
        signalStrength,
        authCode,
        requiredAppVersion,
        institutionName,
        institutionLogoUrl,
      ];

  @override
  String toString() => 'ExamServer(name: $name, url: $url, institution: $institutionName)';
}