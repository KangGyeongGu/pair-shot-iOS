# F06 - Photo Pair List (Project Detail Screen)

## Requirements
- Tap project in Archive → Display all before-after pairs for that project in a grid (2 columns)
- Each cell: before thumbnail / after thumbnail (if missing, empty frame + visual incomplete indicator)
- Visual emphasis on incomplete pairs (red border or badge)
- Pair tap behavior:
  - After exists → Enter comparison view
  - After missing → Enter After capture camera (auto-load overlay + guide for that before)
- Pair deletion (swipe or edit mode)
- "Add Before Photos" button → Additional before captures for this project
- "Batch After Capture" button → Enter After capture mode for incomplete pairs in sequence

## Non-functional Requirements
- Smooth scrolling even with 100+ pairs (LazyVGrid + load thumbnails only)
- Thumbnail cache to prevent repeated loading

## UI Behavior
- Top: Project name + completion rate (12/20 pairs)
- Bottom floating: "Add Before" / "After Capture" buttons
- Filter segment: All / Incomplete / Complete
- Incomplete pairs displayed at top with priority

## Edge Cases
- Empty project (0 pairs) → Empty state screen + "Take your first photo" prompt
- All pairs complete → "All complete" state + export prompt
- Thumbnail file corrupted/missing → Default placeholder image

## Implementation Points
- `LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())])`
- `@Query(filter:, sort:)` SwiftData query for filtering + incomplete-first sorting
- Thumbnails: `UIImage` cache (NSCache)
- Incomplete indicator: `photoPair.status == .pendingAfter` → Red border
- "Batch After Capture": Iterate incomplete pair array, enter After camera for each → Capture → Auto-transition to next pair

## Apple SDK References
- .claude/apple-sdk-refs/SwiftData/SwiftData.swiftinterface
- .claude/apple-sdk-refs/SwiftUI/SwiftUI.swiftinterface

## Related Files
