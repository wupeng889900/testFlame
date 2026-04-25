package com.example.office_sim

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.aliyun.aiccs20191015.Client
import com.aliyun.aiccs20191015.models.LlmSmartCallRequest
import com.aliyun.tea.TeaException
import com.aliyun.tea.TeaModel
import com.aliyun.teaopenapi.models.Config
import com.aliyun.teautil.Common
import com.aliyun.teautil.models.RuntimeOptions
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

object AliyunSmartCallBridge {
    const val CHANNEL = "office_sim/aliyun_smart_call"
    private const val TAG = "AliyunSmartCall"
    private val mainHandler = Handler(Looper.getMainLooper())

    fun handle(call: MethodCall, result: MethodChannel.Result, activity: Activity) {
        when (call.method) {
            "llmSmartCallNative" -> invokeSmartCall(call, result)
            "openDialerNative" -> openDialer(call, result, activity)
            else -> result.notImplemented()
        }
    }

    private fun openDialer(call: MethodCall, result: MethodChannel.Result, activity: Activity) {
        val phoneNumber = call.argument<String>("phoneNumber").orEmpty().trim()
        if (phoneNumber.isEmpty()) {
            result.error("INVALID_ARGUMENT", "phoneNumber is required", null)
            return
        }

        try {
            val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phoneNumber"))
            activity.startActivity(intent)
            result.success(null)
        } catch (error: Exception) {
            Log.e(TAG, "openDialer failed", error)
            result.error("OPEN_DIALER_FAILED", error.message ?: "Failed to open dialer", null)
        }
    }

    private fun invokeSmartCall(call: MethodCall, result: MethodChannel.Result) {
        val accessKeyId = call.argument<String>("accessKeyId").orEmpty().trim()
        val accessKeySecret = call.argument<String>("accessKeySecret").orEmpty().trim()
        val applicationCode = call.argument<String>("applicationCode").orEmpty().trim()
        val securityToken = call.argument<String>("securityToken").orEmpty().trim()
        val callerNumber = call.argument<String>("callerNumber").orEmpty().trim()
        val calledNumber = call.argument<String>("calledNumber").orEmpty().trim()
        val endpoint = call.argument<String>("endpoint").orEmpty().trim().ifEmpty {
            "aiccs.aliyuncs.com"
        }

        if (accessKeyId.isEmpty() || accessKeySecret.isEmpty() || callerNumber.isEmpty() || calledNumber.isEmpty()) {
            result.error(
                "INVALID_ARGUMENT",
                "accessKeyId, accessKeySecret, callerNumber, calledNumber are required",
                null,
            )
            return
        }

        thread {
            try {
                val config = Config()
                    .setAccessKeyId(accessKeyId)
                    .setAccessKeySecret(accessKeySecret)

                if (securityToken.isNotEmpty()) {
                    config.setSecurityToken(securityToken)
                }
                config.endpoint = endpoint

                val client = Client(config)
                val request = LlmSmartCallRequest()
                    .setCallerNumber(callerNumber)
                    .setCalledNumber(calledNumber)

                if (applicationCode.isNotEmpty()) {
                    request.setApplicationCode(applicationCode)
                }

                val response = client.llmSmartCallWithOptions(request, RuntimeOptions())
                val body = response.body
                respondSuccess(
                    result,
                    hashMapOf(
                        "requestId" to body?.requestId,
                        "code" to body?.code,
                        "message" to body?.message,
                        "callId" to body?.callId,
                    ),
                )
            } catch (error: TeaException) {
                val dataMap = error.data?.let {
                    try {
                        @Suppress("UNCHECKED_CAST")
                        Common.assertAsMap(it) as Map<String, Any?>
                    } catch (_: Exception) {
                        mapOf("raw" to serializeTeaData(it))
                    }
                } ?: emptyMap()

                respondError(
                    "ALIYUN_TEA_EXCEPTION",
                    error.message ?: "Aliyun TeaException",
                    buildString {
                        append("message=")
                        append(error.message ?: "Aliyun TeaException")
                        if (dataMap.isNotEmpty()) {
                            append("\ndata=")
                            append(dataMap)
                        }
                    },
                    result,
                )
            } catch (error: Exception) {
                respondError(
                    "ALIYUN_CALL_FAILED",
                    error.message ?: "Aliyun call failed",
                    null,
                    result,
                )
            }
        }
    }

    private fun serializeTeaData(data: Any): Any {
        return when (data) {
            is TeaModel -> data.toMap()
            else -> data.toString()
        }
    }

    private fun respondSuccess(result: MethodChannel.Result, payload: HashMap<String, String?>) {
        mainHandler.post { result.success(payload) }
    }

    private fun respondError(
        code: String,
        message: String,
        details: String?,
        result: MethodChannel.Result,
    ) {
        mainHandler.post { result.error(code, message, details) }
    }
}
