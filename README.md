# CATS - Cognitive-Aware Task Scheduler

**CATS** is a **brain-aware planner** that lives in the macOS Dynamic Island. It schedules your tasks based on your mental capacity, not just time availability.

---

## Features

- **Natural Language Task Input** -- Tell CATS what you need to do via chat (e.g., "I need to finish Graph Theory today")
- **Cognitive Load Estimation** -- Automatically estimates task difficulty (1-10) from keywords
- **Smart Scheduling** -- Matches high-load tasks to peak energy hours, light tasks for when you're tired
- **Apple Calendar Integration** -- Reads deadlines from and writes study blocks to Apple Calendar
- **Dynamic Island UI** -- Lives in the macOS notch area with countdown timers and status
- **Double-Click Dropdown** -- Full task list with sections for In Progress, Upcoming, Completed
- **Deep Work Timer** -- Focus sessions with Pomodoro-style micro-breaks
- **Recovery Cycles** -- Detects fatigue and proactively suggests restorative breaks
- **Gamification** -- XP, streaks, and cat-themed levels from "Curious Kitten" to "Legendary Neko"
- **130+ Kaomoji Cats** -- Mood-aware cat faces throughout the UI

---

## Preview

| Closed State | Expanded | Task List |
|---|---|---|
| Cat + Deadline Countdown | Chat + Deep Work | Full Dropdown |

---

## Installation

```bash
git clone https://github.com/your-repo/CATS.git
cd CATS
open *.xcodeproj
```

- Select the Mac target in Xcode and hit **Run**.
- Grant calendar access when prompted.

## Packaging (macOS App + DMG)

```bash
./scripts/package-macos.sh
```

- Outputs are written to `dist/`.
- The script produces both a `.zip` and a `.dmg`.
- The app is built unsigned for local distribution/testing.

---

## Usage

- **Hover** -- Preview next deadline with cat face
- **Single Click** -- Open full panel (Tasks / Chat / Deep Work / Settings)
- **Double Click** -- Open task list dropdown
- **Chat** -- Type naturally: "Study Dynamic Programming by Friday"
- **Deep Work** -- Start focus sessions, earn XP, level up

---

## Requirements

- **macOS**: 14.5 or later
- **Xcode**: 15.0 or later
- **Swift**: 5.0 or later

---

## License

Licensed under the **MPL-2.0 License**.
See [LICENSE](LICENSE) for details.
