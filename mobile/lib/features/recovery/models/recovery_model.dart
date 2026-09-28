import 'dart:convert';
import '../../items/models/item_model.dart';

class RecoveryStepModel {
  final String stepText;
  final int sortOrder;

  RecoveryStepModel({required this.stepText, required this.sortOrder});

  factory RecoveryStepModel.fromJson(Map<String, dynamic> json) {
    return RecoveryStepModel(
      stepText: json['stepText'] ?? json['text'] ?? '',
      sortOrder: json['sortOrder'] ?? 0,
    );
  }
}

class RecoverySafetyNoteModel {
  final String noteText;
  final int sortOrder;

  RecoverySafetyNoteModel({required this.noteText, required this.sortOrder});

  factory RecoverySafetyNoteModel.fromJson(Map<String, dynamic> json) {
    return RecoverySafetyNoteModel(
      noteText: json['noteText'] ?? json['text'] ?? '',
      sortOrder: json['sortOrder'] ?? 0,
    );
  }
}

class PreCollectionChecklistItem {
  final String id;
  final String title;
  final String description;
  final bool isMandatory;
  bool isCompleted;

  PreCollectionChecklistItem({
    required this.id,
    required this.title,
    required this.description,
    required this.isMandatory,
    required this.isCompleted,
  });

  factory PreCollectionChecklistItem.fromJson(Map<String, dynamic> json) {
    return PreCollectionChecklistItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      isMandatory: json['isMandatory'] == true || json['isMandatory'] == 1,
      isCompleted: json['isCompleted'] == true || json['isCompleted'] == 1,
    );
  }
}

class RecoveryPlanModel {
  final String suitability;
  final String summary;
  final String requiredPartnerType;
  bool isPreparationVerified;
  final String? adminHandlingInstructions;
  final List<RecoveryStepModel> steps;
  final List<RecoverySafetyNoteModel> safetyNotes;
  final List<PreCollectionChecklistItem> checklist;

  RecoveryPlanModel({
    required this.suitability,
    required this.summary,
    required this.requiredPartnerType,
    this.isPreparationVerified = false,
    this.adminHandlingInstructions,
    this.steps = const [],
    this.safetyNotes = const [],
    this.checklist = const [],
  });

  factory RecoveryPlanModel.fromJson(Map<String, dynamic> json) {
    List<RecoveryStepModel> stepList = [];
    if (json['steps'] is List) {
      stepList = (json['steps'] as List).map((s) {
        if (s is String) return RecoveryStepModel(stepText: s, sortOrder: 0);
        if (s is Map<String, dynamic>) return RecoveryStepModel.fromJson(s);
        if (s is Map) return RecoveryStepModel.fromJson(Map<String, dynamic>.from(s));
        return RecoveryStepModel(stepText: s?.toString() ?? '', sortOrder: 0);
      }).toList();
    }

    List<RecoverySafetyNoteModel> noteList = [];
    if (json['safetyNotes'] is List) {
      noteList = (json['safetyNotes'] as List).map((n) {
        if (n is String) return RecoverySafetyNoteModel(noteText: n, sortOrder: 0);
        if (n is Map<String, dynamic>) return RecoverySafetyNoteModel.fromJson(n);
        if (n is Map) return RecoverySafetyNoteModel.fromJson(Map<String, dynamic>.from(n));
        return RecoverySafetyNoteModel(noteText: n?.toString() ?? '', sortOrder: 0);
      }).toList();
    }

    List<PreCollectionChecklistItem> checkList = [];
    if (json['checklist'] is List) {
      checkList = (json['checklist'] as List).map((c) {
        if (c is Map<String, dynamic>) return PreCollectionChecklistItem.fromJson(c);
        if (c is Map) return PreCollectionChecklistItem.fromJson(Map<String, dynamic>.from(c));
        return PreCollectionChecklistItem(id: '', title: c.toString(), description: '', isMandatory: false, isCompleted: false);
      }).toList();
    } else if (json['checklistJson'] != null) {
      try {
        final decoded = jsonDecode(json['checklistJson']);
        if (decoded is List) {
          checkList = decoded.map((c) {
            if (c is Map<String, dynamic>) return PreCollectionChecklistItem.fromJson(c);
            if (c is Map) return PreCollectionChecklistItem.fromJson(Map<String, dynamic>.from(c));
            return PreCollectionChecklistItem(id: '', title: c.toString(), description: '', isMandatory: false, isCompleted: false);
          }).toList();
        }
      } catch (_) {}
    }

    return RecoveryPlanModel(
      suitability: json['suitability'] ?? 'Feasible',
      summary: json['summary'] ?? '',
      requiredPartnerType: json['requiredPartnerType'] ?? 'Recycler',
      isPreparationVerified: json['isPreparationVerified'] == true,
      adminHandlingInstructions: json['adminHandlingInstructions']?.toString(),
      steps: stepList,
      safetyNotes: noteList,
      checklist: checkList,
    );
  }
}

class RecoveryRequestModel {
  final String id;
  final String itemId;
  final String customerId;
  final String selectedRoute;
  final String status;
  final RecoveryPlanModel? plan;
  final ItemModel? item;
  final DateTime? createdAt;

  RecoveryRequestModel({
    required this.id,
    required this.itemId,
    required this.customerId,
    required this.selectedRoute,
    required this.status,
    this.plan,
    this.item,
    this.createdAt,
  });

  RecoveryRequestModel copyWithPlan(RecoveryPlanModel newPlan) {
    return RecoveryRequestModel(
      id: id,
      itemId: itemId,
      customerId: customerId,
      selectedRoute: selectedRoute,
      status: status,
      plan: newPlan,
      item: item,
      createdAt: createdAt,
    );
  }

  factory RecoveryRequestModel.fromJson(Map<String, dynamic> json) {
    return RecoveryRequestModel(
      id: json['id']?.toString() ?? '',
      itemId: json['itemId']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? '',
      selectedRoute: json['selectedRoute']?.toString() ?? 'Recycle',
      status: json['status']?.toString() ?? 'Draft',
      plan: json['plan'] != null && json['plan'] is Map
          ? RecoveryPlanModel.fromJson(Map<String, dynamic>.from(json['plan'] as Map))
          : null,
      item: json['item'] != null && json['item'] is Map
          ? ItemModel.fromJson(Map<String, dynamic>.from(json['item'] as Map))
          : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }
}
