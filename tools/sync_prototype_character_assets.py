from __future__ import annotations

import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OFFICE_GAME_ROOT = ROOT / "assets" / "office_game" / "characters"
PROTOTYPE_ROOT = ROOT / "assets" / "images" / "characters"

ROLE_MAP = {
    "programmer": "programmer",
    "designer": "designer",
    "pm": "project_manager",
    "tester": "tester",
    "ops": "operator",
}

FILE_MAP = {
    "idle/idle_down.png": "idle_down.png",
    "idle/idle_up.png": "idle_up.png",
    "idle/idle_left.png": "idle_left.png",
    "idle/idle_right.png": "idle_right.png",
    "walk/walk_down_0.png": "walk_down_01.png",
    "walk/walk_down_2.png": "walk_down_02.png",
    "walk/walk_up_0.png": "walk_up_01.png",
    "walk/walk_up_2.png": "walk_up_02.png",
    "walk/walk_left_0.png": "walk_left_01.png",
    "walk/walk_left_2.png": "walk_left_02.png",
    "walk/walk_right_0.png": "walk_right_01.png",
    "walk/walk_right_2.png": "walk_right_02.png",
    "sit_desk/sit_desk_front.png": "sit_work_down.png",
    "sit_desk/sit_desk_front.png#up": "sit_work_up.png",
    "sit_desk/sit_desk_left.png": "sit_work_left.png",
    "sit_desk/sit_desk_right.png": "sit_work_right.png",
    "meeting_states/talk_up.png": "sit_meeting_down.png",
    "meeting_states/talk_up.png#up": "sit_meeting_up.png",
    "meeting_states/talk_left.png": "sit_meeting_left.png",
    "meeting_states/talk_right.png": "sit_meeting_right.png",
    "sofa_states/sit_sofa_front.png": "sit_rest_down.png",
    "sofa_states/sit_sofa_up.png": "sit_rest_up.png",
    "sofa_states/sit_sofa_left.png": "sit_rest_left.png",
    "sofa_states/sit_sofa_right.png": "sit_rest_right.png",
}


def copy_asset(source: Path, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)


def main() -> None:
    for source_role, target_role in ROLE_MAP.items():
        source_root = OFFICE_GAME_ROOT / source_role
        target_root = PROTOTYPE_ROOT / target_role
        if not source_root.exists():
            raise FileNotFoundError(source_root)

        for source_rel, target_name in FILE_MAP.items():
            source_key = source_rel.split("#", 1)[0]
            source = source_root / source_key
            target = target_root / target_name
            copy_asset(source, target)

        print(f"{target_role}: synced from {source_role}")


if __name__ == "__main__":
    main()
