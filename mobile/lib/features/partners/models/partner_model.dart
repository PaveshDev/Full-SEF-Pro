class PartnerService {
  final String recoveryRoute;
  final String categoryId;

  PartnerService({
    required this.recoveryRoute,
    required this.categoryId,
  });

  factory PartnerService.fromJson(Map<String, dynamic> json) {
    return PartnerService(
      recoveryRoute: json['recoveryRoute']?.toString() ?? '',
      categoryId: json['categoryId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'recoveryRoute': recoveryRoute,
    'categoryId': categoryId,
  };
}

class Partner {
  final String id;
  final String? userId;
  final String name;
  final String? contactName;
  final String email;
  final String? phone;
  final String? serviceArea;
  final String? operatingHours;
  final int averageProcessingDays;
  final bool isActive;
  final List<PartnerService> services;

  Partner({
    required this.id,
    this.userId,
    required this.name,
    this.contactName,
    required this.email,
    this.phone,
    this.serviceArea,
    this.operatingHours,
    required this.averageProcessingDays,
    required this.isActive,
    required this.services,
  });

  factory Partner.fromJson(Map<String, dynamic> json) {
    var rawServices = json['services'] as List? ?? [];
    return Partner(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString(),
      name: json['name']?.toString() ?? '',
      contactName: json['contactName']?.toString(),
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      serviceArea: json['serviceArea']?.toString(),
      operatingHours: json['operatingHours']?.toString(),
      averageProcessingDays: json['averageProcessingDays'] is int
          ? json['averageProcessingDays']
          : int.tryParse(json['averageProcessingDays']?.toString() ?? '1') ?? 1,
      isActive: json['isActive'] ?? true,
      services: rawServices.map((s) => PartnerService.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }
}

class PartnerMatch {
  final String id;
  final String partnerId;
  final String partnerName;
  final int rank;
  final String reason;
  final String? serviceArea;
  final int averageProcessingDays;

  PartnerMatch({
    required this.id,
    required this.partnerId,
    required this.partnerName,
    required this.rank,
    required this.reason,
    this.serviceArea,
    required this.averageProcessingDays,
  });

  factory PartnerMatch.fromJson(Map<String, dynamic> json) {
    return PartnerMatch(
      id: json['id']?.toString() ?? '',
      partnerId: json['partnerId']?.toString() ?? '',
      partnerName: json['partnerName']?.toString() ?? '',
      rank: json['rank'] is int ? json['rank'] : int.tryParse(json['rank']?.toString() ?? '1') ?? 1,
      reason: json['reason']?.toString() ?? '',
      serviceArea: json['serviceArea']?.toString(),
      averageProcessingDays: json['averageProcessingDays'] is int
          ? json['averageProcessingDays']
          : int.tryParse(json['averageProcessingDays']?.toString() ?? '1') ?? 1,
    );
  }
}
