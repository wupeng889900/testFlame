import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from alibabacloud_aiccs20191015.client import Client as AiccsClient
from alibabacloud_aiccs20191015 import models as aiccs_models
from alibabacloud_tea_openapi import models as open_api_models
from alibabacloud_tea_util import models as util_models


HOST = "0.0.0.0"
PORT = 8080


def build_client(access_key_id: str, access_key_secret: str, security_token: str, endpoint: str) -> AiccsClient:
    config = open_api_models.Config(
        access_key_id=access_key_id,
        access_key_secret=access_key_secret,
    )
    if security_token:
        config.security_token = security_token
    config.endpoint = endpoint or "aiccs.aliyuncs.com"
    return AiccsClient(config)


def invoke_llm_smart_call(payload: dict) -> tuple[int, dict]:
    access_key_id = str(payload.get("accessKeyId", "")).strip()
    access_key_secret = str(payload.get("accessKeySecret", "")).strip()
    application_code = str(payload.get("applicationCode", "")).strip()
    security_token = str(payload.get("securityToken", "")).strip()
    caller_number = str(payload.get("callerNumber", "")).strip()
    called_number = str(payload.get("calledNumber", "")).strip()
    endpoint = str(payload.get("endpoint", "aiccs.aliyuncs.com")).strip() or "aiccs.aliyuncs.com"

    if not access_key_id or not access_key_secret or not caller_number or not called_number:
        return 400, {
            "code": "INVALID_ARGUMENT",
            "message": "accessKeyId, accessKeySecret, callerNumber, calledNumber are required",
        }

    client = build_client(access_key_id, access_key_secret, security_token, endpoint)
    request = aiccs_models.LlmSmartCallRequest(
        caller_number=caller_number,
        called_number=called_number,
    )
    if application_code:
        request.application_code = application_code

    try:
        response = client.llm_smart_call_with_options(request, util_models.RuntimeOptions())
        body = getattr(response, "body", None)
        return 200, {
            "requestId": getattr(body, "request_id", None),
            "code": getattr(body, "code", None),
            "message": getattr(body, "message", None),
            "callId": getattr(body, "call_id", None),
        }
    except Exception as error:
        data = getattr(error, "data", None) or {}
        return 500, {
            "code": getattr(error, "code", None) or data.get("Code") or "ALIYUN_CALL_FAILED",
            "message": getattr(error, "message", None) or str(error),
            "requestId": data.get("RequestId") or data.get("requestId"),
            "recommend": data.get("Recommend") or data.get("recommend"),
            "data": data,
        }


class Handler(BaseHTTPRequestHandler):
    def do_POST(self) -> None:
        if self.path != "/llmSmartCall":
            self._write_json(404, {"code": "NOT_FOUND", "message": "unknown path"})
            return

        try:
            content_length = int(self.headers.get("Content-Length", "0"))
            body = self.rfile.read(content_length).decode("utf-8") if content_length else "{}"
            payload = json.loads(body)
        except Exception as error:
            self._write_json(400, {"code": "BAD_REQUEST", "message": str(error)})
            return

        status_code, response = invoke_llm_smart_call(payload)
        self._write_json(status_code, response)

    def do_GET(self) -> None:
        if self.path == "/health":
            self._write_json(200, {"ok": True})
            return
        self._write_json(404, {"code": "NOT_FOUND", "message": "unknown path"})

    def log_message(self, format: str, *args) -> None:
        return

    def _write_json(self, status_code: int, payload: dict) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"aliyunPython server listening on http://{HOST}:{PORT}")
    server.serve_forever()
