# My RTS Game Prototype (Godot 4)

This repository contains a playable Godot 4 RTS prototype inspired by SC2 fundamentals, focused on one playable Human faction.

## What works right now

- Main menu with **Start Skirmish** and **Quit**.
- One Human HQ and six worker units spawned at game start.
- Primitive placeholder models (capsule workers, box HQ, cylinder mineral fields).
- Left-click worker selection.
- Right-click move commands on terrain.
- Right-click mineral field to issue gather command.
- Workers mine, return to HQ, and increase player mineral count.
- RTS camera movement (`WASD`) and zoom (`mouse wheel`).
- `Esc` returns to the main menu.

## Run

1. Install **Godot 4.2+**.
2. Open this folder as a Godot project.
3. Press **Run** (F5).
4. Click **Start Skirmish**.

## Controls

- `Left click`: Select a worker.
- `Right click`: Move selected worker or gather from mineral field.
- `W`, `A`, `S`, `D`: Move camera.
- `Mouse wheel`: Zoom camera.
- `Esc`: Return to menu.

## Next milestones

- Add worker pathing and collision avoidance.
- Add production (buildings + unit queue).
- Add basic enemy AI and win/loss conditions.
- Replace placeholders with real art/models.
