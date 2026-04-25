enum CharacterState { idle, walking, working, discussing, resting }

extension CharacterStateLabel on CharacterState {
  String get label {
    switch (this) {
      case CharacterState.idle:
        return '空闲';
      case CharacterState.walking:
        return '移动中';
      case CharacterState.working:
        return '工作中';
      case CharacterState.discussing:
        return '讨论中';
      case CharacterState.resting:
        return '休息中';
    }
  }

  String get sitAssetKey {
    switch (this) {
      case CharacterState.working:
        return 'work';
      case CharacterState.discussing:
        return 'meeting';
      case CharacterState.resting:
        return 'rest';
      case CharacterState.idle:
      case CharacterState.walking:
        return 'idle';
    }
  }
}

CharacterState characterStateFromJson(String value) {
  switch (value) {
    case 'walking':
      return CharacterState.walking;
    case 'working':
      return CharacterState.working;
    case 'discussing':
      return CharacterState.discussing;
    case 'resting':
      return CharacterState.resting;
    case 'idle':
    default:
      return CharacterState.idle;
  }
}
