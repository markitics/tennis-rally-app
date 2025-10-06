// ScoreDisplayView.swift
// Screen 1: Score Display (swipe left from Point Entry)

import SwiftUI

struct ScoreDisplayView: View {
    let gameScore: String
    let setScore: String
    let serverName: String

    var body: some View {
        VStack(spacing: 20) {
            // Game score (BIG)
            Text(gameScore)
                .font(.system(size: 60, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            // Set score (small)
            Text(setScore)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.gray)

            // Server indicator (small)
            Text("\(serverName) serving")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

#Preview {
    ScoreDisplayView(
        gameScore: "40-30",
        setScore: "2-1",
        serverName: "Mark"
    )
}
