import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/core/enums.dart';
import 'game/world/office_game.dart';

export 'game/world/office_game.dart' show OfficeGame, OfficeGameOptions;

class OfficeGamePage extends StatefulWidget {
  final OfficeGameOptions options;

  const OfficeGamePage({super.key, this.options = const OfficeGameOptions()});

  @override
  State<OfficeGamePage> createState() => _OfficeGamePageState();
}

class _OfficeGamePageState extends State<OfficeGamePage> {
  late OfficeGame _game;
  bool _walkRouteEditing = false;
  bool _characterPositionEditing = false;
  String _selectedCharacterName = '程序员';
  CharacterState _selectedPositionState = CharacterState.work;
  Vector2? _selectedStatePosition;
  String _selectedStateDirection = 'up';
  int _draftPointCount = 0;
  int _savedRouteCount = 0;
  Timer? _routePointRefreshTimer;

  @override
  void initState() {
    super.initState();
    _game = OfficeGame(options: widget.options);
    if (widget.options.showEditorTools) {
      _routePointRefreshTimer = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) {
          if (!mounted) {
            return;
          }
          final nextDraftCount = _game.walkRouteDraftPointCount;
          final nextRouteCount = _game.savedWalkRouteCount;
          final nextPosition = _game.characterStatePosition(
            _selectedCharacterName,
            _selectedPositionState,
          );
          final nextDirection =
              _game.characterStateDirection(
                _selectedCharacterName,
                _selectedPositionState,
              ) ??
              _selectedStateDirection;
          if (nextDraftCount != _draftPointCount ||
              nextRouteCount != _savedRouteCount ||
              !_samePoint(nextPosition, _selectedStatePosition) ||
              nextDirection != _selectedStateDirection) {
            setState(() {
              _draftPointCount = nextDraftCount;
              _savedRouteCount = nextRouteCount;
              _selectedStatePosition = nextPosition?.clone();
              _selectedStateDirection = nextDirection;
            });
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _routePointRefreshTimer?.cancel();
    super.dispose();
  }

  void _reloadGame() {
    setState(() {
      _game = OfficeGame(options: widget.options);
      _walkRouteEditing = false;
      _characterPositionEditing = false;
      _selectedStatePosition = null;
      _selectedStateDirection = 'up';
      _draftPointCount = 0;
      _savedRouteCount = 0;
    });
  }

  void _resetCamera() {
    _game.resetCamera();
  }

  void _setWalkRouteEditing(bool value) {
    setState(() {
      _walkRouteEditing = value;
      if (value) {
        _characterPositionEditing = false;
        _game.setCharacterPositionEditing(false);
      }
      _game.setWalkRouteEditing(value);
      _draftPointCount = _game.walkRouteDraftPointCount;
      _savedRouteCount = _game.savedWalkRouteCount;
    });
  }

  void _setCharacterPositionEditing(bool value) {
    setState(() {
      _characterPositionEditing = value;
      if (value) {
        _walkRouteEditing = false;
        _game.setWalkRouteEditing(false);
      }
      _game.setCharacterPositionEditing(
        value,
        selectedName: _selectedCharacterName,
      );
      _selectedStatePosition =
          _game
              .characterStatePosition(
                _selectedCharacterName,
                _selectedPositionState,
              )
              ?.clone();
      _selectedStateDirection =
          _game.characterStateDirection(
            _selectedCharacterName,
            _selectedPositionState,
          ) ??
          _selectedStateDirection;
    });
  }

  void _selectCharacter(String name) {
    setState(() {
      _selectedCharacterName = name;
      _game.selectCharacterForPositionEdit(name);
      _selectedStatePosition =
          _game.characterStatePosition(name, _selectedPositionState)?.clone();
      _selectedStateDirection =
          _game.characterStateDirection(name, _selectedPositionState) ??
          _selectedStateDirection;
    });
  }

  void _selectPositionState(CharacterState state) {
    setState(() {
      _selectedPositionState = state;
      _game.selectPositionState(state);
      _selectedStatePosition =
          _game.characterStatePosition(_selectedCharacterName, state)?.clone();
      _selectedStateDirection =
          _game.characterStateDirection(_selectedCharacterName, state) ??
          _selectedStateDirection;
    });
  }

  Future<void> _selectPositionDirection(String direction) async {
    await _game.setCharacterStateDirection(
      _selectedCharacterName,
      _selectedPositionState,
      direction,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedStateDirection =
          _game.characterStateDirection(
            _selectedCharacterName,
            _selectedPositionState,
          ) ??
          direction;
    });
  }

  Future<void> _nudgeSelectedCharacter(double dx, double dy) async {
    await _game.nudgeCharacterStatePosition(
      _selectedCharacterName,
      _selectedPositionState,
      Vector2(dx, dy),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedStatePosition =
          _game
              .characterStatePosition(
                _selectedCharacterName,
                _selectedPositionState,
              )
              ?.clone();
      _selectedStateDirection =
          _game.characterStateDirection(
            _selectedCharacterName,
            _selectedPositionState,
          ) ??
          _selectedStateDirection;
    });
    _game.previewCharacterStatePosition(
      _selectedCharacterName,
      _selectedPositionState,
    );
  }

  Future<void> _resetCharacterPositions() async {
    await _game.resetCharacterStatePositions();
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedStatePosition =
          _game
              .characterStatePosition(
                _selectedCharacterName,
                _selectedPositionState,
              )
              ?.clone();
      _selectedStateDirection =
          _game.characterStateDirection(
            _selectedCharacterName,
            _selectedPositionState,
          ) ??
          _selectedStateDirection;
    });
  }

  Future<void> _saveCharacterPositionsToJson() async {
    await _game.saveCharacterStatePositionsToJson();
    if (mounted) {
      setState(() {});
    }
  }

  bool _samePoint(Vector2? a, Vector2? b) {
    if (a == null || b == null) {
      return a == null && b == null;
    }
    return a.x.round() == b.x.round() && a.y.round() == b.y.round();
  }

  void _undoWalkRoutePoint() {
    setState(() {
      _game.undoWalkRoutePoint();
      _draftPointCount = _game.walkRouteDraftPointCount;
    });
  }

  void _clearWalkRouteDraft() {
    setState(() {
      _game.clearWalkRouteDraft();
      _draftPointCount = 0;
    });
  }

  Future<void> _saveWalkRouteDraft() async {
    await _game.saveWalkRouteDraft();
    if (!mounted) {
      return;
    }
    setState(() {
      _draftPointCount = _game.walkRouteDraftPointCount;
      _savedRouteCount = _game.savedWalkRouteCount;
    });
  }

  Future<void> _clearSavedWalkRoutes() async {
    await _game.clearSavedWalkRoutes();
    if (!mounted) {
      return;
    }
    setState(() {
      _draftPointCount = 0;
      _savedRouteCount = 0;
    });
  }

  @override
  void reassemble() {
    super.reassemble();
    _reloadGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF183247),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: SafeArea(
                    bottom: false,
                    child: GameWidget(key: ValueKey(_game), game: _game),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _GameActionButton(
                          tooltip: '重置视角',
                          icon: Icons.center_focus_strong,
                          onPressed: _resetCamera,
                        ),
                        const SizedBox(height: 12),
                        _GameActionButton(
                          tooltip: '重新开始',
                          icon: Icons.refresh,
                          onPressed: _reloadGame,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.options.showEditorTools)
            _EditorControlsPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _WalkRouteEditorPanel(
                    routeEditing: _walkRouteEditing,
                    draftPointCount: _draftPointCount,
                    savedRouteCount: _savedRouteCount,
                    onEditingChanged: _setWalkRouteEditing,
                    onUndoPoint: _undoWalkRoutePoint,
                    onClearDraft: _clearWalkRouteDraft,
                    onSaveRoute: _saveWalkRouteDraft,
                    onClearSavedRoutes: _clearSavedWalkRoutes,
                  ),
                  const SizedBox(height: 12),
                  _CharacterPositionPanel(
                    editing: _characterPositionEditing,
                    characterNames: _game.characterNames,
                    selectedName: _selectedCharacterName,
                    selectedState: _selectedPositionState,
                    position: _selectedStatePosition,
                    direction: _selectedStateDirection,
                    onEditingChanged: _setCharacterPositionEditing,
                    onSelected: _selectCharacter,
                    onStateSelected: _selectPositionState,
                    onDirectionSelected: _selectPositionDirection,
                    onNudge: _nudgeSelectedCharacter,
                    onReset: _resetCharacterPositions,
                    onSaveJson: _saveCharacterPositionsToJson,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EditorControlsPanel extends StatelessWidget {
  final Widget child;

  const _EditorControlsPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFF102536)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: height * 0.42, minHeight: 112),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _WalkRouteEditorPanel extends StatelessWidget {
  final bool routeEditing;
  final int draftPointCount;
  final int savedRouteCount;
  final ValueChanged<bool> onEditingChanged;
  final VoidCallback onUndoPoint;
  final VoidCallback onClearDraft;
  final Future<void> Function() onSaveRoute;
  final Future<void> Function() onClearSavedRoutes;

  const _WalkRouteEditorPanel({
    required this.routeEditing,
    required this.draftPointCount,
    required this.savedRouteCount,
    required this.onEditingChanged,
    required this.onUndoPoint,
    required this.onClearDraft,
    required this.onSaveRoute,
    required this.onClearSavedRoutes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xE61B2D3D),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x55FFFFFF)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: DefaultTextStyle(
            style: theme.textTheme.bodyMedium!.copyWith(color: Colors.white),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '走廊路线',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Switch(
                      value: routeEditing,
                      onChanged: onEditingChanged,
                      activeColor: const Color(0xFFFFD166),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('当前画线点：$draftPointCount'),
                Text('已保存路线：$savedRouteCount'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onUndoPoint,
                        icon: const Icon(Icons.undo, size: 18),
                        label: const Text('撤销'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          onSaveRoute();
                        },
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text('保存'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onClearDraft,
                        icon: const Icon(Icons.backspace_outlined, size: 18),
                        label: const Text('清当前'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          onClearSavedRoutes();
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('清全部'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CharacterPositionPanel extends StatelessWidget {
  final bool editing;
  final List<String> characterNames;
  final String selectedName;
  final CharacterState selectedState;
  final Vector2? position;
  final String direction;
  final ValueChanged<bool> onEditingChanged;
  final ValueChanged<String> onSelected;
  final ValueChanged<CharacterState> onStateSelected;
  final ValueChanged<String> onDirectionSelected;
  final Future<void> Function(double dx, double dy) onNudge;
  final Future<void> Function() onReset;
  final Future<void> Function() onSaveJson;

  const _CharacterPositionPanel({
    required this.editing,
    required this.characterNames,
    required this.selectedName,
    required this.selectedState,
    required this.position,
    required this.direction,
    required this.onEditingChanged,
    required this.onSelected,
    required this.onStateSelected,
    required this.onDirectionSelected,
    required this.onNudge,
    required this.onReset,
    required this.onSaveJson,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final names =
        characterNames.isEmpty ? <String>[selectedName] : characterNames;
    final selected = names.contains(selectedName) ? selectedName : names.first;
    final coordinateText =
        position == null
            ? '坐下坐标：--, --'
            : '坐下坐标：${position!.x.round()}, ${position!.y.round()}';
    final directionText = '方向：${_directionLabel(direction)}';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xE61B2D3D),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x55FFFFFF)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: DefaultTextStyle(
            style: theme.textTheme.bodyMedium!.copyWith(color: Colors.white),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '状态位置',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Switch(
                      value: editing,
                      onChanged: onEditingChanged,
                      activeColor: const Color(0xFFFFD166),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children:
                      names
                          .map(
                            (name) => ChoiceChip(
                              label: Text(name),
                              selected: selected == name,
                              onSelected:
                                  editing ? (_) => onSelected(name) : null,
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children:
                      _editableStates
                          .map(
                            (state) => ChoiceChip(
                              label: Text(_stateLabel(state)),
                              selected: selectedState == state,
                              onSelected:
                                  editing
                                      ? (_) => onStateSelected(state)
                                      : null,
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children:
                      _editableDirections
                          .map(
                            (item) => ChoiceChip(
                              avatar: Icon(item.icon, size: 16),
                              label: Text(item.label),
                              selected: direction == item.value,
                              onSelected:
                                  editing
                                      ? (_) => onDirectionSelected(item.value)
                                      : null,
                            ),
                          )
                          .toList(),
                ),
                Text(coordinateText),
                Text(directionText),
                const SizedBox(height: 10),
                _NudgePad(enabled: editing, onNudge: onNudge),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: editing ? () => onReset() : null,
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text('重置状态位置'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: editing ? () => onSaveJson() : null,
                  icon: const Icon(Icons.save_as, size: 18),
                  label: const Text('保存到JSON'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const List<CharacterState> _editableStates = [
  CharacterState.work,
  CharacterState.meeting,
  CharacterState.rest,
];

const List<_EditableDirection> _editableDirections = [
  _EditableDirection('up', '上', Icons.keyboard_arrow_up),
  _EditableDirection('down', '下', Icons.keyboard_arrow_down),
  _EditableDirection('left', '左', Icons.keyboard_arrow_left),
  _EditableDirection('right', '右', Icons.keyboard_arrow_right),
];

class _EditableDirection {
  final String value;
  final String label;
  final IconData icon;

  const _EditableDirection(this.value, this.label, this.icon);
}

String _stateLabel(CharacterState state) {
  switch (state) {
    case CharacterState.work:
      return '工作中';
    case CharacterState.meeting:
      return '讨论中';
    case CharacterState.rest:
      return '休息中';
    case CharacterState.walk:
      return '移动中';
    case CharacterState.idle:
      return '空闲中';
  }
}

String _directionLabel(String direction) {
  switch (direction) {
    case 'left':
      return '朝左';
    case 'right':
      return '朝右';
    case 'up':
      return '朝上';
    case 'down':
      return '朝下';
    default:
      return direction;
  }
}

class _NudgePad extends StatelessWidget {
  final bool enabled;
  final Future<void> Function(double dx, double dy) onNudge;

  const _NudgePad({required this.enabled, required this.onNudge});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _NudgeButton(
          enabled: enabled,
          icon: Icons.keyboard_arrow_up,
          onPressed: () => onNudge(0, -8),
        ),
        Row(
          children: [
            Expanded(
              child: _NudgeButton(
                enabled: enabled,
                icon: Icons.keyboard_arrow_left,
                onPressed: () => onNudge(-8, 0),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NudgeButton(
                enabled: enabled,
                icon: Icons.keyboard_double_arrow_left,
                onPressed: () => onNudge(-1, 0),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NudgeButton(
                enabled: enabled,
                icon: Icons.keyboard_double_arrow_right,
                onPressed: () => onNudge(1, 0),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NudgeButton(
                enabled: enabled,
                icon: Icons.keyboard_arrow_right,
                onPressed: () => onNudge(8, 0),
              ),
            ),
          ],
        ),
        _NudgeButton(
          enabled: enabled,
          icon: Icons.keyboard_arrow_down,
          onPressed: () => onNudge(0, 8),
        ),
      ],
    );
  }
}

class _NudgeButton extends StatelessWidget {
  final bool enabled;
  final IconData icon;
  final VoidCallback onPressed;

  const _NudgeButton({
    required this.enabled,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: IconButton.outlined(
        padding: EdgeInsets.zero,
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: 18),
      ),
    );
  }
}

class _GameActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _GameActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 46,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: const Color(0xE62E74D8),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Icon(icon, size: 22),
        ),
      ),
    );
  }
}
