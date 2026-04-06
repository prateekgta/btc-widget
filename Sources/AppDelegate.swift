import AppKit
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var priceLabel: NSTextField!
    var changeLabel: NSTextField!
    var timeLabel: NSTextField!
    var statusLabel: NSTextField!
    var chartView: ChartView!
    var analysisView: NSView!
    var trendLabel: NSTextField!
    var confidenceLabel: NSTextField!
    var recommendationLabel: NSTextField!
    var signalsTextView: NSTextView!
    
    var settingsWindow: NSWindow?
    var indicatorSettings = IndicatorSettings()
    
    var refreshTimer: Timer!
    var priceData: [PriceData] = []
    var indicators: ChartIndicators = ChartIndicators()
    var analysisResult: AnalysisResult?
    var isUsingCachedData: Bool = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        loadCachedData()
        setupWindow()
        setupMenu()
        fetchAllData()
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            self?.fetchAllData()
        }
    }
    
    func loadCachedData() {
        guard let cache = CacheManager.shared.load() else { return }
        
        let priceDatas = cache.chartPrices.compactMap { item -> PriceData? in
            guard item.count >= 2 else { return nil }
            return PriceData(timestamp: Date(timeIntervalSince1970: item[0] / 1000), price: item[1])
        }
        
        if !priceDatas.isEmpty {
            priceData = priceDatas
            calculateIndicators()
            isUsingCachedData = true
        }
    }
    
    func setupWindow() {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        
        window = NSWindow(
            contentRect: NSRect(x: screenFrame.maxX - 340, y: screenFrame.maxY - 580, width: 320, height: 560),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "BTC Widget"
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 320, height: 560)
        window.maxSize = NSSize(width: 500, height: 800)
        
        guard let contentView = window.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor(calibratedWhite: 0.1, alpha: 1.0).cgColor
        contentView.layer?.cornerRadius = 12
        
        setupPriceSection(in: contentView)
        setupChartSection(in: contentView)
        setupAnalysisSection(in: contentView)
        setupIndicatorsLegend(in: contentView)
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        if isUsingCachedData {
            updateUIWithCachedData()
        }
    }
    
    func setupPriceSection(in contentView: NSView) {
        let headerLabel = NSTextField(labelWithString: "Bitcoin (BTC)")
        headerLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        headerLabel.textColor = .gray
        headerLabel.frame = NSRect(x: 20, y: 510, width: 200, height: 20)
        contentView.addSubview(headerLabel)
        
        let refreshBtn = NSButton(frame: NSRect(x: 230, y: 505, width: 28, height: 28))
        refreshBtn.title = "🔄"
        refreshBtn.bezelStyle = .regularSquare
        refreshBtn.isBordered = false
        refreshBtn.target = self
        refreshBtn.action = #selector(refreshData)
        refreshBtn.toolTip = "Refresh Data"
        contentView.addSubview(refreshBtn)
        
        let settingsBtn = NSButton(frame: NSRect(x: 262, y: 505, width: 28, height: 28))
        settingsBtn.title = "⚙️"
        settingsBtn.bezelStyle = .regularSquare
        settingsBtn.isBordered = false
        settingsBtn.target = self
        settingsBtn.action = #selector(openSettings)
        settingsBtn.toolTip = "Settings"
        contentView.addSubview(settingsBtn)
        
        priceLabel = NSTextField(labelWithString: "Loading...")
        priceLabel.font = NSFont.boldSystemFont(ofSize: 36)
        priceLabel.textColor = NSColor(calibratedRed: 0.97, green: 0.58, blue: 0.04, alpha: 1.0)
        priceLabel.alignment = .left
        priceLabel.frame = NSRect(x: 15, y: 465, width: 290, height: 45)
        contentView.addSubview(priceLabel)
        
        changeLabel = NSTextField(labelWithString: "24h: --")
        changeLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        changeLabel.textColor = .white
        changeLabel.alignment = .left
        changeLabel.frame = NSRect(x: 15, y: 438, width: 290, height: 25)
        contentView.addSubview(changeLabel)
        
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = NSFont.systemFont(ofSize: 10)
        statusLabel.textColor = .systemOrange
        statusLabel.alignment = .left
        statusLabel.frame = NSRect(x: 15, y: 418, width: 290, height: 15)
        statusLabel.isHidden = true
        contentView.addSubview(statusLabel)
        
        timeLabel = NSTextField(labelWithString: "Loading data...")
        timeLabel.font = NSFont.systemFont(ofSize: 10)
        timeLabel.textColor = .gray
        timeLabel.alignment = .left
        timeLabel.frame = NSRect(x: 15, y: 418, width: 290, height: 15)
        contentView.addSubview(timeLabel)
    }
    
    func setupChartSection(in contentView: NSView) {
        chartView = ChartView(frame: NSRect(x: 15, y: 195, width: 290, height: 160))
        chartView.wantsLayer = true
        chartView.layer?.cornerRadius = 6
        chartView.layer?.masksToBounds = true
        chartView.layer?.borderWidth = 1
        chartView.layer?.borderColor = NSColor(calibratedWhite: 0.25, alpha: 1.0).cgColor
        
        contentView.addSubview(chartView)
    }
    
    func setupAnalysisSection(in contentView: NSView) {
        let analysisHeader = NSTextField(labelWithString: "📊 Trend Analysis")
        analysisHeader.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        analysisHeader.textColor = .white
        analysisHeader.frame = NSRect(x: 15, y: 175, width: 290, height: 20)
        contentView.addSubview(analysisHeader)
        
        trendLabel = NSTextField(labelWithString: "Analyzing...")
        trendLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        trendLabel.textColor = .white
        trendLabel.frame = NSRect(x: 15, y: 148, width: 200, height: 22)
        contentView.addSubview(trendLabel)
        
        recommendationLabel = NSTextField(labelWithString: "")
        recommendationLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        recommendationLabel.textColor = NSColor.systemGreen
        recommendationLabel.frame = NSRect(x: 215, y: 148, width: 90, height: 22)
        recommendationLabel.alignment = .right
        contentView.addSubview(recommendationLabel)
        
        confidenceLabel = NSTextField(labelWithString: "Confidence: --%")
        confidenceLabel.font = NSFont.systemFont(ofSize: 10)
        confidenceLabel.textColor = .gray
        confidenceLabel.frame = NSRect(x: 15, y: 125, width: 290, height: 18)
        contentView.addSubview(confidenceLabel)
        
        let separatorLine = NSBox(frame: NSRect(x: 15, y: 115, width: 290, height: 1))
        separatorLine.boxType = .separator
        contentView.addSubview(separatorLine)
        
        let scrollView = NSScrollView(frame: NSRect(x: 15, y: 15, width: 290, height: 95))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 1.0)
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 6
        
        signalsTextView = NSTextView(frame: NSRect(x: 0, y: 0, width: 275, height: 200))
        signalsTextView.isEditable = false
        signalsTextView.isSelectable = true
        signalsTextView.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 1.0)
        signalsTextView.textColor = .white
        signalsTextView.font = NSFont.systemFont(ofSize: 10)
        scrollView.documentView = signalsTextView
        
        contentView.addSubview(scrollView)
    }
    
    func setupIndicatorsLegend(in contentView: NSView) {
        // Legend removed to fix layout
    }
    
    func setupMenu() {
        let mainMenu = NSMenu()
        
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        
        appMenu.addItem(withTitle: "About BTC Widget", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        appMenu.addItem(withTitle: "Refresh Now", action: #selector(refreshData), keyEquivalent: "r")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit BTC Widget", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        NSApp.mainMenu = mainMenu
    }
    
    @objc func openSettings() {
        if settingsWindow != nil {
            settingsWindow?.makeKeyAndOrderFront(nil)
            return
        }
        
        settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        settingsWindow?.title = "Indicator Settings"
        settingsWindow?.level = .floating
        
        guard let contentView = settingsWindow?.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor(calibratedWhite: 0.15, alpha: 1.0).cgColor
        
        let header = NSTextField(labelWithString: "Select Indicators to Display")
        header.font = NSFont.boldSystemFont(ofSize: 14)
        header.textColor = .white
        header.frame = NSRect(x: 20, y: 240, width: 260, height: 25)
        contentView.addSubview(header)
        
        let indicators: [(String, String, Int)] = [
            ("SMA (20-day)", "sma20", 0),
            ("SMA (50-day)", "sma50", 1),
            ("EMA (12-day)", "ema12", 2),
            ("EMA (26-day)", "ema26", 3),
            ("MACD", "macd", 4),
            ("RSI (14-day)", "rsi", 5),
            ("Bollinger Bands", "bollinger", 6)
        ]
        
        var yOffset: CGFloat = 200
        for (title, _, tag) in indicators {
            let checkbox = NSButton(checkboxWithTitle: title, target: self, action: #selector(settingChanged(_:)))
            checkbox.tag = tag
            switch tag {
            case 0: checkbox.state = indicatorSettings.showSMA20 ? .on : .off
            case 1: checkbox.state = indicatorSettings.showSMA50 ? .on : .off
            case 2: checkbox.state = indicatorSettings.showEMA12 ? .on : .off
            case 3: checkbox.state = indicatorSettings.showEMA26 ? .on : .off
            case 4: checkbox.state = indicatorSettings.showMACD ? .on : .off
            case 5: checkbox.state = indicatorSettings.showRSI ? .on : .off
            case 6: checkbox.state = indicatorSettings.showBollinger ? .on : .off
            default: break
            }
            checkbox.frame = NSRect(x: 20, y: yOffset, width: 260, height: 22)
            checkbox.contentTintColor = .white
            contentView.addSubview(checkbox)
            yOffset -= 30
        }
        
        let closeBtn = NSButton(title: "Close", target: self, action: #selector(closeSettings))
        closeBtn.bezelStyle = .rounded
        closeBtn.frame = NSRect(x: 110, y: 15, width: 80, height: 30)
        contentView.addSubview(closeBtn)
        
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    
    @objc func settingChanged(_ sender: NSButton) {
        switch sender.tag {
        case 0: indicatorSettings.showSMA20 = sender.state == .on
        case 1: indicatorSettings.showSMA50 = sender.state == .on
        case 2: indicatorSettings.showEMA12 = sender.state == .on
        case 3: indicatorSettings.showEMA26 = sender.state == .on
        case 4: indicatorSettings.showMACD = sender.state == .on
        case 5: indicatorSettings.showRSI = sender.state == .on
        case 6: indicatorSettings.showBollinger = sender.state == .on
        default: break
        }
        renderChart()
    }
    
    @objc func closeSettings() {
        settingsWindow?.close()
        settingsWindow = nil
    }
    
    @objc func refreshData() {
        statusLabel.stringValue = "🔄 Fetching latest data..."
        statusLabel.isHidden = false
        fetchAllData()
    }
    
    func fetchAllData() {
        fetchBTCPrice()
        fetchBTCData(days: 90)
    }
    
    func fetchBTCPrice() {
        guard let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_change=true") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
                DispatchQueue.main.async {
                    self?.showRateLimitWarning()
                }
                return
            }
            
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    self?.loadCachedPrice()
                }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let btc = json["bitcoin"] as? [String: Any],
                   let price = btc["usd"] as? Double,
                   let change = btc["usd_24h_change"] as? Double {
                    
                    DispatchQueue.main.async {
                        self?.updatePriceDisplay(price: price, change: change, fromCache: false)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.loadCachedPrice()
                }
            }
        }.resume()
    }
    
    func showRateLimitWarning() {
        statusLabel.stringValue = "⚠️ Rate limited - using cached data"
        statusLabel.isHidden = false
        loadCachedPrice()
    }
    
    func loadCachedPrice() {
        guard let cache = CacheManager.shared.load() else {
            statusLabel.stringValue = "No cached data available"
            statusLabel.isHidden = false
            return
        }
        
        updatePriceDisplay(price: cache.price, change: cache.change24h, fromCache: true)
        
        let priceDatas = cache.chartPrices.compactMap { item -> PriceData? in
            guard item.count >= 2 else { return nil }
            return PriceData(timestamp: Date(timeIntervalSince1970: item[0] / 1000), price: item[1])
        }
        
        if !priceDatas.isEmpty {
            priceData = priceDatas
            calculateIndicators()
            performAnalysis()
            renderChart()
        }
    }
    
    func updatePriceDisplay(price: Double, change: Double, fromCache: Bool) {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let priceStr = formatter.string(from: NSNumber(value: price)) ?? "$\(price)"
        
        priceLabel.stringValue = priceStr
        changeLabel.stringValue = String(format: "24h: %+.2f%%", change)
        changeLabel.textColor = change >= 0 ? .systemGreen : .systemRed
        
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        
        if fromCache, let cache = CacheManager.shared.load() {
            let cacheTime = df.string(from: cache.timestamp)
            timeLabel.stringValue = "Updated: \(cacheTime) (cached)"
            statusLabel.stringValue = "📦 Showing cached data from \(cacheTime)"
            statusLabel.isHidden = false
        } else {
            timeLabel.stringValue = "Updated: \(df.string(from: Date())) • 30min"
            statusLabel.isHidden = true
        }
    }
    
    func updateUIWithCachedData() {
        guard let cache = CacheManager.shared.load() else { return }
        updatePriceDisplay(price: cache.price, change: cache.change24h, fromCache: true)
        renderChart()
    }
    
    func fetchBTCData(days: Int) {
        guard let url = URL(string: "https://api.coingecko.com/api/v3/coins/bitcoin/market_chart?vs_currency=usd&days=\(days)") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
                DispatchQueue.main.async {
                    self?.loadCachedChartData()
                }
                return
            }
            
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    self?.loadCachedChartData()
                }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let prices = json["prices"] as? [[Double]] {
                    
                    print("DEBUG: Fetched prices count: \(prices.count)")
                    
                    let priceData = prices.compactMap { item -> PriceData? in
                        guard item.count >= 2 else { return nil }
                        return PriceData(timestamp: Date(timeIntervalSince1970: item[0] / 1000), price: item[1])
                    }
                    
                    print("DEBUG: Parsed priceData count: \(priceData.count)")
                    
                    DispatchQueue.main.async {
                        self?.priceData = priceData
                        self?.calculateIndicators()
                        self?.performAnalysis()
                        self?.renderChart()
                        self?.saveToCache(prices: prices)
                        self?.statusLabel.isHidden = true
                        print("DEBUG: UI updated with \(priceData.count) data points")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.loadCachedChartData()
                }
            }
        }.resume()
    }
    
    func loadCachedChartData() {
        print("DEBUG: loadCachedChartData called")
        guard let cache = CacheManager.shared.load() else { 
            print("DEBUG: No cache found")
            return 
        }
        
        print("DEBUG: Cache found, prices count: \(cache.chartPrices.count)")
        
        let priceDatas = cache.chartPrices.compactMap { item -> PriceData? in
            guard item.count >= 2 else { return nil }
            return PriceData(timestamp: Date(timeIntervalSince1970: item[0] / 1000), price: item[1])
        }
        
        print("DEBUG: Parsed priceData count: \(priceDatas.count)")
        
        if !priceDatas.isEmpty {
            priceData = priceDatas
            calculateIndicators()
            performAnalysis()
            renderChart()
        }
    }
    
    func saveToCache(prices: [[Double]]) {
        guard let lastPrice = prices.last?.last else { return }
        
        let change24h: Double = {
            if prices.count >= 24 {
                let oldPrice = prices[prices.count - 24][1]
                return ((lastPrice - oldPrice) / oldPrice) * 100
            }
            return 0
        }()
        
        let cache = CachedData(price: lastPrice, change24h: change24h, chartPrices: prices, timestamp: Date())
        CacheManager.shared.save(cache)
    }
    
    func calculateIndicators() {
        let prices = priceData.map { $0.price }
        guard prices.count > 50 else { return }
        
        let sma20 = TechnicalAnalyzer.calculateSMA(prices: prices, period: 20)
        let sma50 = TechnicalAnalyzer.calculateSMA(prices: prices, period: 50)
        let ema12 = TechnicalAnalyzer.calculateEMA(prices: prices, period: 12)
        let ema26 = TechnicalAnalyzer.calculateEMA(prices: prices, period: 26)
        let macdData = TechnicalAnalyzer.calculateMACD(prices: prices)
        let rsi = TechnicalAnalyzer.calculateRSI(prices: prices)
        let bollinger = TechnicalAnalyzer.calculateBollingerBands(prices: prices)
        
        indicators = ChartIndicators(
            sma20: sma20.last ?? nil,
            sma50: sma50.last ?? nil,
            ema12: ema12.last ?? nil,
            ema26: ema26.last ?? nil,
            macd: macdData.macd.last ?? nil,
            macdSignal: macdData.signal.last ?? nil,
            macdHistogram: macdData.histogram.last ?? nil,
            rsi: rsi.last ?? nil,
            bollingerUpper: bollinger.upper.last ?? nil,
            bollingerLower: bollinger.lower.last ?? nil,
            bollingerMiddle: bollinger.middle.last ?? nil
        )
    }
    
    func performAnalysis() {
        analysisResult = TechnicalAnalyzer.analyze(prices: priceData, indicators: indicators)
        
        guard let result = analysisResult else { return }
        
        trendLabel.stringValue = result.trend
        confidenceLabel.stringValue = "Confidence: \(Int(result.confidence))%"
        
        recommendationLabel.stringValue = result.recommendation
        if result.recommendation.contains("BUY") {
            recommendationLabel.textColor = NSColor.systemGreen
        } else if result.recommendation.contains("SELL") {
            recommendationLabel.textColor = NSColor.systemRed
        } else {
            recommendationLabel.textColor = NSColor.systemYellow
        }
        
        let signalsText = result.signals.joined(separator: "\n")
        signalsTextView.string = signalsText.isEmpty ? "Analyzing..." : signalsText
    }
    
    func renderChart() {
        print("DEBUG AppDelegate: renderChart called, priceData count: \(priceData.count)")
        chartView.updateChart(with: priceData, settings: indicatorSettings)
        print("DEBUG AppDelegate: chartView bounds: \(chartView.bounds)")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
