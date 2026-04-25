import 'dart:io';
import 'package:dio/dio.dart';
import 'api_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  late Dio _dio;
  static const int maxRetries = 3;

  ApiClient({String? baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? '',
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add auth token if needed
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          final exception = _handleDioError(e);
          return handler.next(e.copyWith(error: exception));
        },
      ),
    );
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool useCache = true,
  }) async {
    if (useCache) {
      final cachedData = await _getCachedData(path, queryParameters);
      if (cachedData != null) {
        // Return mock response from cache if needed or just use as fallback
      }
    }

    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      if (e.error is ApiException) {
        throw e.error as ApiException;
      }
      throw ApiException(e.message ?? '网络请求失败');
    } catch (e) {
      throw ApiException(e.toString());
    }
  }

  ApiException _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException('连接超时，请检查网络');
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        if (status == 401) return AuthException('身份验证失败');
        if (status == 429) return RateLimitException('请求过于频繁，请稍后再试');
        return ServerException('服务器响应异常', status);
      case DioExceptionType.cancel:
        return ApiException('请求已取消');
      default:
        if (e.error is SocketException) return NetworkException('网络不可用');
        return ApiException('未知错误: ${e.message}');
    }
  }

  // Simple SharedPreferences based caching (Placeholder)
  Future<void> _saveToCache(String key, String data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, data);
  }

  Future<String?> _getCachedData(
    String path,
    Map<String, dynamic>? params,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$path${params?.toString()}');
  }
}
