# Pair Shot

## Project Overview
iOS native app for field workers to capture and manage Before-After photo pairs.
"Easy and fast for field workers" is the top priority.

## Target Device
- Primary dev/test: iPhone 15 Pro (developer), iPhone 17 Pro (client)
- Minimum support: standard iPhone without LiDAR (basic features work)
- Sensor layering: no LiDAR → camera tracking + sensor guide; with LiDAR → auto-enhanced precision

## Tech Stack
- Swift 6 / SwiftUI / iOS 17+
- AVFoundation (camera, 48MP, macro, low-light auto compensation)
- ARKit (precise repositioning — works without LiDAR, enhanced with it)
- Core Motion (gyro/compass), Core Location (GPS)
- Vision (AI auto-alignment, similarity — iOS built-in, no custom model needed)
- Core Image (change detection heatmap, color correction — iOS built-in filters)
- Core Haptics (angle matching vibration feedback)
- SwiftData (local DB)
- PDFKit, ZIPFoundation

## Distribution
- Apple Developer Program ($99/year) + TestFlight

## Storage
- Local device only (no cloud upload)

## Development Guidelines
- Respond in Korean to the user
- Target iOS 17+
- UX first — minimum taps, intuitive visual guides, automation
- Sensor layering — never depend on a single sensor
- Low-light auto — app optimizes exposure without user knowledge
- Removed features: NFC, voice memo, floor detection, CloudKit, WeatherKit, map view

## Git Convention
- Conventional Commits: `<type>(<scope>): <English summary>` + Korean body
- NEVER add Co-Authored-By, Contributed-by, or any attribution trailer
- NEVER reference Claude, AI, bot, or assistant in commits/PRs
