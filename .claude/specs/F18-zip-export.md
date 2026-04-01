# F18 - ZIP Bundle Export

## Requirements
- ZIP compress all pair photos per project
- Include standardized filenames + index.csv metadata
- Invoke share sheet after ZIP generation

## Non-functional Requirements
- ZIP generation for 100 pairs (200 photos) within 10 seconds
- Display progress during generation

## ZIP Internal Structure
```
{ProjectName}_{Date}/
  ├── {ProjectName}_001_before.jpg
  ├── {ProjectName}_001_after.jpg
  ├── ...
  └── index.csv
```

## index.csv
```csv
PairNumber,Before_DateTime,After_DateTime,Latitude,Longitude,Memo
001,2026-04-01 09:15,2026-04-01 17:30,37.4979,127.0276,1st floor lobby
```

## Implementation Points
- ZIPFoundation: `Archive(url:accessMode:)` → `addEntry`
- Copy files with renamed filenames to temporary directory → ZIP → Share → Clean up
- Progress: `Progress` object binding

## Apple SDK References
- .claude/apple-sdk-refs/Foundation/NSFileManager.h
- .claude/apple-sdk-refs/UIKit/UIActivityViewController.h

## Related Files
