import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class AliyunSmartCallService {
  static const MethodChannel _channel = MethodChannel('office_sim/aliyun_smart_call');

  Future<Map<String, dynamic>> llmSmartCall({
    required String accessKeyId,
    required String accessKeySecret,
    required String callerNumber,
    required String calledNumber,
    String applicationCode = '',
    String securityToken = '',
    String endpoint = 'aiccs.aliyuncs.com',
  }) async {
    final normalizedEndpoint = endpoint.trim().isEmpty ? 'aiccs.aliyuncs.com' : endpoint.trim();
    final timestamp = DateTime.now().toUtc().toIso8601String().replaceFirst(RegExp(r'\.\d{3}Z$'), 'Z');
    final queryParameters = <String, String>{
      'AccessKeyId': accessKeyId.trim(),
      'Action': 'LlmSmartCall',
      'ApplicationCode': applicationCode.trim(),
      'CalledNumber': calledNumber.trim(),
      'CallerNumber': callerNumber.trim(),
      'Format': 'JSON',
      'SignatureMethod': 'HMAC-SHA1',
      'SignatureNonce': _generateNonce(),
      'SignatureVersion': '1.0',
      'Timestamp': timestamp,
      'Version': '2019-10-15',
    };

    if (securityToken.trim().isNotEmpty) {
      queryParameters['SecurityToken'] = securityToken.trim();
    }

    if (queryParameters['AccessKeyId']!.isEmpty ||
        queryParameters['CallerNumber']!.isEmpty ||
        queryParameters['CalledNumber']!.isEmpty) {
      throw Exception('accessKeyId, callerNumber, calledNumber are required');
    }

    if (accessKeySecret.trim().isEmpty) {
      throw Exception('accessKeySecret is required');
    }

    if (queryParameters['ApplicationCode']!.isEmpty) {
      queryParameters.remove('ApplicationCode');
    }

    final sortedEntries =
        queryParameters.entries.toList()..sort((left, right) => left.key.compareTo(right.key));
    final canonicalizedQuery = sortedEntries
        .map((entry) => '${_percentEncode(entry.key)}=${_percentEncode(entry.value)}')
        .join('&');
    final stringToSign = 'GET&${_percentEncode('/')}&${_percentEncode(canonicalizedQuery)}';
    final signature = base64Encode(
      Hmac(sha1, utf8.encode('${accessKeySecret.trim()}&')).convert(utf8.encode(stringToSign)).bytes,
    );

    final uri = Uri.https(normalizedEndpoint, '/', <String, String>{
      ...queryParameters,
      'Signature': signature,
    });

    final response = await http.get(uri, headers: const <String, String>{'Accept': 'application/json'}).timeout(
          const Duration(seconds: 30),
        );

    final responseBody = response.body.isEmpty ? '{}' : response.body;
    dynamic decoded;
    try {
      decoded = jsonDecode(responseBody);
    } catch (_) {
      decoded = <String, dynamic>{
        'raw': responseBody,
        'statusCode': response.statusCode,
      };
    }
    final responseMap = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'raw': responseBody, 'statusCode': response.statusCode};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: $responseMap');
    }

    return <String, dynamic>{
      'source': 'flutter_direct',
      'requestId': responseMap['RequestId'] ?? responseMap['requestId'],
      'code': responseMap['Code'] ?? responseMap['code'],
      'message': responseMap['Message'] ?? responseMap['message'],
      'callId': responseMap['CallId'] ?? responseMap['callId'] ?? responseMap['Data']?['CallId'],
      'raw': responseMap,
    };
  }

  Future<Map<String, dynamic>> llmSmartCallNative({
    required String accessKeyId,
    required String accessKeySecret,
    required String callerNumber,
    required String calledNumber,
    String applicationCode = '',
    String securityToken = '',
    String endpoint = 'aiccs.aliyuncs.com',
  }) async {
    final response = await _channel.invokeMapMethod<String, dynamic>('llmSmartCallNative', <String, dynamic>{
      'accessKeyId': accessKeyId.trim(),
      'accessKeySecret': accessKeySecret.trim(),
      'applicationCode': applicationCode.trim(),
      'securityToken': securityToken.trim(),
      'callerNumber': callerNumber.trim(),
      'calledNumber': calledNumber.trim(),
      'endpoint': endpoint.trim(),
    });

    return <String, dynamic>{
      'source': 'android_native',
      ...?response,
    };
  }

  Future<Map<String, dynamic>> llmSmartCallViaServer({
    required String accessKeyId,
    required String accessKeySecret,
    required String callerNumber,
    required String calledNumber,
    String applicationCode = '',
    String securityToken = '',
    String endpoint = 'aiccs.aliyuncs.com',
    String? serverBaseUrl,
  }) async {
    final normalizedBaseUrl = _normalizeServerBaseUrl(serverBaseUrl);
    final uri = Uri.parse('$normalizedBaseUrl/llmSmartCall');
    final response = await http
        .post(
          uri,
          headers: const <String, String>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, String>{
            'accessKeyId': accessKeyId.trim(),
            'accessKeySecret': accessKeySecret.trim(),
            'applicationCode': applicationCode.trim(),
            'securityToken': securityToken.trim(),
            'callerNumber': callerNumber.trim(),
            'calledNumber': calledNumber.trim(),
            'endpoint': endpoint.trim(),
          }),
        )
        .timeout(const Duration(seconds: 30));

    final responseBody = response.body.isEmpty ? '{}' : response.body;
    final decoded = jsonDecode(responseBody);
    final responseMap = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'raw': responseBody, 'statusCode': response.statusCode};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: $responseMap');
    }

    return <String, dynamic>{
      'source': 'python_server',
      'serverBaseUrl': normalizedBaseUrl,
      ...responseMap,
    };
  }

  Future<void> openDialer({required String phoneNumber}) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw Exception('无法打开系统拨号盘');
    }
  }

  Future<void> openDialerNative({required String phoneNumber}) async {
    await _channel.invokeMethod<void>('openDialerNative', <String, dynamic>{
      'phoneNumber': phoneNumber.trim(),
    });
  }

  String _generateNonce() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List<String>.generate(32, (_) => alphabet[random.nextInt(alphabet.length)]).join();
  }

  String _percentEncode(String value) {
    return Uri.encodeQueryComponent(value)
        .replaceAll('+', '%20')
        .replaceAll('*', '%2A')
        .replaceAll('%7E', '~');
  }

  String _normalizeServerBaseUrl(String? serverBaseUrl) {
    final trimmed = serverBaseUrl?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
    }
    if (kIsWeb) {
      return 'http://127.0.0.1:8080';
    }
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8080'
        : 'http://127.0.0.1:8080';
  }
}
