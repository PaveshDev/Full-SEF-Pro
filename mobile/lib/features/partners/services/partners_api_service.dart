import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../models/partner_model.dart';

class PartnersApiService {
  final Dio _dio = ApiClient().dio;

  Future<List<Partner>> getPartners({
    String? route,
    String? categoryId,
    bool? activeOnly,
  }) async {
    final queryParams = <String, dynamic>{};
    if (route != null && route.isNotEmpty) queryParams['route'] = route;
    if (categoryId != null && categoryId.isNotEmpty) queryParams['categoryId'] = categoryId;
    if (activeOnly != null) queryParams['activeOnly'] = activeOnly;

    final response = await _dio.get('/partners', queryParameters: queryParams);
    final raw = response.data;
    final List data = raw is List ? raw : (raw is Map ? (raw['items'] as List? ?? []) : []);
    return data.map((json) => Partner.fromJson(Map<String, dynamic>.from(json as Map))).toList();
  }

  Future<List<PartnerMatch>> getMatches(String recoveryId) async {
    final response = await _dio.get('/recovery/$recoveryId/partners/matches');
    final raw = response.data;
    final List data = raw is List ? raw : (raw is Map ? (raw['items'] as List? ?? []) : []);
    return data.map((json) => PartnerMatch.fromJson(Map<String, dynamic>.from(json as Map))).toList();
  }

  Future<List<PartnerMatch>> matchPartners(String recoveryId) async {
    final response = await _dio.post('/recovery/$recoveryId/partners/match');
    final raw = response.data;
    final List data = raw is List ? raw : (raw is Map ? (raw['items'] as List? ?? []) : []);
    return data.map((json) => PartnerMatch.fromJson(Map<String, dynamic>.from(json as Map))).toList();
  }

  Future<Map<String, dynamic>> selectPartner(String recoveryId, String partnerId) async {
    final response = await _dio.post('/recovery/$recoveryId/partners/$partnerId/select');
    return response.data is Map ? Map<String, dynamic>.from(response.data) : {};
  }

  Future<List<Map<String, dynamic>>> getPartnerCollections() async {
    final response = await _dio.get('/partner/collections');
    final raw = response.data;
    final List data = raw is List ? raw : (raw is Map ? (raw['items'] as List? ?? []) : []);
    return data.map((json) => Map<String, dynamic>.from(json as Map)).toList();
  }

  Future<Map<String, dynamic>> confirmReceipt(
    String collectionId, {
    Uint8List? photoBytes,
    String? photoFileName,
    File? photo,
    String? feedback,
    bool conditionOk = true,
  }) async {
    final formData = FormData.fromMap({
      'feedback': feedback ?? '',
      'conditionOk': conditionOk.toString(),
    });

    if (photoBytes != null) {
      final name = photoFileName ?? 'intake_receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
      String subType = 'jpeg';
      if (name.toLowerCase().endsWith('.png')) {
        subType = 'png';
      } else if (name.toLowerCase().endsWith('.webp')) {
        subType = 'webp';
      }

      formData.files.add(MapEntry(
        'photo',
        MultipartFile.fromBytes(
          photoBytes,
          filename: name,
          contentType: DioMediaType('image', subType),
        ),
      ));
    } else if (photo != null) {
      final fileName = photo.path.split(RegExp(r'[\\/]')).last;
      formData.files.add(MapEntry(
        'photo',
        await MultipartFile.fromFile(photo.path, filename: fileName),
      ));
    }

    final response = await _dio.post(
      '/partner/collections/$collectionId/receive',
      data: formData,
    );
    return response.data as Map<String, dynamic>;
  }
}
