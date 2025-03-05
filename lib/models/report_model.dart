class ReportModel {
  final String id;
  final String reportReason;
  final String reportedBy;
  final String reportedUser;
  final DateTime timestamp;

  ReportModel({
    required this.id,
    required this.reportReason,
    required this.reportedBy,
    required this.reportedUser,
    required this.timestamp,
  });

  factory ReportModel.fromMap(Map<String, dynamic> map) {
    return ReportModel(
      id: map['id'] ?? '',
      reportReason: map['reportReason'] ?? '',
      reportedBy: map['reportedBy'] ?? '',
      reportedUser: map['reportedUser'] ?? '',
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reportReason': reportReason,
      'reportedBy': reportedBy,
      'reportedUser': reportedUser,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
