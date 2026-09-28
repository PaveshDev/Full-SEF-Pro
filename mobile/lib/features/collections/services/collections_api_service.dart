import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../models/collection_model.dart';

class CollectionsApiService {
  final Dio _dio = ApiClient().dio;

  Future<CollectionRequest> createCollectionPreference(
    String recoveryId, {
    required DateTime pickupDate,
    required String startTime,
    required String endTime,
  }) async {
    final response = await _dio.post(
      '/recovery/$recoveryId/collections',
      data: {
        'preferredPickupDate': pickupDate.toUtc().toIso8601String(),
        'preferredStartTime': startTime,
        'preferredEndTime': endTime,
      },
    );
    return CollectionRequest.fromJson(response.data as Map<String, dynamic>);
  }

  Future<HandoverPass> getHandoverPass(String recoveryId) async {
    final response = await _dio.get('/recovery/$recoveryId/handover-pass');
    return HandoverPass.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<CollectionRequest>> getCustomerCollections() async {
    final response = await _dio.get('/collections');
    final raw = response.data;
    final List data = raw is List ? raw : (raw is Map ? (raw['items'] as List? ?? []) : []);
    return data.map((json) => CollectionRequest.fromJson(Map<String, dynamic>.from(json as Map))).toList();
  }

  Future<List<CollectionRequest>> getAgentJobs() async {
    final response = await _dio.get('/agent/collections');
    final raw = response.data;
    final List data = raw is List ? raw : (raw is Map ? (raw['items'] as List? ?? []) : []);
    return data.map((json) => CollectionRequest.fromJson(Map<String, dynamic>.from(json as Map))).toList();
  }

  Future<CollectionRequest> acceptJob(String id) async {
    final response = await _dio.post('/agent/collections/$id/accept');
    return CollectionRequest.fromJson(response.data as Map<String, dynamic>);
  }

  Future<CollectionRequest> rejectJob(String id, {String? reason}) async {
    final response = await _dio.post(
      '/agent/collections/$id/reject',
      data: {
        'reason': reason ?? 'Schedule conflict',
      },
    );
    return CollectionRequest.fromJson(response.data as Map<String, dynamic>);
  }

  Future<CollectionRequest> updateStatus(
    String id, {
    required String status,
    String? note,
  }) async {
    final response = await _dio.post(
      '/agent/collections/$id/status',
      data: {
        'status': status,
        'note': note,
      },
    );
    return CollectionRequest.fromJson(response.data as Map<String, dynamic>);
  }
}
