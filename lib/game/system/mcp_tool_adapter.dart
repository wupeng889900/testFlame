import '../core/enums.dart';
import 'remote_controller.dart';

class McpToolAdapter {
  const McpToolAdapter();

  List<RemoteCommand> parse(Map<String, dynamic> message) {
    final dynamic type = message['type'];
    if (type == 'state_change') {
      final command = _parseDirectCommand(message);
      return command == null ? const [] : [command];
    }

    if (type == 'mcp.tool_call') {
      return _parseToolCall(message);
    }

    if (message.containsKey('method')) {
      return _parseJsonRpc(message);
    }

    return const [];
  }

  List<RemoteCommand> _parseJsonRpc(Map<String, dynamic> message) {
    final method = message['method'];
    if (method != 'tools/call') {
      return const [];
    }
    final params = (message['params'] as Map?)?.cast<String, dynamic>() ?? const {};
    return _parseToolPayload(
      params['name']?.toString() ?? '',
      (params['arguments'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  List<RemoteCommand> _parseToolCall(Map<String, dynamic> message) {
    final tool = message['tool']?.toString() ?? '';
    final arguments = (message['arguments'] as Map?)?.cast<String, dynamic>() ?? const {};
    return _parseToolPayload(tool, arguments);
  }

  List<RemoteCommand> _parseToolPayload(
    String tool,
    Map<String, dynamic> arguments,
  ) {
    switch (tool) {
      case 'set_character_state':
        final command = _parseDirectCommand(arguments);
        return command == null ? const [] : [command];
      case 'batch_set_character_state':
        final items = (arguments['items'] as List?) ?? const [];
        return items
            .whereType<Map>()
            .map((item) => _parseDirectCommand(item.cast<String, dynamic>()))
            .whereType<RemoteCommand>()
            .toList();
      default:
        return const [];
    }
  }

  RemoteCommand? _parseDirectCommand(Map<String, dynamic> payload) {
    final characterName = payload['characterName']?.toString() ??
        payload['character']?.toString() ??
        payload['name']?.toString();
    final action = payload['action']?.toString() ?? payload['state']?.toString();
    final durationRaw = payload['duration'];
    final duration = durationRaw is num ? durationRaw.toDouble() : 15.0;

    if (characterName == null || characterName.isEmpty || action == null || action.isEmpty) {
      return null;
    }

    final normalized = _normalizeAction(action);
    if (normalized == null) {
      return null;
    }

    return RemoteCommand(
      characterName: characterName,
      action: normalized.name,
      duration: duration,
      source: 'mcp',
    );
  }

  CharacterState? _normalizeAction(String value) {
    switch (value.toLowerCase()) {
      case 'work':
      case 'working':
      case '工作':
      case '工作中':
        return CharacterState.work;
      case 'rest':
      case 'resting':
      case '休息':
      case '休息中':
        return CharacterState.rest;
      case 'meeting':
      case 'discuss':
      case '讨论':
      case '讨论中':
        return CharacterState.meeting;
      default:
        return null;
    }
  }
}
