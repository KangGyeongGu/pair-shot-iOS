//
//  PhotoPair.swift
//  PairShot
//
//  Created by KKK on 3/31/26.
//

import Foundation
import SwiftData

/// Before-After 사진 쌍 단위
@Model
final class PhotoPair {
    var id: UUID
    var createdAt: Date
    var status: PairStatus

    // MARK: - 사진 관계

    @Relationship(deleteRule: .cascade)
    var beforePhoto: Photo?

    @Relationship(deleteRule: .cascade)
    var afterPhoto: Photo?

    // MARK: - 역방향 관계

    var project: Project?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        status: PairStatus = .pendingAfter,
        project: Project? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.status = status
        self.project = project
    }
}
