// PointEntryView.swift
// Screen 2: Point Entry (default screen, 95% usage)

import SwiftUI

struct PointEntryView: View {
    @ObservedObject var connectivity: WatchConnectivityManager

    var body: some View {
        VStack(spacing: 12) {
            // Score at top (small)
            Text("\(connectivity.currentSetScore), \(connectivity.currentGameScore)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .padding(.top, 8)

            Spacer()

            // Mark Winner button (BIG)
            Button(action: {
                connectivity.sendAction("mark_winner")
                WKInterfaceDevice.current().play(.click)  // Haptic feedback
            }) {
                VStack(spacing: 8) {
                    Text("🏆")
                        .font(.system(size: 40))
                    Text("Mark Winner")
                        .font(.system(size: 18, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 80)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            // Jeff Winner button (BIG)
            Button(action: {
                connectivity.sendAction("jeff_winner")
                WKInterfaceDevice.current().play(.click)  // Haptic feedback
            }) {
                VStack(spacing: 8) {
                    Text("🏆")
                        .font(.system(size: 40))
                    Text("Jeff Winner")
                        .font(.system(size: 18, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 80)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

#Preview {
    PointEntryView(connectivity: WatchConnectivityManager())
}
