//
//  PairStatus.swift
//  PairShot
//
//  Created by KKK on 3/31/26.
//

import Foundation

/// 사진 쌍의 완료 상태
enum PairStatus: String, Codable, CaseIterable {
    /// Before 촬영 완료, After 촬영 대기 중
    case pendingAfter = "pending_after"
    /// Before + After 모두 촬영 완료
    case complete = "complete"
}
