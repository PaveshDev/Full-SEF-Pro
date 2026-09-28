import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/api_client.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String phone;
  final String address;
  final String district;
  final String town;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
    this.address = '',
    this.district = '',
    this.town = '',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['userId'] ?? json['id'] ?? '',
      name: json['name'] ?? json['fullName'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'Customer',
      phone: json['phone'] ?? json['phoneNumber'] ?? '',
      address: json['address'] ?? '',
      district: json['district'] ?? '',
      town: json['town'] ?? '',
    );
  }
}

class AuthProvider extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Dio _dio = ApiClient().dio;

  UserModel? _user;
  String? _token;
  bool _isLoading = true;

  UserModel? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null && _user != null;

  AuthProvider() {
    init();
  }

  Future<void> init() async {
    try {
      _token = await _storage.read(key: 'jwt_token');
      if (_token != null) {
        await fetchProfile();
      } else {
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('AuthProvider.init storage read error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      final res = await _dio.post('/auth/login', data: {
        'email': email.trim(),
        'password': password,
      });

      _token = res.data['token'];
      await _storage.write(key: 'jwt_token', value: _token);

      _user = UserModel.fromJson(res.data);
      notifyListeners();
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String address,
    required String district,
    required String town,
  }) async {
    try {
      final res = await _dio.post('/auth/register', data: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'phone': phone.trim(),
        'address': address.trim(),
        'district': district.trim(),
        'town': town.trim(),
      });

      _token = res.data['token'];
      await _storage.write(key: 'jwt_token', value: _token);

      _user = UserModel.fromJson(res.data);
      notifyListeners();
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> fetchProfile() async {
    try {
      final res = await _dio.get('/auth/me');
      _user = UserModel.fromJson(res.data);
    } catch (_) {
      // Token might be expired
      await logout();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    String? name,
    String? phone,
    String? address,
    String? district,
    String? town,
  }) async {
    try {
      final res = await _dio.put('/auth/me', data: {
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (address != null) 'address': address,
        if (district != null) 'district': district,
        if (town != null) 'town': town,
      });

      _user = UserModel.fromJson(res.data);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    await _storage.delete(key: 'jwt_token');
    notifyListeners();
  }
}
