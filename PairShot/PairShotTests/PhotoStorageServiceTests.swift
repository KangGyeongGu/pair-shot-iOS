import Foundation
@testable import PairShot
import Testing

@MainActor
struct PhotoStorageServiceTests {
    private func makeService() -> PhotoStorageService {
        PhotoStorageService()
    }

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - photoURL happy path

    @Test func photoURL_happyPath_beforeReturnsBeforeJpg() throws {
        let service = makeService()
        let projectId = UUID()
        let pairId = UUID()

        let url = try service.photoURL(projectId: projectId, pairId: pairId, isBefore: true)

        #expect(url.lastPathComponent == "before.jpg")
    }

    @Test func photoURL_happyPath_afterReturnsAfterJpg() throws {
        let service = makeService()
        let projectId = UUID()
        let pairId = UUID()

        let url = try service.photoURL(projectId: projectId, pairId: pairId, isBefore: false)

        #expect(url.lastPathComponent == "after.jpg")
    }

    // MARK: - photoURL boundary

    @Test func photoURL_boundary_pathContainsPairId() throws {
        let service = makeService()
        let projectId = UUID()
        let pairId = UUID()

        let url = try service.photoURL(projectId: projectId, pairId: pairId, isBefore: true)

        #expect(url.path.contains(pairId.uuidString))
    }

    @Test func photoURL_boundary_pathContainsProjectId() throws {
        let service = makeService()
        let projectId = UUID()
        let pairId = UUID()

        let url = try service.photoURL(projectId: projectId, pairId: pairId, isBefore: false)

        #expect(url.path.contains(projectId.uuidString))
    }

    // MARK: - photoURL negative

    @Test func photoURL_negative_beforeAndAfterPathsAreDifferent() throws {
        let service = makeService()
        let projectId = UUID()
        let pairId = UUID()

        let beforeURL = try service.photoURL(projectId: projectId, pairId: pairId, isBefore: true)
        let afterURL = try service.photoURL(projectId: projectId, pairId: pairId, isBefore: false)

        #expect(beforeURL.path != afterURL.path)
    }

    @Test func photoURL_negative_differentPairIdProducesDifferentPath() throws {
        let service = makeService()
        let projectId = UUID()
        let pairId1 = UUID()
        let pairId2 = UUID()

        let url1 = try service.photoURL(projectId: projectId, pairId: pairId1, isBefore: true)
        let url2 = try service.photoURL(projectId: projectId, pairId: pairId2, isBefore: true)

        #expect(url1.path != url2.path)
    }

    // MARK: - photoURL error

    @Test func photoURL_error_differentProjectIdProducesDifferentPath() throws {
        let service = makeService()
        let projectId1 = UUID()
        let projectId2 = UUID()
        let pairId = UUID()

        let url1 = try service.photoURL(projectId: projectId1, pairId: pairId, isBefore: true)
        let url2 = try service.photoURL(projectId: projectId2, pairId: pairId, isBefore: true)

        #expect(url1.path != url2.path)
    }

    // MARK: - thumbnailURL happy path

    @Test func thumbnailURL_happyPath_beforeContainsBeforeSuffix() throws {
        let service = makeService()
        let projectId = UUID()
        let pairId = UUID()

        let url = try service.thumbnailURL(projectId: projectId, pairId: pairId, isBefore: true)

        #expect(url.lastPathComponent == "\(pairId.uuidString)_before.jpg")
    }

    @Test func thumbnailURL_happyPath_afterContainsAfterSuffix() throws {
        let service = makeService()
        let projectId = UUID()
        let pairId = UUID()

        let url = try service.thumbnailURL(projectId: projectId, pairId: pairId, isBefore: false)

        #expect(url.lastPathComponent == "\(pairId.uuidString)_after.jpg")
    }

    // MARK: - thumbnailURL boundary

    @Test func thumbnailURL_boundary_pathContainsProjectId() throws {
        let service = makeService()
        let projectId = UUID()
        let pairId = UUID()

        let url = try service.thumbnailURL(projectId: projectId, pairId: pairId, isBefore: true)

        #expect(url.path.contains(projectId.uuidString))
    }

    @Test func thumbnailURL_boundary_pathContainsPairId() throws {
        let service = makeService()
        let projectId = UUID()
        let pairId = UUID()

        let url = try service.thumbnailURL(projectId: projectId, pairId: pairId, isBefore: false)

        #expect(url.path.contains(pairId.uuidString))
    }

    // MARK: - thumbnailURL negative

    @Test func thumbnailURL_negative_beforeAndAfterPathsAreDifferent() throws {
        let service = makeService()
        let projectId = UUID()
        let pairId = UUID()

        let beforeURL = try service.thumbnailURL(projectId: projectId, pairId: pairId, isBefore: true)
        let afterURL = try service.thumbnailURL(projectId: projectId, pairId: pairId, isBefore: false)

        #expect(beforeURL.path != afterURL.path)
    }

    @Test func thumbnailURL_negative_differentPairIdProducesDifferentFilename() throws {
        let service = makeService()
        let projectId = UUID()
        let pairId1 = UUID()
        let pairId2 = UUID()

        let url1 = try service.thumbnailURL(projectId: projectId, pairId: pairId1, isBefore: true)
        let url2 = try service.thumbnailURL(projectId: projectId, pairId: pairId2, isBefore: true)

        #expect(url1.lastPathComponent != url2.lastPathComponent)
    }

    // MARK: - thumbnailURL error

    @Test func thumbnailURL_error_storedInThumbsNotPairsDirectory() throws {
        let service = makeService()
        let projectId = UUID()
        let pairId = UUID()

        let thumbURL = try service.thumbnailURL(projectId: projectId, pairId: pairId, isBefore: true)
        let photoURL = try service.photoURL(projectId: projectId, pairId: pairId, isBefore: true)

        #expect(thumbURL.deletingLastPathComponent().path != photoURL.deletingLastPathComponent().path)
    }

    // MARK: - projectDirectoryURL happy path

    @Test func projectDirectoryURL_happyPath_pathContainsProjectId() throws {
        let service = makeService()
        let projectId = UUID()

        let url = try service.projectDirectoryURL(for: projectId)

        #expect(url.path.contains(projectId.uuidString))
    }

    @Test func projectDirectoryURL_happyPath_pathContainsProjectsSegment() throws {
        let service = makeService()
        let projectId = UUID()

        let url = try service.projectDirectoryURL(for: projectId)

        #expect(url.path.contains("projects"))
    }

    // MARK: - projectDirectoryURL boundary

    @Test func projectDirectoryURL_boundary_differentProjectIdsProduceDifferentPaths() throws {
        let service = makeService()
        let projectId1 = UUID()
        let projectId2 = UUID()

        let url1 = try service.projectDirectoryURL(for: projectId1)
        let url2 = try service.projectDirectoryURL(for: projectId2)

        #expect(url1.path != url2.path)
    }

    @Test func projectDirectoryURL_boundary_lastPathComponentIsProjectId() throws {
        let service = makeService()
        let projectId = UUID()

        let url = try service.projectDirectoryURL(for: projectId)

        #expect(url.lastPathComponent == projectId.uuidString)
    }

    // MARK: - projectDirectoryURL negative

    @Test func projectDirectoryURL_negative_sameSeedReturnsSamePath() throws {
        let service = makeService()
        let projectId = UUID()

        let url1 = try service.projectDirectoryURL(for: projectId)
        let url2 = try service.projectDirectoryURL(for: projectId)

        #expect(url1.path == url2.path)
    }

    // MARK: - projectDirectoryURL error

    @Test func projectDirectoryURL_error_isSubpathOfDocumentsDirectory() throws {
        let service = makeService()
        let projectId = UUID()

        let url = try service.projectDirectoryURL(for: projectId)

        #expect(url.path.hasPrefix(documentsURL.path))
    }

    // MARK: - createDirectories happy path

    @Test func createDirectories_happyPath_pairDirectoryExists() throws {
        let service = makeService()
        let projectId = UUID()
        let pairId = UUID()

        try service.createDirectories(for: projectId, pairId: pairId)
        let pairDir = try service.pairDirectoryURL(for: projectId, pairId: pairId)

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: pairDir.path, isDirectory: &isDirectory)
        #expect(exists == true)
        #expect(isDirectory.boolValue == true)

        try? FileManager.default.removeItem(at: try service.projectDirectoryURL(for: projectId))
    }

    @Test func createDirectories_happyPath_thumbsDirectoryExists() throws {
        let service = makeService()
        let projectId = UUID()
        let pairId = UUID()

        try service.createDirectories(for: projectId, pairId: pairId)
        let thumbDir = try service.thumbnailDirectoryURL(for: projectId)

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: thumbDir.path, isDirectory: &isDirectory)
        #expect(exists == true)
        #expect(isDirectory.boolValue == true)

        try? FileManager.default.removeItem(at: try service.projectDirectoryURL(for: projectId))
    }

    // MARK: - createDirectories boundary

    @Test func createDirectories_boundary_idempotentWhenCalledTwice() throws {
        let service = makeService()
        let projectId = UUID()
        let pairId = UUID()

        try service.createDirectories(for: projectId, pairId: pairId)
        try service.createDirectories(for: projectId, pairId: pairId)

        let pairDir = try service.pairDirectoryURL(for: projectId, pairId: pairId)
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: pairDir.path, isDirectory: &isDirectory)
        #expect(exists == true)
        #expect(isDirectory.boolValue == true)

        try? FileManager.default.removeItem(at: try service.projectDirectoryURL(for: projectId))
    }

    @Test func createDirectories_boundary_multiplePairsShareThumbsDirectory() throws {
        let service = makeService()
        let projectId = UUID()
        let pairId1 = UUID()
        let pairId2 = UUID()

        try service.createDirectories(for: projectId, pairId: pairId1)
        try service.createDirectories(for: projectId, pairId: pairId2)

        let thumbDir1 = try service.thumbnailDirectoryURL(for: projectId)
        let thumbDir2 = try service.thumbnailDirectoryURL(for: projectId)
        #expect(thumbDir1.path == thumbDir2.path)

        try? FileManager.default.removeItem(at: try service.projectDirectoryURL(for: projectId))
    }

    // MARK: - createDirectories negative

    @Test func createDirectories_negative_differentPairIdsCreateDifferentSubdirectories() throws {
        let service = makeService()
        let projectId = UUID()
        let pairId1 = UUID()
        let pairId2 = UUID()

        try service.createDirectories(for: projectId, pairId: pairId1)
        try service.createDirectories(for: projectId, pairId: pairId2)

        let dir1 = try service.pairDirectoryURL(for: projectId, pairId: pairId1)
        let dir2 = try service.pairDirectoryURL(for: projectId, pairId: pairId2)
        #expect(dir1.path != dir2.path)

        try? FileManager.default.removeItem(at: try service.projectDirectoryURL(for: projectId))
    }

    // MARK: - createDirectories error

    @Test func createDirectories_error_directoryNotExistBeforeCreation() throws {
        let service = makeService()
        let projectId = UUID()
        let pairId = UUID()

        let pairDir = try service.pairDirectoryURL(for: projectId, pairId: pairId)
        #expect(FileManager.default.fileExists(atPath: pairDir.path) == false)

        try service.createDirectories(for: projectId, pairId: pairId)
        #expect(FileManager.default.fileExists(atPath: pairDir.path) == true)

        try? FileManager.default.removeItem(at: try service.projectDirectoryURL(for: projectId))
    }

    // MARK: - deleteProject happy path

    @Test func deleteProject_happyPath_directoryIsRemovedAfterDelete() async throws {
        let service = makeService()
        let projectId = UUID()
        let pairId = UUID()

        try service.createDirectories(for: projectId, pairId: pairId)
        let projectDir = try service.projectDirectoryURL(for: projectId)
        #expect(FileManager.default.fileExists(atPath: projectDir.path) == true)

        service.deleteProject(projectId: projectId)

        #expect(FileManager.default.fileExists(atPath: projectDir.path) == false)
    }

    @Test func deleteProject_happyPath_subDirectoriesAreAlsoRemoved() async throws {
        let service = makeService()
        let projectId = UUID()
        let pairId = UUID()

        try service.createDirectories(for: projectId, pairId: pairId)
        let pairDir = try service.pairDirectoryURL(for: projectId, pairId: pairId)
        #expect(FileManager.default.fileExists(atPath: pairDir.path) == true)

        service.deleteProject(projectId: projectId)

        #expect(FileManager.default.fileExists(atPath: pairDir.path) == false)
    }

    // MARK: - deleteProject boundary

    @Test func deleteProject_boundary_deletingNonExistentProjectDoesNotThrow() async throws {
        let service = makeService()
        let nonExistentId = UUID()

        service.deleteProject(projectId: nonExistentId)

        let projectDir = try service.projectDirectoryURL(for: nonExistentId)
        #expect(FileManager.default.fileExists(atPath: projectDir.path) == false)
    }

    @Test func deleteProject_boundary_deleteDoesNotAffectOtherProjects() async throws {
        let service = makeService()
        let projectId1 = UUID()
        let projectId2 = UUID()
        let pairId = UUID()

        try service.createDirectories(for: projectId1, pairId: pairId)
        try service.createDirectories(for: projectId2, pairId: pairId)

        service.deleteProject(projectId: projectId1)

        let projectDir2 = try service.projectDirectoryURL(for: projectId2)
        #expect(FileManager.default.fileExists(atPath: projectDir2.path) == true)

        try? FileManager.default.removeItem(at: projectDir2)
    }

    // MARK: - deleteProject negative

    @Test func deleteProject_negative_callingTwiceIsIdempotent() async throws {
        let service = makeService()
        let projectId = UUID()
        let pairId = UUID()

        try service.createDirectories(for: projectId, pairId: pairId)
        service.deleteProject(projectId: projectId)
        service.deleteProject(projectId: projectId)

        let projectDir = try service.projectDirectoryURL(for: projectId)
        #expect(FileManager.default.fileExists(atPath: projectDir.path) == false)
    }

    // MARK: - deleteProject error

    @Test func deleteProject_error_thumbsDirectoryIsAlsoRemoved() async throws {
        let service = makeService()
        let projectId = UUID()
        let pairId = UUID()

        try service.createDirectories(for: projectId, pairId: pairId)
        let thumbDir = try service.thumbnailDirectoryURL(for: projectId)
        #expect(FileManager.default.fileExists(atPath: thumbDir.path) == true)

        service.deleteProject(projectId: projectId)

        #expect(FileManager.default.fileExists(atPath: thumbDir.path) == false)
    }
}
