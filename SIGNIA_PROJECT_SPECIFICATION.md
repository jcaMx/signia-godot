# Signia — Project Specification & Technical Documentation

**Signia** is an educational 2D game built in **Godot Engine 4.6** designed to teach users Filipino Sign Language (FSL). The game integrates real-time FSL sign recognition by communicating asynchronously over a REST API with an external **Python Flask FSL Recognition Server**.

---

## 1. Project Overview & Architecture

### System Architecture Diagram
```
                     +---------------------------------+
                     |  Python Flask FSL API Server    |
                     |     http://127.0.0.1:5000/      |
                     +----------------+----------------+
                                      ^
                                      | HTTP POST /predict (0.1s polling)
                                      v
+-------------------------------------------------------------------------------+
| Godot 4.6 Client (Signia)                                                     |
|                                                                               |
|   +-----------------------+           +--------------------+                  |
|   |   FSLHttpClient.gd    | --------> |  FSLInputBridge.gd |                  |
|   | (Timer + HTTPRequest) |           |   (Event Router)   |                  |
|   +-----------------------+           +---------+----------+                  |
|                                                 |                             |
|                        +------------------------+------------------------+    |
|                        v                                                 v    |
|             +--------------------+                             +-------------+|
|             |  DialogueManager   |                             | GameManager ||
|             | (Branching Graph)  |                             | (Challenge) ||
|             +---------+----------+                             +------+------+|
|                       |                                               |       |
|                       v                                               v       |
|             +--------------------+                             +-------------+|
|             | UI / Speech Bubbles|                             | User Input  ||
|             | (ui.gd / text_box) |                             | HUD Banner  ||
|             +--------------------+                             +-------------+|
+-------------------------------------------------------------------------------+
```

### Key Technical Specs
* **Engine:** Godot Engine 4.6 (Forward Plus driver, Direct3D 12)
* **Viewport Resolution:** $456 \times 273$ (Scaled to $1920 \times 1080$ viewport override)
* **Rendering Style:** 2D Pixel Art with `nearest` texture filtering
* **Physics Engine:** Jolt Physics 3D / Godot 2D Physics
* **Web Integration:** Single Web Export target (`/signia-game/index.html?chapter=N`) communicating bi-directionally with Vue/Nuxt web frontend via `JavaScriptBridge` (`window.parent.postMessage`).

---

## 1.1 Web Frontend (Vue / Nuxt) & Single Export Architecture

### URL-Based Chapter Launching
The Godot engine uses a **Single Web Export**. The Vue frontend launches the game passing `?chapter=1`, `?chapter=2`, etc.
* [`LevelManager.gd`](file:///c:/Users/Acer/Games/signia/Scripts/LevelManager.gd) reads `new URLSearchParams(window.location.search).get('chapter')` on web startup.
* [`main_menu.gd`](file:///c:/Users/Acer/Games/signia/Scripts/main_menu.gd) automatically bypasses the main menu UI and directly loads the requested chapter scene (`res://Scenes/scene_1.tscn`, `res://Scenes/scene_2.tscn`, etc.).

### Bi-Directional Web Events (`postMessage`)
* `SIGNIA_PROGRESS_UPDATE`: Emitted to `window.parent` on every waypoint reached with details (`current_level`, `waypoint_index`, `total_waypoints`, `completed_levels`).
* `SIGNIA_CHAPTER_FINISHED`: Emitted to `window.parent` when a level/chapter is completed (`level_id`).

---

## 2. API & FSL Recognition Pipeline

### Server Communication Protocol
* **Endpoint:** `POST http://127.0.0.1:5000/predict`
* **Request Frequency:** Polling interval of `0.1s` via a `Timer` in `FSLHttpClient.tscn`.
* **Request Payload:**
```json
{
  "mode": "alphabet",
  "frame_source": "server",
  "stabilize": true,
  "stream_id": "godot-player-1"
}
```
* **Response Payload Handling:**
```json
{
  "prediction": "A",
  "confidence": 0.92,
  "emitted": true,
  "stabilized_prediction": "A",
  "suppressed_change": false,
  "raw_prediction": "A",
  "raw_confidence": 0.92,
  "history_length": 5,
  "hand_detected": true,
  "frame_source": "server"
}
```

### Processing Logic
1. **Filtering:** A gesture is accepted when `raw_confidence >= 0.60` and `raw_prediction != last_raw_prediction`.
2. **Event Dispatch:** `FSLHttpClient` emits signal `sign_detected(prediction, confidence)` directly connected to `FSLInputBridge.on_sign_detected`.
3. **Challenge Routing:**
   * If an active spelling/sign challenge exists in [`GameManager`](file:///c:/Users/Acer/Games/signia/Scripts/GameManager.gd), the sign is processed by `GameManager.submit_sign()` or `GameManager.submit_letter()`.
   * Otherwise, if active dialogue choices exist in [`DialogueManager`](file:///c:/Users/Acer/Games/signia/Scripts/DialogueManager.gd), it advances the dialogue matching the target choice sign ID.

---

## 3. Scripts Inventory & Class Breakdown

### Global Autoload Singletons (Registered in `project.godot`)

| Autoload Name | Script Path | Description |
| :--- | :--- | :--- |
| **`DialogueManager`** | [`Scripts/DialogueManager.gd`](file:///c:/Users/Acer/Games/signia/Scripts/DialogueManager.gd) | Manages graph-based JSON dialogue traversal, NPC/Narrator modes, choice branching, and player advance inputs. |
| **`GameManager`** | [`Scripts/GameManager.gd`](file:///c:/Users/Acer/Games/signia/Scripts/GameManager.gd) | Controls active spelling & sign challenges, letter progress matching, status prompts, and level chapter completion signals. |
| **`SignProcessor`** | [`Scripts/SignProcessor.gd`](file:///c:/Users/Acer/Games/signia/Scripts/SignProcessor.gd) | Utility class for identifying challenge types (`SPELL_*` vs `SIGN_*`), stripping prefixes, and normalizing letter inputs. |
| **`FSLInputBridge`** | [`Scripts/FSLInputBridge.gd`](file:///c:/Users/Acer/Games/signia/Scripts/FSLInputBridge.gd) | Decoupled sign signal router that channels detected signs into `GameManager` or `DialogueManager`. |
| **`LevelManager`** | [`Scripts/LevelManager.gd`](file:///c:/Users/Acer/Games/signia/Scripts/LevelManager.gd) | Tracks current level index, level scene path registry, waypoint index progress, and triggers level completion events. |
| **`SaveManager`** | [`Scripts/SaveManager.gd`](file:///c:/Users/Acer/Games/signia/Scripts/SaveManager.gd) | Manages persistent save state (`user://save_data.json`), unlocked levels, completed tasks, and Master audio volume. |

---

### Core Gameplay & System Scripts

#### 1. FSL Networking & Detection
* [`Scripts/FSLHttpClient.gd`](file:///c:/Users/Acer/Games/signia/Scripts/FSLHttpClient.gd): Sends periodic HTTP POST requests to the Flask server, parses JSON response fields (`raw_prediction`, `raw_confidence`), updates on-screen debug text, and emits `sign_detected`.

#### 2. Player & NPC Controllers
* [`Player/Scripts/player.gd`](file:///c:/Users/Acer/Games/signia/Player/Scripts/player.gd): `CharacterBody2D` script controlling player movement along defined level `Waypoints`, directional walking animations (`walk_up/down/left/right`), idle animations, and pausing during active dialogue.
* [`Player/Scripts/npc.gd`](file:///c:/Users/Acer/Games/signia/Player/Scripts/npc.gd): `Node2D` script attached to NPCs containing an `Area2D` collision trigger that starts dialogue upon player collision.
* [`Player/Scripts/marker.gd`](file:///c:/Users/Acer/Games/signia/Player/Scripts/marker.gd): Lightweight non-physics path-following node used for waypoint testing.

#### 3. User Interface (UI) Controllers
* [`Scripts/ui.gd`](file:///c:/Users/Acer/Games/signia/Scripts/ui.gd): CanvasLayer manager that dynamically positions speech bubbles above active speaker NPCs or bottom-aligns narration boxes.
* [`Scripts/text_box.gd`](file:///c:/Users/Acer/Games/signia/Scripts/text_box.gd): Dynamic NPC speech bubble script featuring typewriter text rendering (Tween), auto-wrapping, and click-to-advance input.
* [`Scripts/narrator_box.gd`](file:///c:/Users/Acer/Games/signia/Scripts/narrator_box.gd): Bottom-screen narrator text box with typewriter effect.
* [`Scripts/choice_box.gd`](file:///c:/Users/Acer/Games/signia/Scripts/choice_box.gd): Container that instantiates dialogue choice buttons and connects user selection or sign gesture triggers to challenges.
* [`Scripts/choice_item.gd`](file:///c:/Users/Acer/Games/signia/Scripts/choice_item.gd): Choice button item component script.
* [`Scripts/user_input.gd`](file:///c:/Users/Acer/Games/signia/Scripts/user_input.gd): HUD banner overlay displaying active challenge word progress (e.g., `S I G N I A`), status message prompts, and keyboard fallback input debugging.
* [`Scripts/main_menu.gd`](file:///c:/Users/Acer/Games/signia/Scripts/main_menu.gd): Main menu control supporting Play, Continue (with save validation), and Quit actions.
* [`Scripts/pause_menu.gd`](file:///c:/Users/Acer/Games/signia/Scripts/pause_menu.gd): Pause menu overlay managing process pause state, audio bus volume slider, level reload, and return to main menu.
* [`Scripts/chapter_finished_ui.gd`](file:///c:/Users/Acer/Games/signia/Scripts/chapter_finished_ui.gd): Chapter completion overlay shown when a player finishes all level waypoints.
* [`Scripts/progress_bar.gd`](file:///c:/Users/Acer/Games/signia/Scripts/progress_bar.gd): HUD progress bar updating completion percentage based on current level waypoint index.
* [`Scripts/AudioManager.gd`](file:///c:/Users/Acer/Games/signia/Scripts/AudioManager.gd): Manager for playing background music and sound effects.

---

## 4. Main Scenes Breakdown

### Game Level Scenes

#### 1. [`res://Scenes/scene_1.tscn`](file:///c:/Users/Acer/Games/signia/Scenes/scene_1.tscn) *(Main Starting Scene)*
* **Role:** Level 1 environment (Farm & Village theme).
* **Components:**
  * TileMaps (`FarmLand_Tile`, `Cliff_Tile`, `Oak_Tree`, `Beach_Tile`, `output_tileset`)
  * `Player` node with `player.gd` controller
  * `Waypoints` path node container
  * `NPC` triggers linked to dialogue files [`dialogues/s1_p1.json`](file:///c:/Users/Acer/Games/signia/dialogues/s1_p1.json) and [`dialogues/s1_p2.json`](file:///c:/Users/Acer/Games/signia/dialogues/s1_p2.json)
  * `UI` canvas layer containing `FSLHttpClient` instance and debug labels.

#### 2. [`res://Scenes/scene_2.tscn`](file:///c:/Users/Acer/Games/signia/Scenes/scene_2.tscn)
* **Role:** Level 2 environment.
* **Components:** Expanded level terrain, waypoints system, and NPCs connected to dialogues `s2_p1.json` through `s2_p5.json`.

#### 3. [`res://Scenes/scene_3.tscn`](file:///c:/Users/Acer/Games/signia/Scenes/scene_3.tscn)
* **Role:** Level 3 environment (Beach theme).
* **Components:** Coastal tilemaps, waypoints system, and NPCs connected to dialogues `s3_p1.json` through `s3_p6.json`.

#### 4. [`res://Scenes/test_ai_scene.tscn`](file:///c:/Users/Acer/Games/signia/Scenes/test_ai_scene.tscn)
* **Role:** Developer test environment for isolated FSL API integration testing. Contains standalone `HTTPRequest`, `Timer`, and output `Label`.

---

### UI & Sub-System Scenes

| Scene Path | Description |
| :--- | :--- |
| [`res://Scenes/UI/MainMenu.tscn`](file:///c:/Users/Acer/Games/signia/Scenes/UI/MainMenu.tscn) | Start menu screen with Play, Continue, and Quit buttons. |
| [`res://Scenes/UI/ui.tscn`](file:///c:/Users/Acer/Games/signia/Scenes/UI/ui.tscn) | Primary overlay containing `TextBox`, `ChoiceBox`, `NarratorBox`, and nested `FSLHttpClient`. |
| [`res://Scenes/UI/PauseMenu.tscn`](file:///c:/Users/Acer/Games/signia/Scenes/UI/PauseMenu.tscn) | In-game pause menu modal with volume control slider. |
| [`res://Scenes/UI/ChapterFinished.tscn`](file:///c:/Users/Acer/Games/signia/Scenes/UI/ChapterFinished.tscn) | Chapter finished banner modal. |
| [`res://Scenes/UI/progress_bar_ui.tscn`](file:///c:/Users/Acer/Games/signia/Scenes/UI/progress_bar_ui.tscn) | Waypoint completion progress bar UI widget. |
| [`res://Scenes/FSLHttpClient.tscn`](file:///c:/Users/Acer/Games/signia/Scenes/FSLHttpClient.tscn) | Network HTTP polling node containing `HTTPRequest`, `Timer` (0.1s), and status `Label`. |
| [`res://Scenes/user_input.tscn`](file:///c:/Users/Acer/Games/signia/Scenes/user_input.tscn) | Challenge HUD banner displaying status messages and spelling input progress. |
| [`res://Scenes/textbox.tscn`](file:///c:/Users/Acer/Games/signia/Scenes/textbox.tscn) | Dynamic speech bubble UI for NPC dialogues. |
| [`res://Scenes/narrator_box.tscn`](file:///c:/Users/Acer/Games/signia/Scenes/narrator_box.tscn) | Screen-bottom narration box widget. |
| [`res://Scenes/choice_box.tscn`](file:///c:/Users/Acer/Games/signia/Scenes/choice_box.tscn) | Dialogue choices layout container. |
| [`res://Scenes/choice_item.tscn`](file:///c:/Users/Acer/Games/signia/Scenes/choice_item.tscn) | Choice button item prefab. |
| [`res://Scenes/npc.tscn`](file:///c:/Users/Acer/Games/signia/Scenes/npc.tscn) | NPC entity prefab with `Sprite2D` and `Area2D` collision trigger. |

---

## 5. Dialogue Data System Structure

Dialogue files are located under [`dialogues/*.json`](file:///c:/Users/Acer/Games/signia/dialogues). Each JSON file defines an array of dialogue node objects.

### JSON Node Schema
```json
[
  {
    "id": 0,
    "type": "npc",
    "speaker": "Elder Maria",
    "text": "Welcome! Can you sign 'HELLO' to continue?",
    "choices": [
      {
        "text": "Sign HELLO",
        "sign": "SIGN_HELLO",
        "next": 1
      },
      {
        "text": "Spell HELLO",
        "sign": "SPELL_HELLO",
        "next": 1
      }
    ]
  },
  {
    "id": 1,
    "type": "narrator",
    "text": "You successfully completed the sign greeting!",
    "next": -1
  }
]
```

### Challenge Prefixes
* `SPELL_<WORD>`: Triggers a letter-by-letter spelling challenge managed by `GameManager.gd` (e.g. `SPELL_APPLE` requires signing `A`, `P`, `P`, `L`, `E` in sequence).
* `SIGN_<GESTURE>`: Triggers a single direct sign gesture challenge (e.g. `SIGN_HELLO` requires recognizing `HELLO`).
