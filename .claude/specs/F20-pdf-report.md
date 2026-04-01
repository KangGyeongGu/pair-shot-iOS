# F20 - PDF Report

## Requirements
- A4 layout, before-after placed side by side
- Cover page: Project name, date, location
- Each page: Pair number, before/after photos, capture date/time, GPS, memo
- Display location as GPS coordinate text

## Implementation Points
- `PDFKit`: `PDFDocument` + `PDFPage` generation
- Or custom drawing with `UIGraphicsPDFRenderer`
- GPS coordinates: `CLLocationCoordinate2D` → Text formatting

## Apple SDK References
- .claude/apple-sdk-refs/PDFKit/PDFDocument.h
- .claude/apple-sdk-refs/PDFKit/PDFPage.h
- .claude/apple-sdk-refs/UIKit/UIGraphicsPDFRenderer.h

## Related Files
