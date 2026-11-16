# Skybound Survival

An Android-first, third-person 3D collection-survival prototype built with Godot 4.5.

## Current playable prototype

- Third-person character with a follow camera.
- Keyboard controls for desktop testing.
- On-screen movement joystick, camera swipe and jump button for touch devices.
- Low-poly arena with solid obstacles.
- 12 glowing energy cores to collect.
- Three-minute round timer.
- Pause/resume overlay and replay button.
- Win condition for collecting all cores and a timeout condition.

## Open the project

1. Install Godot 4.5.
2. Clone or download this repository.
3. In Godot, import the folder containing `project.godot`.
4. Press **F6** or **F5** to run the main scene.

## Controls

- WASD / arrow keys: move.
- Space: jump.
- Right mouse drag: rotate camera.
- Touch: left joystick to move, swipe the right half to look, JUMP button to jump.
- Escape: pause.

## Android build

The repository includes an Android debug export preset and a GitHub Actions workflow at `.github/workflows/android-build.yml`.

After a push to `main`, or a manual run from the Actions tab, the workflow attempts to:
1. Import/validate the Godot project headlessly.
2. Export a debug APK.
3. Upload the APK as a workflow artifact named `Skybound-Survival-Android-debug`.

The first workflow run is the real check that the export setup works. The APK has not yet been confirmed as built or tested on a phone.

## Not included yet

- Online multiplayer or matchmaking.
- Multiple maps and character customization.
- Audio, accessibility options and full settings menu.
- Cloud saves and progression.
- Performance testing on physical Android devices.
