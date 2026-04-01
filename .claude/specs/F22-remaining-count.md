# F22 - Remaining Count Display

## Requirements
- Persistently display the number of uncaptured pairs in the current project during After capture mode
- Count automatically decreases with each completed capture
- Example: "5 remaining" → Capture → "4 remaining"

## UI Behavior
- Concise count badge at top or bottom of After camera screen
- Display "All complete" + success haptic when all pairs are done

## Implementation Points
- `@Query(filter: #Predicate { $0.status == .pendingAfter })` count
- SwiftUI `Text("\(remainingCount) remaining")` overlay

## Apple SDK References
- .claude/apple-sdk-refs/SwiftData/SwiftData.swiftinterface

## Related Files
