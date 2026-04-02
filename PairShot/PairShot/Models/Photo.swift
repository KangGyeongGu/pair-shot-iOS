//
//  Photo.swift
//  PairShot
//
//  Created by KKK on 3/31/26.
//

import Foundation
import SwiftData

/// 촬영된 단일 사진 및 센서 데이터
@Model
final class Photo {
    var id: UUID
    /// Documents 기준 상대 경로 (예: projects/{project_id}/pairs/{pair_id}/before.jpg)
    var filePath: String
    /// Documents 기준 상대 경로 (예: projects/{project_id}/thumbs/{pair_id}_before.jpg)
    var thumbnailPath: String
    var timestamp: Date

    // MARK: - GPS

    var latitude: Double?
    var longitude: Double?
    var altitude: Double?

    // MARK: - 방향/자세 (Core Motion)

    var heading: Double?
    var pitch: Double?
    var roll: Double?
    var yaw: Double?

    // MARK: - 메모

    var notes: String?

    var worldMapPath: String?
    var arTransformData: Data?

    init(
        id: UUID = UUID(),
        filePath: String,
        thumbnailPath: String,
        timestamp: Date = Date(),
        latitude: Double? = nil,
        longitude: Double? = nil,
        altitude: Double? = nil,
        heading: Double? = nil,
        pitch: Double? = nil,
        roll: Double? = nil,
        yaw: Double? = nil,
        notes: String? = nil,
        worldMapPath: String? = nil,
        arTransformData: Data? = nil
    ) {
        self.id = id
        self.filePath = filePath
        self.thumbnailPath = thumbnailPath
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.heading = heading
        self.pitch = pitch
        self.roll = roll
        self.yaw = yaw
        self.notes = notes
        self.worldMapPath = worldMapPath
        self.arTransformData = arTransformData
    }
}
