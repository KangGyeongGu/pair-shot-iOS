# F12 - Share Sheet Export

## Requirements
- Share selected pair's photos with standardized filenames
- Filename: `{ProjectName}_{PairNumber}_before.jpg`, `{ProjectName}_{PairNumber}_after.jpg`
- iOS share sheet (AirDrop, Email, KakaoTalk, Files app, etc.)

## Non-functional Requirements
- Multi-pair selection → Batch sharing supported
- Create temporary files, clean up after sharing is complete

## UI Behavior
- Share button on pair detail screen or gallery
- Gallery edit mode: Multi-select → Share

## Implementation Points
- Copy to temporary directory with standardized filenames → `UIActivityViewController(activityItems:)`
- Use `FileManager.default.temporaryDirectory`
- Delete temporary files in share completion callback

## Related Files
