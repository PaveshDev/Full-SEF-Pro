class CollectionStatusHistory {
  final String status;
  final String? note;
  final DateTime changedAt;

  CollectionStatusHistory({
    required this.status,
    this.note,
    required this.changedAt,
  });

  factory CollectionStatusHistory.fromJson(Map<String, dynamic> json) {
    return CollectionStatusHistory(
      status: json['status']?.toString() ?? '',
      note: json['note']?.toString(),
      changedAt: json['changedAt'] != null
          ? DateTime.tryParse(json['changedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class CollectionRequest {
  final String id;
  final String recoveryRequestId;
  final String partnerId;
  final String partnerName;
  final String customerId;
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String? customerDistrict;
  final String? customerTown;
  final DateTime? preferredPickupDate;
  final String? preferredStartTime;
  final String? preferredEndTime;
  final DateTime? scheduledPickupDate;
  final String? scheduledStartTime;
  final String? scheduledEndTime;
  final String? assignedCollectionAgentId;
  final String? assignedAgentName;
  final String status;
  final String? partnerPhotoUrl;
  final String? partnerFeedback;
  final DateTime? partnerConfirmedAt;
  final bool? partnerReceivedConditionOk;
  final bool deliveryEmailSent;
  final DateTime? deliveryEmailSentAt;
  final String? deliveryEmailSubject;
  final Map<String, dynamic>? item;
  final List<CollectionStatusHistory> statusHistory;
  final DateTime createdAt;

  CollectionRequest({
    required this.id,
    required this.recoveryRequestId,
    required this.partnerId,
    required this.partnerName,
    required this.customerId,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.customerDistrict,
    this.customerTown,
    this.preferredPickupDate,
    this.preferredStartTime,
    this.preferredEndTime,
    this.scheduledPickupDate,
    this.scheduledStartTime,
    this.scheduledEndTime,
    this.assignedCollectionAgentId,
    this.assignedAgentName,
    required this.status,
    this.partnerPhotoUrl,
    this.partnerFeedback,
    this.partnerConfirmedAt,
    this.partnerReceivedConditionOk,
    required this.deliveryEmailSent,
    this.deliveryEmailSentAt,
    this.deliveryEmailSubject,
    this.item,
    required this.statusHistory,
    required this.createdAt,
  });

  factory CollectionRequest.fromJson(Map<String, dynamic> json) {
    var rawHistory = json['statusHistory'] as List? ?? [];
    return CollectionRequest(
      id: json['id']?.toString() ?? '',
      recoveryRequestId: json['recoveryRequestId']?.toString() ?? '',
      partnerId: json['partnerId']?.toString() ?? '',
      partnerName: json['partnerName']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? '',
      customerName: json['customerName']?.toString(),
      customerPhone: json['customerPhone']?.toString(),
      customerAddress: json['customerAddress']?.toString(),
      customerDistrict: json['customerDistrict']?.toString(),
      customerTown: json['customerTown']?.toString(),
      preferredPickupDate: json['preferredPickupDate'] != null
          ? DateTime.tryParse(json['preferredPickupDate'].toString())
          : null,
      preferredStartTime: json['preferredStartTime']?.toString(),
      preferredEndTime: json['preferredEndTime']?.toString(),
      scheduledPickupDate: json['scheduledPickupDate'] != null
          ? DateTime.tryParse(json['scheduledPickupDate'].toString())
          : null,
      scheduledStartTime: json['scheduledStartTime']?.toString(),
      scheduledEndTime: json['scheduledEndTime']?.toString(),
      assignedCollectionAgentId: json['assignedCollectionAgentId']?.toString(),
      assignedAgentName: json['assignedAgentName']?.toString(),
      status: json['status']?.toString() ?? 'Requested',
      partnerPhotoUrl: json['partnerPhotoUrl']?.toString(),
      partnerFeedback: json['partnerFeedback']?.toString(),
      partnerConfirmedAt: json['partnerConfirmedAt'] != null
          ? DateTime.tryParse(json['partnerConfirmedAt'].toString())
          : null,
      partnerReceivedConditionOk: json['partnerReceivedConditionOk'],
      deliveryEmailSent: json['deliveryEmailSent'] ?? false,
      deliveryEmailSentAt: json['deliveryEmailSentAt'] != null
          ? DateTime.tryParse(json['deliveryEmailSentAt'].toString())
          : null,
      deliveryEmailSubject: json['deliveryEmailSubject']?.toString(),
      item: json['item'] as Map<String, dynamic>?,
      statusHistory: rawHistory.map((h) => CollectionStatusHistory.fromJson(h as Map<String, dynamic>)).toList(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class HandoverPass {
  final String recoveryRequestId;
  final String passReferenceCode;
  final String itemId;
  final String itemName;
  final String categoryName;
  final String? brand;
  final String? model;
  final String? conditionDescription;
  final String? primaryImageUrl;
  final String selectedRoute;
  final String status;
  final String customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String? customerDistrict;
  final String? customerTown;
  final String? planSummary;
  final String? requiredPartnerType;
  final List<String> preparationSteps;
  final List<String> safetyNotes;
  final bool isApproved;
  final DateTime? approvedAt;
  final String? adminNote;
  final bool isPreparationVerified;
  final String? adminHandlingInstructions;
  final String? ecoHazardLevel;
  final String? collectionRequestId;
  final String? collectionStatus;
  final String? assignedAgentId;
  final String? assignedAgentName;
  final String? partnerName;
  final DateTime? scheduledPickupDate;
  final String? scheduledStartTime;
  final String? scheduledEndTime;

  HandoverPass({
    required this.recoveryRequestId,
    required this.passReferenceCode,
    required this.itemId,
    required this.itemName,
    required this.categoryName,
    this.brand,
    this.model,
    this.conditionDescription,
    this.primaryImageUrl,
    required this.selectedRoute,
    required this.status,
    required this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.customerDistrict,
    this.customerTown,
    this.planSummary,
    this.requiredPartnerType,
    required this.preparationSteps,
    required this.safetyNotes,
    required this.isApproved,
    this.approvedAt,
    this.adminNote,
    required this.isPreparationVerified,
    this.adminHandlingInstructions,
    this.ecoHazardLevel,
    this.collectionRequestId,
    this.collectionStatus,
    this.assignedAgentId,
    this.assignedAgentName,
    this.partnerName,
    this.scheduledPickupDate,
    this.scheduledStartTime,
    this.scheduledEndTime,
  });

  factory HandoverPass.fromJson(Map<String, dynamic> json) {
    var rawPrep = json['preparationSteps'] as List? ?? [];
    var rawSafety = json['safetyNotes'] as List? ?? [];

    return HandoverPass(
      recoveryRequestId: json['recoveryRequestId']?.toString() ?? '',
      passReferenceCode: json['passReferenceCode']?.toString() ?? '',
      itemId: json['itemId']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      categoryName: json['categoryName']?.toString() ?? '',
      brand: json['brand']?.toString(),
      model: json['model']?.toString(),
      conditionDescription: json['conditionDescription']?.toString(),
      primaryImageUrl: json['primaryImageUrl']?.toString(),
      selectedRoute: json['selectedRoute']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? 'Customer',
      customerPhone: json['customerPhone']?.toString(),
      customerAddress: json['customerAddress']?.toString(),
      customerDistrict: json['customerDistrict']?.toString(),
      customerTown: json['customerTown']?.toString(),
      planSummary: json['planSummary']?.toString(),
      requiredPartnerType: json['requiredPartnerType']?.toString(),
      preparationSteps: rawPrep.map((e) => e.toString()).toList(),
      safetyNotes: rawSafety.map((e) => e.toString()).toList(),
      isApproved: json['isApproved'] ?? false,
      approvedAt: json['approvedAt'] != null ? DateTime.tryParse(json['approvedAt'].toString()) : null,
      adminNote: json['adminNote']?.toString(),
      isPreparationVerified: json['isPreparationVerified'] ?? false,
      adminHandlingInstructions: json['adminHandlingInstructions']?.toString(),
      ecoHazardLevel: json['ecoHazardLevel']?.toString(),
      collectionRequestId: json['collectionRequestId']?.toString(),
      collectionStatus: json['collectionStatus']?.toString(),
      assignedAgentId: json['assignedAgentId']?.toString(),
      assignedAgentName: json['assignedAgentName']?.toString(),
      partnerName: json['partnerName']?.toString(),
      scheduledPickupDate: json['scheduledPickupDate'] != null
          ? DateTime.tryParse(json['scheduledPickupDate'].toString())
          : null,
      scheduledStartTime: json['scheduledStartTime']?.toString(),
      scheduledEndTime: json['scheduledEndTime']?.toString(),
    );
  }
}
