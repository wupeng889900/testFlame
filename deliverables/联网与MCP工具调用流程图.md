# 联网与 MCP 工具调用流程图

```mermaid
flowchart TD
    A[外部实时服务 / WebSocket Server] --> B[RemoteSyncController]
    B -->|JSON 消息| C[McpToolAdapter]
    C -->|RemoteCommand| D[OfficeGame._handleRemoteCommand]
    D --> E[AIController.forceTask]
    E --> F[Character.moveTo / startTask]
    F --> G[状态更新与动画切换]
    G --> H[OfficeHUD / StatusBubble]
    D --> I[场景快照汇总]
    I --> B
    B -->|sendSceneSnapshot| A

    J[无可用网络] --> K[Mock Fallback]
    K --> B
```

## 通道说明

- 主通道：外部 WebSocket 服务
- 退化通道：内置 Mock 指令流
- 指令协议：原始状态消息、MCP 工具调用消息、JSON-RPC 风格工具调用

## 典型输入示例

```json
{
  "method": "tools/call",
  "params": {
    "name": "set_character_state",
    "arguments": {
      "characterName": "Rosalind",
      "state": "work",
      "duration": 18
    }
  }
}
```
