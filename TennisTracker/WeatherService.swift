//
//  WeatherService.swift
//  TennisTracker
//
//  Created by M@rkMoriarty.com on 10/4/25.
//

import Foundation
import WeatherKit
import CoreLocation

@MainActor
class WeatherService {
    static let shared = WeatherService()
    private let weatherService = WeatherKit.WeatherService.shared

    private init() {}

    /// Fetches current weather for a given location and updates the match asynchronously
    /// This runs in the background and won't block the UI
    func fetchWeather(for match: Match, latitude: Double, longitude: Double) async {
        let location = CLLocation(latitude: latitude, longitude: longitude)

        print("🌤️ WeatherService: Starting fetch for location \(latitude), \(longitude)")

        do {
            let weather = try await weatherService.weather(for: location)
            let currentWeather = weather.currentWeather

            print("🌤️ WeatherService: Got weather data - temp: \(currentWeather.temperature.value)°C, condition: \(currentWeather.condition.description), symbol: \(currentWeather.symbolName)")

            // Update match with weather data
            match.temperature = currentWeather.temperature.value  // Celsius
            match.weatherCondition = currentWeather.condition.description
            match.weatherSymbol = currentWeather.symbolName

            print("✅ Weather updated on match - temp: \(match.temperature ?? -999), condition: \(match.weatherCondition ?? "nil"), symbol: \(match.weatherSymbol ?? "nil")")
        } catch {
            print("❌ Failed to fetch weather: \(error.localizedDescription)")
            print("❌ Error details: \(error)")
            // Don't crash - weather is nice-to-have, not critical
        }
    }
}
