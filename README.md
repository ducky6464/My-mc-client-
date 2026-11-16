# Skybound Survival

An Android-first, third-person 3D island survival game prototype built with Godot 4.5. It uses an original low-poly island and a nonviolent last-survivor-style supply race.

## Current playable prototype

- Third-person character with follow camera.
- Keyboard and touch movement, camera swipe, and jump controls.
- A 220 × 220 island blockout with roads, cabins, and low-poly trees.
- 24 supply beacons scattered around the island.
- Six AI scout characters that roam toward and collect supplies.
- A safe zone that steadily shrinks during a three-minute match.
- A storm-energy meter that drains outside the safe zone and recharges inside it.
- Match scoring, pause/resume, replay, camera sensitivity settings, and saved best score.
- FPS counter and Android-first rendering settings.

## Open the project

1. Install Godot 4.5.
2. Clone or download this repository.
3. In Godot, import the folder containing `project.godot`.
4. Press **F5** to run the main scene.

## Controls

- WASD / arrow keys: move.
- Space: jump.
- Right mouse drag: rotate camera.
- Touch: left joystick to move, swipe the right half to look, JUMP button to jump.
- Escape: pause.

## Android build

The repository includes an Android debug export preset and a GitHub Actions workflow at `.github/workflows/android-build.yml`.

After a push to `main`, or a manual run from the Actions tab, the workflow:
1. Imports and validates the Godot project headlessly.
2. Launches the main scene as a smoke test.
3. Exports a debug APK.
4. Uploads the APK as `Skybound-Survival-Android-debug`.

The GitHub Actions build verifies project parsing and APK export. It does not replace testing on a physical Android device.

## Next development stages

- Improve the island blockout with original, optimized art and more distinct locations.
- Add a proper match intro and drop-in sequence.
- Improve scout navigation and match pacing.
- Add sound, animation, and accessibility options.
- Profile and optimize on the target Android phone.
- Consider online play only after the offline match is stable.

## Mobile performance

- The project targets landscape orientation and caps the frame rate at 60 FPS.
- The Compatibility renderer is used for broad Android support.
- 3D resolution scaling is set to 80%, MSAA is disabled, and static scenery does not cast dynamic shadows.
- Shared low-poly geometry and simple materials keep the island lightweight.
- Performance must still be measured on physical devices; no specific FPS is guaranteed.
