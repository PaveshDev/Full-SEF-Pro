import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../models/recovery_model.dart';

class RecoveryApiService {
  final Dio _dio = ApiClient().dio;

  Future<void> selectItemRoute(String itemId, String route) async {
    await _dio.post('/items/$itemId/select-route', data: {
      'selectedRoute': route,
    });
  }

  Future<RecoveryRequestModel> createRecoveryRequest(String itemId) async {
    try {
      final res = await _dio.post('/recovery', data: {
        'itemId': itemId,
      });
      return RecoveryRequestModel.fromJson(res.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        try {
          final listRes = await _dio.get('/recovery');
          final List list = listRes.data is List ? listRes.data : (listRes.data['items'] ?? []);
          var match = list.firstWhere(
            (r) {
              final rItemId = (r['itemId'] ?? r['ItemId'] ?? r['item']?['id'] ?? r['Item']?['Id'])?.toString().toLowerCase();
              return rItemId == itemId.toLowerCase();
            },
            orElse: () => null,
          );
          if (match == null) {
            final adminRes = await _dio.get('/admin/recovery');
            final List adminList = adminRes.data is List ? adminRes.data : (adminRes.data['items'] ?? []);
            match = adminList.firstWhere(
              (r) {
                final rItemId = (r['itemId'] ?? r['ItemId'] ?? r['item']?['id'] ?? r['Item']?['Id'])?.toString().toLowerCase();
                return rItemId == itemId.toLowerCase();
              },
              orElse: () => null,
            );
          }
          if (match != null) {
            return RecoveryRequestModel.fromJson(Map<String, dynamic>.from(match));
          }
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<List<RecoveryRequestModel>> getRecoveries({String? status}) async {
    final res = await _dio.get('/recovery', queryParameters: {
      if (status != null && status.isNotEmpty) 'status': status,
    });
    final List list = res.data is List ? res.data : (res.data['items'] ?? []);
    return list.map((e) => RecoveryRequestModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<RecoveryRequestModel> getRecoveryRequest(String recoveryId) async {
    if (recoveryId.trim().isEmpty) {
      throw Exception('Recovery ID cannot be empty');
    }
    final res = await _dio.get('/recovery/$recoveryId');
    return RecoveryRequestModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<RecoveryRequestModel> generateRecoveryPlan(String recoveryId) async {
    try {
      final res = await _dio.post('/recovery/$recoveryId/plan');
      return RecoveryRequestModel.fromJson(res.data);
    } catch (_) {
      final res = await _dio.post('/recovery/$recoveryId/generate-plan');
      return RecoveryRequestModel.fromJson(res.data);
    }
  }

  Future<Map<String, dynamic>?> toggleChecklistStep(String recoveryId, String stepId, bool isCompleted) async {
    final res = await _dio.patch('/recovery/$recoveryId/checklist', data: {
      'stepId': stepId,
      'isCompleted': isCompleted,
    });
    return res.data is Map ? Map<String, dynamic>.from(res.data) : null;
  }

  Future<void> submitForAdminApproval(String recoveryId) async {
    await _dio.post('/recovery/$recoveryId/submit');
  }

  Future<List<RecoveryRequestModel>> getPendingApprovals() async {
    final res = await _dio.get('/admin/recovery', queryParameters: {
      'status': 'PendingAdminApproval',
    });
    final List list = res.data is List ? res.data : (res.data['items'] ?? []);
    return list.map((e) => RecoveryRequestModel.fromJson(e)).toList();
  }

  Future<void> approvePlan(String recoveryId, {String? customHandlingInstructions, String? routeOverride}) async {
    await _dio.post('/admin/recovery/$recoveryId/approve', data: {
      if (customHandlingInstructions != null) 'customHandlingInstructions': customHandlingInstructions,
      if (routeOverride != null) 'routeOverride': routeOverride,
    });
  }

  Future<void> requestRevision(String recoveryId, String reason) async {
    await _dio.post('/admin/recovery/$recoveryId/request-revision', data: {
      'reason': reason,
    });
  }

  Future<void> rejectPlan(String recoveryId, String reason) async {
    await _dio.post('/admin/recovery/$recoveryId/reject', data: {
      'reason': reason,
    });
  }

  Future<void> submitDecision(String recoveryId, {
    required String decision,
    String? reason,
    String? customHandlingInstructions,
    String? routeOverride,
  }) async {
    await _dio.post('/admin/recovery/$recoveryId/decision', data: {
      'decision': decision,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      if (customHandlingInstructions != null && customHandlingInstructions.trim().isNotEmpty)
        'customHandlingInstructions': customHandlingInstructions.trim(),
      if (routeOverride != null && routeOverride.trim().isNotEmpty) 'routeOverride': routeOverride.trim(),
    });
  }
}
