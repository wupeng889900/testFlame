import 'dart:async' as async;
import 'dart:convert';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'mcp_tool_adapter.dart';

class RemoteCommand {
  final String characterName;
  final String action; // 'work', 'rest', 'meeting'
  final double duration;
  final String source;

  const RemoteCommand({
    required this.characterName,
    required this.action,
    this.duration = 15.0,
    this.source = 'network',
  });
}

class RemoteSyncController extends Component {
  final List<String> characterNames;
  final String websocketUrl;
  final bool enableMockFallback;
  final _controller = async.StreamController<RemoteCommand>.broadcast();
  final _statusController = async.StreamController<String>.broadcast();
  final Random _random = Random();
  final McpToolAdapter _mcpAdapter = const McpToolAdapter();

  Stream<RemoteCommand> get commandStream => _controller.stream;
  Stream<String> get statusStream => _statusController.stream;

  WebSocketChannel? _channel;
  async.StreamSubscription? _channelSubscription;
  async.Timer? _mockTimer;
  String connectionLabel = 'offline';

  RemoteSyncController({
    required this.characterNames,
    required this.websocketUrl,
    this.enableMockFallback = true,
  });

  @override
  Future<void> onLoad() async {
    await _start();
  }

  Future<void> _start() async {
    if (websocketUrl.isNotEmpty) {
      try {
        _channel = WebSocketChannel.connect(Uri.parse(websocketUrl));
        connectionLabel = 'live';
        _statusController.add(connectionLabel);
        _channelSubscription = _channel!.stream.listen(
          _handleMessage,
          onError: (_) => _startMockFallback('degraded'),
          onDone: () => _startMockFallback('disconnected'),
          cancelOnError: false,
        );
        return;
      } catch (_) {
        _startMockFallback('fallback');
        return;
      }
    }

    _startMockFallback('mock');
  }

  void _handleMessage(dynamic raw) {
    try {
      final payload = raw is String ? jsonDecode(raw) : raw;
      if (payload is Map<String, dynamic>) {
        final commands = _mcpAdapter.parse(payload);
        for (final command in commands) {
          _controller.add(command);
        }
      }
    } catch (_) {
      // Ignore malformed network payloads to keep the game loop stable.
    }
  }

  void _startMockFallback(String status) {
    if (!enableMockFallback) {
      connectionLabel = status;
      _statusController.add(connectionLabel);
      return;
    }
    _mockTimer?.cancel();
    connectionLabel = status;
    _statusController.add(connectionLabel);
    _mockTimer = async.Timer.periodic(
      Duration(seconds: 5 + _random.nextInt(4)),
      (_) => _sendRandomCommand(),
    );
  }

  void _sendRandomCommand() {
    if (characterNames.isEmpty) {
      return;
    }
    final name = characterNames[_random.nextInt(characterNames.length)];
    final actions = ['work', 'rest', 'meeting'];
    final action = actions[_random.nextInt(actions.length)];
    _controller.add(
      RemoteCommand(
        characterName: name,
        action: action,
        duration: 10 + _random.nextInt(10).toDouble(),
        source: connectionLabel,
      ),
    );
  }

  void sendSceneSnapshot(Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel == null) {
      return;
    }
    channel.sink.add(jsonEncode(payload));
  }

  @override
  void onRemove() {
    _mockTimer?.cancel();
    _channelSubscription?.cancel();
    _channel?.sink.close();
    _controller.close();
    _statusController.close();
    super.onRemove();
  }
}
