import 'package:equatable/equatable.dart';

/// Represents an exam server
class ExamServer extends Equatable {
  final String name;
  final String ipAddress;
  final int port;
  final int? signalStrength; // For auto-discovered servers
  final String? authCode; // 6-digit authentication code
  
  // Institution branding
  final String? institutionName;
  final String? institutionLogoUrl;
  final String? primaryColor;
  final String? secondaryColor;

  const ExamServer({
    required this.name,
    required this.ipAddress,
    required this.port,
    this.signalStrength,
    this.authCode,
    this.institutionName,
    this.institutionLogoUrl,
    this.primaryColor,
    this.secondaryColor,
  });

  /// Full server URL
  String get url => 'http://$ipAddress:$port/smashrite/public/api/v1';

  /// Server display name with IP
  String get displayInfo => '$name ($ipAddress)';

  /// Copy with method
  ExamServer copyWith({
    String? name,
    String? ipAddress,
    int? port,
    int? signalStrength,
    String? authCode,
    String? institutionName,
    String? institutionLogoUrl,
    String? primaryColor,
    String? secondaryColor,
  }) {
    return ExamServer(
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      signalStrength: signalStrength ?? this.signalStrength,
      authCode: authCode ?? this.authCode,
      institutionName: institutionName ?? this.institutionName,
      institutionLogoUrl: institutionLogoUrl ?? this.institutionLogoUrl,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'ipAddress': ipAddress,
      'port': port,
      'signalStrength': signalStrength,
      'authCode': authCode,
      'institutionName': institutionName,
      'institutionLogoUrl': institutionLogoUrl,
      'primaryColor': primaryColor,
      'secondaryColor': secondaryColor,
    };
  }

  /// Create from JSON
  factory ExamServer.fromJson(Map<String, dynamic> json) {
    return ExamServer(
      name: json['name'] as String,
      ipAddress: json['ipAddress'] as String,
      port: json['port'] as int,
      signalStrength: json['signalStrength'] as int?,
      authCode: json['authCode'] as String?,
      institutionName: json['institutionName'] as String?,
      institutionLogoUrl: json['institutionLogoUrl'] as String?,
      primaryColor: json['primaryColor'] as String?,
      secondaryColor: json['secondaryColor'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        name,
        ipAddress,
        port,
        signalStrength,
        authCode,
        institutionName,
        institutionLogoUrl,
        primaryColor,
        secondaryColor,
      ];

  @override
  String toString() => 'ExamServer(name: $name, url: $url, institution: $institutionName)';
}