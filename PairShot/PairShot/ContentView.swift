import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        ArchiveView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Project.self, PhotoPair.self, Photo.self], inMemory: true)
}
