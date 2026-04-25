import 'package:flutter/material.dart';

import 'aliyun_smart_call_defaults.dart';
import 'aliyun_smart_call_service.dart';

class AliyunSmartCallDemoPage extends StatefulWidget {
  const AliyunSmartCallDemoPage({super.key});

  @override
  State<AliyunSmartCallDemoPage> createState() => _AliyunSmartCallDemoPageState();
}

class _AliyunSmartCallDemoPageState extends State<AliyunSmartCallDemoPage> {
  final _service = AliyunSmartCallService();
  final _formKey = GlobalKey<FormState>();
  final _accessKeyIdController = TextEditingController(text: AliyunSmartCallDefaults.accessKeyId);
  final _accessKeySecretController = TextEditingController(text: AliyunSmartCallDefaults.accessKeySecret);
  final _applicationCodeController = TextEditingController(text: AliyunSmartCallDefaults.applicationCode);
  final _securityTokenController = TextEditingController(text: AliyunSmartCallDefaults.securityToken);
  final _callerNumberController = TextEditingController(text: AliyunSmartCallDefaults.callerNumber);
  final _calledNumberController = TextEditingController(text: AliyunSmartCallDefaults.calledNumber);
  final _endpointController = TextEditingController(text: AliyunSmartCallDefaults.endpoint);
  final _serverBaseUrlController = TextEditingController();

  bool _submitting = false;
  String _resultText = '尚未调用';

  @override
  void dispose() {
    _accessKeyIdController.dispose();
    _accessKeySecretController.dispose();
    _applicationCodeController.dispose();
    _securityTokenController.dispose();
    _callerNumberController.dispose();
    _calledNumberController.dispose();
    _endpointController.dispose();
    _serverBaseUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await _submitWith(mode: _CallMode.flutterDirect);
  }

  Future<void> _submitNative() async {
    await _submitWith(mode: _CallMode.androidNative);
  }

  Future<void> _submitViaServer() async {
    await _submitWith(mode: _CallMode.pythonServer);
  }

  Future<void> _submitWith({required _CallMode mode}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
      _resultText =
          switch (mode) {
            _CallMode.flutterDirect => 'Flutter 直连调用中...',
            _CallMode.androidNative => 'Android 原生调用中...',
            _CallMode.pythonServer => '本地 Python 服务调用中...',
          };
    });

    try {
      final response =
          mode == _CallMode.flutterDirect
              ? await _service.llmSmartCall(
                accessKeyId: _accessKeyIdController.text.trim(),
                accessKeySecret: _accessKeySecretController.text.trim(),
                applicationCode: _applicationCodeController.text.trim(),
                securityToken: _securityTokenController.text.trim(),
                callerNumber: _callerNumberController.text.trim(),
                calledNumber: _calledNumberController.text.trim(),
                endpoint: _endpointController.text.trim(),
              )
              : mode == _CallMode.androidNative
              ? await _service.llmSmartCallNative(
                accessKeyId: _accessKeyIdController.text.trim(),
                accessKeySecret: _accessKeySecretController.text.trim(),
                applicationCode: _applicationCodeController.text.trim(),
                securityToken: _securityTokenController.text.trim(),
                callerNumber: _callerNumberController.text.trim(),
                calledNumber: _calledNumberController.text.trim(),
                endpoint: _endpointController.text.trim(),
              )
              : await _service.llmSmartCallViaServer(
                accessKeyId: _accessKeyIdController.text.trim(),
                accessKeySecret: _accessKeySecretController.text.trim(),
                applicationCode: _applicationCodeController.text.trim(),
                securityToken: _securityTokenController.text.trim(),
                callerNumber: _callerNumberController.text.trim(),
                calledNumber: _calledNumberController.text.trim(),
                endpoint: _endpointController.text.trim(),
                serverBaseUrl: _serverBaseUrlController.text.trim(),
              );

      setState(() {
        _resultText = response.entries.map((entry) => '${entry.key}: ${entry.value}').join('\n');
      });
    } catch (error) {
      setState(() {
        _resultText = '调用失败\n$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _openDialer() async {
    final phoneNumber = _calledNumberController.text.trim();
    if (phoneNumber.isEmpty) {
      setState(() {
        _resultText = '打开拨号盘失败\n请先填写被叫号码';
      });
      return;
    }

    try {
      await _service.openDialer(phoneNumber: phoneNumber);
      setState(() {
        _resultText = '已打开系统拨号盘\nphoneNumber: $phoneNumber';
      });
    } catch (error) {
      setState(() {
        _resultText = '打开拨号盘失败\n$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('阿里云智能外呼 Demo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
          children: [
          const Text('当前支持三套外呼实现：Flutter 直连阿里云 OpenAPI、Android 原生 SDK 调用，以及通过本地 aliyunPython 服务转发调用。正式环境不应把 AK/SK 直接放在客户端里。'),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              children: [
                _buildField(controller: _accessKeyIdController, label: 'AccessKey ID'),
                const SizedBox(height: 12),
                _buildField(controller: _accessKeySecretController, label: 'AccessKey Secret', obscureText: true),
                const SizedBox(height: 12),
                _buildField(controller: _applicationCodeController, label: 'ApplicationCode', isRequired: false),
                const SizedBox(height: 12),
                _buildField(controller: _securityTokenController, label: 'Security Token', isRequired: false),
                const SizedBox(height: 12),
                _buildField(controller: _callerNumberController, label: '主叫号码'),
                const SizedBox(height: 12),
                _buildField(controller: _calledNumberController, label: '被叫号码'),
                const SizedBox(height: 12),
                _buildField(controller: _endpointController, label: 'Endpoint'),
                const SizedBox(height: 12),
                _buildField(controller: _serverBaseUrlController, label: 'Python 服务地址', isRequired: false),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: Text(_submitting ? '调用中...' : 'Flutter 直连阿里云'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting ? null : _submitNative,
                        child: const Text('Android 原生 SDK'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: _submitting ? null : _submitViaServer,
                    child: const Text('调用本地 Python 服务'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _submitting ? null : _openDialer,
                    child: const Text('打开拨号盘'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('返回结果', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
            child: SelectableText(_resultText, style: const TextStyle(color: Colors.white, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    bool isRequired = true,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      validator: (value) {
        if (!isRequired) {
          return null;
        }
        if (value == null || value.trim().isEmpty) {
          return '请填写$label';
        }
        return null;
      },
    );
  }
}

enum _CallMode {
  flutterDirect,
  androidNative,
  pythonServer,
}
