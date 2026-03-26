# CLAUDE.md — Opticmix Umbrella

## 언어

**항상 한국어로 응답할 것.** 코드 주석과 커밋 메시지는 영어 가능.

## Repository Structure

```
opticmix/
├── edge/          → Opticmix/opticmix-edge      (DLL, streamer, protocol, deploy)
├── tracker/       → Opticmix/opticmix-tracker    (AOT model loader, custom tracker)
├── aeromix/       → Opticmix/opticmix-aeromix    (AeroMix service, CursorOverlay client)
├── re-docs/       → Opticmix/opticmix-re-docs     (RE analysis documents)
├── claude-skills/ → Opticmix/claude-skills        (Claude Code custom skills)
└── scripts/       ← Unified build/deploy scripts
```

Each subdirectory is a git submodule. After cloning:
```bash
git submodule update --init --recursive
```

## Build Commands

```powershell
# Build everything
powershell -File scripts/build_all.ps1

# Edge only (DLL + Streamer)
powershell -File scripts/build_all.ps1 -EdgeOnly

# AeroMix only
powershell -File scripts/build_all.ps1 -AeroMixOnly

# Deploy (admin required)
powershell -File scripts/deploy.ps1

# Check submodule status
powershell -File scripts/status.ps1
```

For component-specific build instructions, see CLAUDE.md in each submodule.

## Architecture

**Goal**: Edge computing hand tracking — client (mini-PC) captures IR camera via USB, streams frames over TCP to server (desktop) where TrackingSvc processes them.

```
Client (미니PC)                      Server (데스크탑)
┌──────────────────┐                ┌───────────────────────┐
│ IR-170 (USB)     │                │ 교체 librealuvc.dll   │
│ Streamer ────────│──TCP 7100────→│  NetworkUvcDevice     │
│                  │←─TCP 7101───→│  NetworkPropertyDriver│
│ CursorOverlay    │                │       ↓ TrackingSvc    │
│ (tray+overlay)   │←─WS 9739────│  AeroMix (0.0.0.0)    │
│   ↓ 커서 표시    │                └───────────────────────┘
│ [모니터]         │
└──────────────────┘
```

## Submodule Workflow

When making changes inside a submodule:
```bash
cd edge/                    # Enter submodule
git checkout main           # Make sure on main branch
# ... make changes ...
git add . && git commit     # Commit inside submodule
git push                    # Push submodule repo

cd ..                       # Back to umbrella
git add edge                # Update submodule pointer
git commit -m "chore: Update edge submodule"
git push                    # Push umbrella
```

## Debugging Rules

- **원본 소스 대조**: Visualizer/프로젝션 등에서 문제가 발생하면 반드시 원본 소스(Ultraleap LeapC + TrackingSvc 모드에서 동작하던 코드)와 비교 검토할 것. 원본에서 작동하던 로직을 기준으로 OpticMixC 모드의 차이점을 분석한다.

## External Dependencies

- OpenCV 4.10.0: `C:\opencv\opencv\build`
- vcpkg: `C:\vcpkg` (libusb-1.0, pthreads4w)
- libuvc: `C:\libuvc`
- TrackingSvc: `C:\Program Files\OpticMix\TrackingService\bin\`
- Tracking SDK: `C:\Program Files\OpticMix\LeapSDK\`
