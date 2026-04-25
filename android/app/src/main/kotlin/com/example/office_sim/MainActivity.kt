package com.example.office_sim

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AliyunSmartCallBridge.CHANNEL)
            .setMethodCallHandler { call, result ->
                AliyunSmartCallBridge.handle(call, result, this)
            }
    }
}
