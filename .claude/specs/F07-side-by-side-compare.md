# F07 - Basic Comparison View (Side by Side)

## Requirements
- Before on left / After on right displayed side by side
- Synchronized pinch zoom: Zooming one side zooms the other to the same region
- Synchronized panning: Dragging one side moves the other identically
- Double tap to reset zoom

## Non-functional Requirements
- Smooth zoom/panning even when displaying high-resolution images (CATiledLayer or MKMapView pattern)

## UI Behavior
- Full screen, left-right split
- Bottom: Comparison mode switch tab bar (Side by Side / Slider / Heatmap)
- Top: Back button + Share button

## Edge Cases
- Before/after aspect ratios differ → Crop to match the smaller one
- Very large images (48MP) → Display downscaled version + load original tiles on zoom

## Implementation Points
- `ScrollView` + `.simultaneousGesture(MagnificationGesture)` synchronization
- Shared `@State var zoomScale`, `@State var offset`
- High resolution: Generate display version with `CGImageSourceCreateThumbnailAtPixelSize`, crop original region on zoom

## Related Files
