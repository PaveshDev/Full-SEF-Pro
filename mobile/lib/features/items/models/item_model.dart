class CategoryModel {
  final String id;
  final String code;
  final String name;

  CategoryModel({
    required this.id,
    required this.code,
    required this.name,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
    );
  }
}

class ItemImageModel {
  final String id;
  final String url;

  ItemImageModel({required this.id, required this.url});

  factory ItemImageModel.fromJson(Map<String, dynamic> json) {
    return ItemImageModel(
      id: json['id'] ?? '',
      url: json['url'] ?? json['imageUrl'] ?? '',
    );
  }
}

class EcoAssessmentModel {
  final String hazardLevel;
  final bool isHarmfulToEnvironment;
  final String environmentalAlert;
  final bool canBeDonated;
  final String? donationUnsuitabilityReason;
  final List<String> detectedHazards;       // backend field: detectedHazards
  final List<String> handlingPrecautions;   // backend field: handlingPrecautions
  final double estimatedCo2OffsetKg;
  final bool isEcoFriendly;
  final String summary;

  EcoAssessmentModel({
    required this.hazardLevel,
    required this.isHarmfulToEnvironment,
    required this.environmentalAlert,
    required this.canBeDonated,
    this.donationUnsuitabilityReason,
    this.detectedHazards = const [],
    this.handlingPrecautions = const [],
    this.estimatedCo2OffsetKg = 70.0,
    this.isEcoFriendly = true,
    this.summary = '',
  });

  factory EcoAssessmentModel.fromJson(Map<String, dynamic> json) {
    // Backend uses camelCase: detectedHazards, handlingPrecautions
    var rawHazards = json['detectedHazards'];
    var rawPrecautions = json['handlingPrecautions'];
    return EcoAssessmentModel(
      hazardLevel: json['hazardLevel'] ?? 'Low',
      isHarmfulToEnvironment: json['isHarmfulToEnvironment'] ?? false,
      environmentalAlert: json['environmentalAlert'] ?? '',
      canBeDonated: json['canBeDonated'] ?? true,
      donationUnsuitabilityReason: json['donationUnsuitabilityReason'],
      detectedHazards: rawHazards is List ? rawHazards.map((e) => e.toString()).toList() : [],
      handlingPrecautions: rawPrecautions is List ? rawPrecautions.map((e) => e.toString()).toList() : [],
      estimatedCo2OffsetKg: (json['estimatedCo2OffsetKg'] ?? 70.0).toDouble(),
      isEcoFriendly: json['isEcoFriendly'] ?? true,
      summary: json['summary'] ?? '',
    );
  }
}


class AiAssessmentModel {
  final bool isConsistent;
  final List<String> flaggedMismatches;
  final String recommendedRecoveryRoute;
  final double? estimatedRecoveryValue;
  final double confidenceScore;
  final String reasoning;
  final String? conditionLevel;
  final String? confidenceLevel;
  final String? inconsistencyType;
  final String? detectedCategory;

  AiAssessmentModel({
    required this.isConsistent,
    required this.flaggedMismatches,
    required this.recommendedRecoveryRoute,
    this.estimatedRecoveryValue,
    required this.confidenceScore,
    required this.reasoning,
    this.conditionLevel,
    this.confidenceLevel,
    this.inconsistencyType,
    this.detectedCategory,
  });

  factory AiAssessmentModel.fromJson(Map<String, dynamic> json) {
    var rawMismatches = json['flaggedMismatches'];
    List<String> mismatches = [];
    if (rawMismatches is List) {
      mismatches = rawMismatches.map((e) => e.toString()).toList();
    }

    return AiAssessmentModel(
      isConsistent: json['isConsistent'] ?? json['categoryConsistency'] ?? true,
      flaggedMismatches: mismatches,
      recommendedRecoveryRoute: json['recommendedRoute']?.toString() ??
          json['recommendedRecoveryRoute']?.toString() ??
          json['suggestedRoute']?.toString() ??
          'Recycle',
      estimatedRecoveryValue: json['estimatedRecoveryValue'] != null
          ? (json['estimatedRecoveryValue'] as num).toDouble()
          : null,
      confidenceScore: json['confidenceScore'] != null
          ? (json['confidenceScore'] as num).toDouble()
          : 0.9,
      reasoning: json['explanation']?.toString() ??
          json['reasoning']?.toString() ??
          json['summary']?.toString() ??
          '',
      conditionLevel: json['conditionLevel']?.toString() ?? json['estimatedCondition']?.toString(),
      confidenceLevel: json['confidenceLevel']?.toString(),
      inconsistencyType: json['inconsistencyType']?.toString(),
      detectedCategory: json['detectedCategory']?.toString(),
    );
  }
}

class ItemModel {
  final String id;
  final String name;
  final String? brand;
  final String? model;
  final String? conditionDescription;
  final String status;
  final String categoryId;
  final CategoryModel? category;
  final List<ItemImageModel> images;
  final AiAssessmentModel? assessment;
  final EcoAssessmentModel? ecoAssessment;
  final bool ecoHazardAcknowledged;
  final String? selectedRecoveryRoute;
  final DateTime? createdAt;

  ItemModel({
    required this.id,
    required this.name,
    this.brand,
    this.model,
    this.conditionDescription,
    required this.status,
    required this.categoryId,
    this.category,
    this.images = const [],
    this.assessment,
    this.ecoAssessment,
    this.ecoHazardAcknowledged = true,
    this.selectedRecoveryRoute,
    this.createdAt,
  });

  ItemModel copyWith({
    String? id,
    String? name,
    String? brand,
    String? model,
    String? conditionDescription,
    String? status,
    String? categoryId,
    CategoryModel? category,
    List<ItemImageModel>? images,
    AiAssessmentModel? assessment,
    EcoAssessmentModel? ecoAssessment,
    bool? ecoHazardAcknowledged,
    String? selectedRecoveryRoute,
    DateTime? createdAt,
  }) {
    return ItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      conditionDescription: conditionDescription ?? this.conditionDescription,
      status: status ?? this.status,
      categoryId: categoryId ?? this.categoryId,
      category: category ?? this.category,
      images: images ?? this.images,
      assessment: assessment ?? this.assessment,
      ecoAssessment: ecoAssessment ?? this.ecoAssessment,
      ecoHazardAcknowledged: ecoHazardAcknowledged ?? this.ecoHazardAcknowledged,
      selectedRecoveryRoute: selectedRecoveryRoute ?? this.selectedRecoveryRoute,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    List<ItemImageModel> imgList = [];
    if (json['images'] is List) {
      imgList = (json['images'] as List)
          .map((i) => i is Map
              ? ItemImageModel.fromJson(Map<String, dynamic>.from(i))
              : ItemImageModel(id: '', url: i.toString()))
          .toList();
    }

    EcoAssessmentModel? eco;
    if (json['ecoAssessment'] is Map) {
      eco = EcoAssessmentModel.fromJson(Map<String, dynamic>.from(json['ecoAssessment'] as Map));
    }

    CategoryModel? cat;
    if (json['category'] is Map) {
      cat = CategoryModel.fromJson(Map<String, dynamic>.from(json['category'] as Map));
    }

    AiAssessmentModel? ai;
    if (json['latestAssessment'] is Map) {
      ai = AiAssessmentModel.fromJson(Map<String, dynamic>.from(json['latestAssessment'] as Map));
    } else if (json['assessment'] is Map) {
      ai = AiAssessmentModel.fromJson(Map<String, dynamic>.from(json['assessment'] as Map));
    }

    return ItemModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      brand: json['brand']?.toString(),
      model: json['model']?.toString(),
      conditionDescription: json['conditionDescription']?.toString(),
      status: json['status']?.toString() ?? 'Draft',
      categoryId: json['categoryId']?.toString() ?? '',
      category: cat,
      images: imgList,
      assessment: ai,
      ecoAssessment: eco,
      ecoHazardAcknowledged: json['ecoHazardAcknowledged'] ?? true,
      selectedRecoveryRoute: json['selectedRecoveryRoute']?.toString(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }
}
