import AppKit
import Foundation

struct PriceData {
    let timestamp: Date
    let price: Double
}

struct ChartIndicators {
    var sma20: Double?
    var sma50: Double?
    var ema12: Double?
    var ema26: Double?
    var macd: Double?
    var macdSignal: Double?
    var macdHistogram: Double?
    var rsi: Double?
    var bollingerUpper: Double?
    var bollingerLower: Double?
    var bollingerMiddle: Double?
}

struct AnalysisResult {
    let trend: String
    let confidence: Double
    let signals: [String]
    let recommendation: String
}

struct IndicatorSettings {
    var showSMA20: Bool = true
    var showSMA50: Bool = true
    var showEMA12: Bool = true
    var showEMA26: Bool = true
    var showMACD: Bool = true
    var showRSI: Bool = true
    var showBollinger: Bool = true
}

struct CachedData: Codable {
    let price: Double
    let change24h: Double
    let chartPrices: [[Double]]
    let timestamp: Date
}

class CacheManager {
    static let shared = CacheManager()
    private let cachePath: String
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let cacheDir = appSupport.appendingPathComponent("BTCWidget")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        cachePath = cacheDir.appendingPathComponent("cache.json").path
    }
    
    func save(_ data: CachedData) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let json = try encoder.encode(data)
            try json.write(to: URL(fileURLWithPath: cachePath))
        } catch {
            print("Cache save error: \(error)")
        }
    }
    
    func load() -> CachedData? {
        guard FileManager.default.fileExists(atPath: cachePath) else { return nil }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: cachePath))
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(CachedData.self, from: data)
        } catch {
            print("Cache load error: \(error)")
            return nil
        }
    }
    
    func isCacheValid(maxAge: TimeInterval = 3600) -> Bool {
        guard let cache = load() else { return false }
        return Date().timeIntervalSince(cache.timestamp) < maxAge
    }
}

class TechnicalAnalyzer {
    
    static func calculateSMA(prices: [Double], period: Int) -> [Double?] {
        guard prices.count >= period else { return Array(repeating: nil, count: prices.count) }
        
        var sma: [Double?] = Array(repeating: nil, count: period - 1)
        
        for i in (period - 1)..<prices.count {
            let slice = prices[(i - period + 1)...i]
            let avg = slice.reduce(0, +) / Double(period)
            sma.append(avg)
        }
        return sma
    }
    
    static func calculateEMA(prices: [Double], period: Int) -> [Double?] {
        guard prices.count >= period else { return Array(repeating: nil, count: prices.count) }
        
        var ema: [Double?] = Array(repeating: nil, count: period - 1)
        let multiplier = 2.0 / Double(period + 1)
        
        let initialSMA = prices[0..<period].reduce(0, +) / Double(period)
        ema.append(initialSMA)
        
        for i in period..<prices.count {
            if let prevEMA = ema[i - 1] {
                let currentEMA = (prices[i] - prevEMA) * multiplier + prevEMA
                ema.append(currentEMA)
            }
        }
        return ema
    }
    
    static func calculateMACD(prices: [Double]) -> (macd: [Double?], signal: [Double?], histogram: [Double?]) {
        let ema12 = calculateEMA(prices: prices, period: 12)
        let ema26 = calculateEMA(prices: prices, period: 26)
        
        var macdLine: [Double?] = []
        for i in 0..<prices.count {
            if let e12 = ema12[i], let e26 = ema26[i] {
                macdLine.append(e12 - e26)
            } else {
                macdLine.append(nil)
            }
        }
        
        let macdValues = macdLine.compactMap { $0 }
        let signalLine = calculateEMA(prices: macdValues, period: 9)
        
        var fullSignal: [Double?] = Array(repeating: nil, count: prices.count)
        var signalIndex = 0
        for i in 0..<prices.count {
            if macdLine[i] != nil {
                fullSignal[i] = signalLine[signalIndex]
                signalIndex += 1
            }
        }
        
        var histogram: [Double?] = []
        for i in 0..<prices.count {
            if let macd = macdLine[i], let signal = fullSignal[i] {
                histogram.append(macd - signal)
            } else {
                histogram.append(nil)
            }
        }
        
        return (macdLine, fullSignal, histogram)
    }
    
    static func calculateRSI(prices: [Double], period: Int = 14) -> [Double?] {
        guard prices.count > period else { return Array(repeating: nil, count: prices.count) }
        
        var rsi: [Double?] = Array(repeating: nil, count: period)
        
        var gains: [Double] = []
        var losses: [Double] = []
        
        for i in 1..<prices.count {
            let change = prices[i] - prices[i - 1]
            gains.append(max(0, change))
            losses.append(max(0, -change))
        }
        
        guard gains.count >= period else { return rsi }
        
        var avgGain = gains[0..<period].reduce(0, +) / Double(period)
        var avgLoss = losses[0..<period].reduce(0, +) / Double(period)
        
        if avgLoss == 0 {
            rsi.append(100)
        } else {
            let rs = avgGain / avgLoss
            rsi.append(100 - (100 / (1 + rs)))
        }
        
        for i in period..<gains.count {
            avgGain = (avgGain * Double(period - 1) + gains[i]) / Double(period)
            avgLoss = (avgLoss * Double(period - 1) + losses[i]) / Double(period)
            
            if avgLoss == 0 {
                rsi.append(100)
            } else {
                let rs = avgGain / avgLoss
                rsi.append(100 - (100 / (1 + rs)))
            }
        }
        
        return rsi
    }
    
    static func calculateBollingerBands(prices: [Double], period: Int = 20, stdDev: Double = 2.0) -> (upper: [Double?], middle: [Double?], lower: [Double?]) {
        let sma = calculateSMA(prices: prices, period: period)
        
        var upper: [Double?] = []
        var lower: [Double?] = []
        var middle: [Double?] = []
        
        for i in 0..<prices.count {
            guard let smaValue = sma[i], i >= period - 1 else {
                upper.append(nil)
                lower.append(nil)
                middle.append(nil)
                continue
            }
            
            let slice = Array(prices[(i - period + 1)...i])
            let variance = slice.map { pow($0 - smaValue, 2) }.reduce(0, +) / Double(period)
            let std = sqrt(variance)
            
            middle.append(smaValue)
            upper.append(smaValue + stdDev * std)
            lower.append(smaValue - stdDev * std)
        }
        
        return (upper, middle, lower)
    }
    
    static func analyze(prices: [PriceData], indicators: ChartIndicators) -> AnalysisResult {
        var signals: [String] = []
        var confidenceScore: Double = 0
        var trendIndicators: [String] = []
        
        guard let currentPrice = prices.last?.price,
              let sma20 = indicators.sma20,
              let sma50 = indicators.sma50,
              let ema12 = indicators.ema12,
              let ema26 = indicators.ema26,
              let rsi = indicators.rsi else {
            return AnalysisResult(trend: "Unknown", confidence: 0, signals: [], recommendation: "Insufficient data")
        }
        
        if currentPrice > sma20 {
            signals.append("✅ Price above SMA20")
            trendIndicators.append("bullish")
        } else {
            signals.append("🔻 Price below SMA20")
            trendIndicators.append("bearish")
        }
        
        if sma20 > sma50 {
            signals.append("✅ SMA20 above SMA50 (Golden Cross)")
            trendIndicators.append("bullish")
        } else {
            signals.append("🔻 SMA20 below SMA50 (Death Cross)")
            trendIndicators.append("bearish")
        }
        
        if ema12 > ema26 {
            signals.append("✅ Short EMA above Long EMA")
            trendIndicators.append("bullish")
        } else {
            signals.append("🔻 Short EMA below Long EMA")
            trendIndicators.append("bearish")
        }
        
        if let macdHist = indicators.macdHistogram {
            if macdHist > 0 {
                signals.append("✅ MACD Histogram Positive (Bullish Momentum)")
                trendIndicators.append("bullish")
            } else {
                signals.append("🔻 MACD Histogram Negative (Bearish Momentum)")
                trendIndicators.append("bearish")
            }
        }
        
        if rsi > 70 {
            signals.append("⚠️ RSI Overbought (\(Int(rsi)))")
        } else if rsi < 30 {
            signals.append("⚡ RSI Oversold (\(Int(rsi)))")
        } else {
            signals.append("📊 RSI Neutral (\(Int(rsi)))")
        }
        
        if let upper = indicators.bollingerUpper, let lower = indicators.bollingerLower {
            let bandWidth = upper - lower
            let position = (currentPrice - lower) / bandWidth
            
            if position > 0.8 {
                signals.append("⚠️ Near Upper Bollinger Band (Overbought)")
            } else if position < 0.2 {
                signals.append("💡 Near Lower Bollinger Band (Oversold)")
            } else {
                signals.append("📊 Within Bollinger Bands")
            }
        }
        
        let bullishCount = trendIndicators.filter { $0 == "bullish" }.count
        let totalIndicators = trendIndicators.count
        
        if totalIndicators > 0 {
            confidenceScore = Double(bullishCount) / Double(totalIndicators) * 100
        }
        
        if rsi > 70 || rsi < 30 {
            confidenceScore *= 0.9
        }
        
        var trend: String
        var recommendation: String
        
        if confidenceScore >= 70 {
            trend = "Strong Uptrend 📈"
            recommendation = confidenceScore >= 80 ? "STRONG BUY" : "BUY"
        } else if confidenceScore >= 55 {
            trend = "Weak Uptrend ↗️"
            recommendation = "HOLD / ACCUMULATE"
        } else if confidenceScore >= 45 {
            trend = "Neutral ↔️"
            recommendation = "HOLD"
        } else if confidenceScore >= 30 {
            trend = "Weak Downtrend ↘️"
            recommendation = "HOLD / REDUCE"
        } else {
            trend = "Strong Downtrend 📉"
            recommendation = confidenceScore <= 20 ? "STRONG SELL" : "SELL"
        }
        
        return AnalysisResult(
            trend: trend,
            confidence: confidenceScore,
            signals: signals,
            recommendation: recommendation
        )
    }
}
