import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../models/item_model.dart';

class ItemsApiService {
  final Dio _dio = ApiClient().dio;

  Future<List<CategoryModel>> getCategories() async {
    final res = await _dio.get('/categories');
    final List list = res.data is List ? res.data : (res.data['items'] ?? []);
    return list.map((e) => CategoryModel.fromJson(e)).toList();
  }

  Future<List<ItemModel>> getItems({String? search, String? status}) async {
    final res = await _dio.get('/items', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null && status.isNotEmpty) 'status': status,
      'pageSize': 50,
    });

    final List list = res.data['items'] ?? [];
    return list.map((e) => ItemModel.fromJson(e)).toList();
  }

  Future<ItemModel> getItemById(String id) async {
    final res = await _dio.get('/items/$id');
    var item = ItemModel.fromJson(res.data);
    if (item.assessment == null && item.status != 'Draft') {
      try {
        final assess = await getItemAssessment(id);
        if (assess != null) {
          item = item.copyWith(assessment: assess);
        }
      } catch (_) {}
    }
    return item;
  }

  Future<ItemModel> createItem({
    required String name,
    required String brand,
    required String model,
    required String conditionDescription,
    required String categoryId,
  }) async {
    final res = await _dio.post('/items', data: {
      'name': name.trim(),
      'brand': brand.trim(),
      'model': model.trim(),
      'conditionDescription': conditionDescription.trim(),
      'categoryId': categoryId,
    });
    return ItemModel.fromJson(res.data);
  }

  Future<ItemModel> updateItem({
    required String id,
    required String name,
    required String brand,
    required String model,
    required String conditionDescription,
    required String categoryId,
  }) async {
    final res = await _dio.put('/items/$id', data: {
      'name': name.trim(),
      'brand': brand.trim(),
      'model': model.trim(),
      'conditionDescription': conditionDescription.trim(),
      'categoryId': categoryId,
    });
    return ItemModel.fromJson(res.data);
  }

  Future<void> uploadPhotoBytes(String itemId, List<int> bytes, String fileName) async {
    // Sanitize filename to ensure backend accepted extensions (.jpg, .jpeg, .png, .webp)
    String cleanName = fileName.trim();
    if (cleanName.isEmpty || cleanName.toLowerCase() == 'blob') {
      cleanName = 'item_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    }

    final lower = cleanName.toLowerCase();
    if (!lower.endsWith('.jpg') && !lower.endsWith('.jpeg') && !lower.endsWith('.png') && !lower.endsWith('.webp')) {
      if (bytes.length >= 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
        cleanName = '$cleanName.png';
      } else if (bytes.length >= 12 && bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) {
        cleanName = '$cleanName.webp';
      } else {
        cleanName = '$cleanName.jpg';
      }
    }

    String subType = 'jpeg';
    if (cleanName.toLowerCase().endsWith('.png')) {
      subType = 'png';
    } else if (cleanName.toLowerCase().endsWith('.webp')) {
      subType = 'webp';
    }

    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: cleanName,
        contentType: DioMediaType('image', subType),
      ),
    });

    await _dio.post(
      '/items/$itemId/photos',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<void> uploadPhoto(String itemId, dynamic imageFile) async {
    // Supports both XFile and dart:io File
    if (imageFile is List<int>) {
      await uploadPhotoBytes(itemId, imageFile, 'photo.jpg');
    } else {
      try {
        final bytes = await imageFile.readAsBytes();
        final name = imageFile.name ?? 'photo.jpg';
        await uploadPhotoBytes(itemId, bytes, name);
      } catch (_) {
        // Fallback for dart:io File
        final bytes = await (imageFile as dynamic).readAsBytes();
        final path = (imageFile as dynamic).path as String;
        final name = path.contains('/') ? path.split('/').last : path.split('\\').last;
        await uploadPhotoBytes(itemId, bytes, name);
      }
    }
  }

  // Submit item from Draft to Submitted
  Future<void> submitItem(String itemId) async {
    await _dio.post('/items/$itemId/submit');
  }

  // Select recovery route (Donate or Recycle)
  Future<void> selectRoute(String itemId, String route) async {
    await _dio.post('/items/$itemId/select-route', data: {
      'selectedRoute': route,
    });
  }

  // Eco-Agent Assessment
  Future<EcoAssessmentModel> triggerEcoAssessment(String itemId) async {
    final res = await _dio.post('/items/$itemId/eco-assessment');
    return EcoAssessmentModel.fromJson(res.data);
  }

  // Acknowledge environmental hazard precautions
  Future<void> acknowledgeEcoHazard(String itemId) async {
    await _dio.post('/items/$itemId/eco-acknowledge');
  }

  // Switch recovery route directly to Recycle
  Future<void> switchToRecycle(String itemId) async {
    await _dio.post('/items/$itemId/switch-to-recycle');
  }

  // Agent 1 Advisory Assessment
  Future<AiAssessmentModel> triggerAiAssessment(String itemId) async {
    final res = await _dio.post('/items/$itemId/assess');
    return AiAssessmentModel.fromJson(res.data);
  }

  // Get latest assessment for item
  Future<AiAssessmentModel?> getItemAssessment(String itemId) async {
    try {
      final res = await _dio.get('/items/$itemId/assessment');
      if (res.data is Map<String, dynamic>) {
        return AiAssessmentModel.fromJson(res.data);
      } else if (res.data is Map) {
        return AiAssessmentModel.fromJson(Map<String, dynamic>.from(res.data));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteItem(String itemId) async {
    await _dio.delete('/items/$itemId');
  }
}
