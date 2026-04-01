# F01 - Project Management + Archive Structure

## Core Workflow
```
App Launch → Archive (Project List) → "New Field Shoot" tab
→ Create Project (enter name + auto GPS) → Immediately enter Before Camera
→ Continuous shooting → Shooting complete → Return to Archive

Later:
Archive → Select Project → Pair List → Select incomplete pair → Enter After Camera
```

## Archive Structure
```
Archive (Project List)
├── Gangnam Site [12/20 complete] [2026-04-01]
│   ├── Pair 001: before.jpg ↔ after.jpg ✅
│   ├── Pair 002: before.jpg ↔ (not taken) ❌
│   └── ...
├── Yeoksam Site [0/8 complete] [2026-04-02]
│   └── ...
└── + New Field Shoot
```

## Requirements
- Project creation: Name input, auto creation date, auto-record current GPS location
- Project list: Sorted by most recent, thumbnail (first before photo), completion rate (N/M pairs complete) display
- Project deletion: Confirmation dialog then delete all photo files + DB records
- Project rename: Inline editing
- **"New Field Shoot" button → Project creation and Before Camera connected as a single flow**

## Non-functional Requirements
- No scroll lag even with 100+ projects in the list
- Photo files in Documents must be cleaned up on deletion (prevent orphan files)

## UI Behavior
- First screen on app launch = Archive (Project List)
- **"New Field Shoot" large button** → Name input sheet → Confirm → Create project + immediately enter Before Camera
- Tap existing project → Enter pair gallery
- Swipe left → Delete
- Long press → Rename

## Edge Cases
- No name entered → Auto-generate default name with date+time ("2026-04-01 09:15 Site")
- Deleting a project with hundreds of photos → Background processing + progress indicator
- GPS permission denied → Create without location (location nil allowed)

## Implementation Points
- SwiftData `@Model`: Project, 1:N relationship PhotoPair
- `@Query(sort: \Project.createdAt, order: .reverse)` for most recent first
- File deletion: `FileManager.default.removeItem(at:)` + error handling
- Project creation → Before Camera entry: NavigationStack `.navigationDestination` chain

### File System Storage Structure
```
Documents/
├── projects/
│   ├── {project_id}/
│   │   ├── pairs/
│   │   │   ├── {pair_id}/
│   │   │   │   ├── before.jpg
│   │   │   │   ├── after.jpg          ← Created after After shoot
│   │   │   │   └── before_armap.dat   ← ARWorldMap (when available)
│   │   │   ├── {pair_id}/
│   │   │   │   └── ...
│   │   │   └── ...
│   │   └── thumbs/
│   │       ├── {pair_id}_before.jpg   ← 300x300 thumbnail
│   │       └── {pair_id}_after.jpg
│   └── {project_id}/
│       └── ...
└── exports/                            ← Temporary export directory (cleaned after sharing)
```

## Apple SDK References
- .claude/apple-sdk-refs/SwiftData/SwiftData.swiftinterface
- .claude/apple-sdk-refs/CoreLocation/CLLocationManager.h
- .claude/apple-sdk-refs/CoreLocation/CLLocation.h

## Related Files
