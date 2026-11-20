# 🎯 Respect PVP Hub v1.0 — Official Keyless Release

Official, high-performance, and **100% Keyless** Luau script for **PVP'ye Saygı (Respect PVP)** on Roblox, protected with **Panda-K (Max Security VM)** via Panda Vault Lite.

---

## ⚡ Quick Load (Execution)

Run the following loader code in any supported executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/myheisenberg/Respect-PVP/main/loader.luau"))()
```

---

## ✨ Features

- **Dual Aim Engine:**
  - **Camera Aim (Safe / Anti-Shake):** Direct upvalue integration with CameraController (`u52`/`u53`). Features Sticky Target logic to prevent aim wobble, dynamic FOV circle (green on target lock), and WallCheck.
  - **Silent Aim (Packet Bending):** Direct hit redirection on `WeaponFire` RemoteEvent. Uses angle-budgeting and Humanization (30% body shots + 0.12 stud micro-jitter) to bypass headshot ratio telemetry checks.
- **TriggerBot:** Automated crosshair trigger pulse via `WeaponController.SetTrigger` with customizable millisecond delay.
- **Full ESP:** Supports Players, MatchBots, and Training Dummies (`workspace.Targets`) with Name, Distance, Health, and TeamCheck.
- **Skins Changer:** Unlocks custom weapon skins locally using the game's internal `Skins` and `SkinLook` modules.
- **Mobile Friendly:** Auto-detects touch devices and creates a floating "HUB" toggle button with responsive UI sizing.
- **Safe Teardown:** Full cleanup routines (`PVP_TEARDOWN`) prevent crash on re-execution.
