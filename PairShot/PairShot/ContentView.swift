//
//  ContentView.swift
//  PairShot
//
//  Created by KKK on 3/31/26.
//

import SwiftUI

struct ContentView: View {
    @State private var showCamera: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 32) {
                    // 앱 아이콘 영역
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 72, weight: .thin))
                        .foregroundStyle(.white)

                    Text("Pair Shot")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)

                    Text("현장 Before·After 촬영")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))

                    Spacer().frame(height: 16)

                    // 촬영 시작 버튼
                    NavigationLink(destination: CameraView()) {
                        HStack(spacing: 10) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 17, weight: .semibold))
                            Text("촬영 시작")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(.black)
                        .frame(minWidth: 200, minHeight: 54)
                        .background(Color.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    ContentView()
}
