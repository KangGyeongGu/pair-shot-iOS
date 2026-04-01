//
//  Project.swift
//  PairShot
//
//  Created by KKK on 3/31/26.
//

import Foundation
import SwiftData

/// 현장 작업 프로젝트 (Before-After 쌍 묶음)
@Model
final class Project {
    var id: UUID
    var title: String
    var createdAt: Date

    // MARK: - GPS (권한 거부 시 nil 허용)

    var latitude: Double?
    var longitude: Double?

    // MARK: - 사진 쌍 관계 (cascade delete)

    @Relationship(deleteRule: .cascade, inverse: \PhotoPair.project)
    var pairs: [PhotoPair]

    var completePairCount: Int {
        pairs.count(where: { $0.status == .complete })
    }

    var totalPairCount: Int {
        pairs.count
    }

    var coverThumbnailPath: String? {
        pairs
            .min { $0.createdAt < $1.createdAt }?
            .beforePhoto?
            .thumbnailPath
    }

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.latitude = latitude
        self.longitude = longitude
        pairs = []
    }
}
