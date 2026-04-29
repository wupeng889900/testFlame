# office_sim

Flutter + Flame office scene demo. The reusable entry point is now separated
from the local demo app so it can be embedded into another Flutter project.

## Integration

Copy these parts into the target project:

- `lib/game/`
- `lib/office_game_embed.dart`
- the `assets/office_game/`, `assets/environment/`, `assets/data/office_game_layout.json`,
  and font assets referenced by `pubspec.yaml`
- the dependencies `flame`, `web_socket_channel`, `http`, and
  `shared_preferences`

Then add the scene where you need it:

```dart
import 'package:office_sim/office_game_embed.dart';

class OfficeTab extends StatelessWidget {
  const OfficeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const OfficeGamePage(
      options: OfficeGameOptions(
        showEditorTools: false,
        enableRemoteSync: false,
      ),
    );
  }
}
```

For the local calibration/demo app, `lib/main.dart` keeps editor tools enabled.
For product integration, keep `showEditorTools` off unless you specifically need
route and seat-position editing in-app.

## Runtime Options

`OfficeGameOptions` controls the parts that usually differ between demo and
production embedding:

- `showEditorTools`: shows the route and character position editor overlay.
- `enableRemoteSync`: enables websocket command/snapshot sync.
- `enableMockRemoteCommands`: lets the remote controller generate mock commands
  when no websocket is available. Keep this off in production.
- `websocketUrl`: websocket endpoint. It defaults to the compile-time
  `OFFICE_WS_URL` value.

Example with a websocket:

```bash
flutter run --dart-define=OFFICE_WS_URL=ws://127.0.0.1:8787
```

## Notes

- Scene layout is data-driven from `assets/data/office_game_layout.json`.
- Character state positions can be tuned with the editor overlay in the demo.
- Saved route editing uses local storage at runtime; project JSON writing is only
  available where the project asset file can be accessed directly.
