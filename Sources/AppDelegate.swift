import AppKit
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var priceLabel: NSTextField!
    var changeLabel: NSTextField!
    var timeLabel: NSTextField!
    var chartView: NSImageView!
    var refreshTimer: Timer!
    var chartTimer: Timer!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupWindow()
        setupMenu()
        fetchBTCPrice()
        fetchBTCChart()
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            self?.fetchBTCPrice()
        }
        
        chartTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            self?.fetchBTCChart()
        }
    }
    
    func setupWindow() {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        
        window = NSWindow(
            contentRect: NSRect(x: screenFrame.maxX - 280, y: screenFrame.maxY - 320, width: 260, height: 300),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "BTC Widget"
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible
        
        guard let contentView = window.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 1.0).cgColor
        contentView.layer?.cornerRadius = 12
        
        let headerLabel = NSTextField(labelWithString: "Bitcoin Price")
        headerLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        headerLabel.textColor = .gray
        headerLabel.frame = NSRect(x: 20, y: 255, width: 220, height: 20)
        headerLabel.alignment = .center
        contentView.addSubview(headerLabel)
        
        priceLabel = NSTextField(labelWithString: "Loading...")
        priceLabel.font = NSFont.boldSystemFont(ofSize: 32)
        priceLabel.textColor = NSColor(calibratedRed: 0.97, green: 0.58, blue: 0.04, alpha: 1.0)
        priceLabel.alignment = .center
        priceLabel.frame = NSRect(x: 10, y: 205, width: 240, height: 45)
        contentView.addSubview(priceLabel)
        
        changeLabel = NSTextField(labelWithString: "24h: --")
        changeLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        changeLabel.textColor = .white
        changeLabel.alignment = .center
        changeLabel.frame = NSRect(x: 10, y: 175, width: 240, height: 25)
        contentView.addSubview(changeLabel)
        
        chartView = NSImageView(frame: NSRect(x: 15, y: 35, width: 230, height: 130))
        chartView.imageScaling = .scaleProportionallyUpOrDown
        chartView.wantsLayer = true
        chartView.layer?.cornerRadius = 8
        chartView.layer?.masksToBounds = true
        chartView.layer?.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 1.0).cgColor
        contentView.addSubview(chartView)
        
        timeLabel = NSTextField(labelWithString: "Updating...")
        timeLabel.font = NSFont.systemFont(ofSize: 10)
        timeLabel.textColor = .gray
        timeLabel.alignment = .center
        timeLabel.frame = NSRect(x: 10, y: 10, width: 240, height: 20)
        contentView.addSubview(timeLabel)
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func setupMenu() {
        let mainMenu = NSMenu()
        
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        
        appMenu.addItem(withTitle: "About BTC Widget", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Refresh Now", action: #selector(refreshData), keyEquivalent: "r")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit BTC Widget", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        NSApp.mainMenu = mainMenu
    }
    
    @objc func refreshData() {
        fetchBTCPrice()
        fetchBTCChart()
    }
    
    func fetchBTCPrice() {
        guard let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_change=true") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let btc = json["bitcoin"] as? [String: Any],
                   let price = btc["usd"] as? Double,
                   let change = btc["usd_24h_change"] as? Double {
                    
                    DispatchQueue.main.async {
                        let formatter = NumberFormatter()
                        formatter.numberStyle = .currency
                        formatter.currencyCode = "USD"
                        let priceStr = formatter.string(from: NSNumber(value: price)) ?? "$\(price)"
                        
                        self?.priceLabel.stringValue = priceStr
                        self?.changeLabel.stringValue = String(format: "24h: %+.2f%%", change)
                        self?.changeLabel.textColor = change >= 0 ? .systemGreen : .systemRed
                        
                        let df = DateFormatter()
                        df.dateFormat = "HH:mm"
                        self?.timeLabel.stringValue = "Updated: \(df.string(from: Date())) • Auto-refresh 30min"
                    }
                }
            } catch {
                print("Parse error: \(error)")
            }
        }.resume()
    }
    
    func fetchBTCChart() {
        guard let url = URL(string: "https://api.coingecko.com/api/v3/coins/bitcoin/market_chart?vs_currency=usd&days=7") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let prices = json["prices"] as? [[Double]] {
                    
                    DispatchQueue.main.async {
                        self?.renderChart(prices: prices)
                    }
                }
            } catch {
                print("Chart parse error: \(error)")
            }
        }.resume()
    }
    
    func renderChart(prices: [[Double]]) {
        let width: CGFloat = 230
        let height: CGFloat = 130
        let padding: CGFloat = 10
        
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                            pixelsWide: Int(width),
                                            pixelsHigh: Int(height),
                                            bitsPerSample: 8,
                                            samplesPerPixel: 4,
                                            hasAlpha: true,
                                            isPlanar: false,
                                            colorSpaceName: .deviceRGB,
                                            bytesPerRow: 0,
                                            bitsPerPixel: 0) else { return }
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        
        NSColor(calibratedWhite: 0.08, alpha: 1.0).setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        
        guard prices.count > 1 else { return }
        
        let values = prices.map { $0[1] }
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 1
        let range = maxVal - minVal
        
        let path = NSBezierPath()
        let chartWidth = width - 2 * padding
        let chartHeight = height - 2 * padding
        let step = chartWidth / CGFloat(prices.count - 1)
        
        for (index, price) in prices.enumerated() {
            let x = padding + CGFloat(index) * step
            let normalizedY = range > 0 ? (price[1] - minVal) / range : 0.5
            let y = padding + CGFloat(normalizedY) * chartHeight
            
            if index == 0 {
                path.move(to: NSPoint(x: x, y: y))
            } else {
                path.line(to: NSPoint(x: x, y: y))
            }
        }
        
        NSColor(calibratedRed: 0.97, green: 0.58, blue: 0.04, alpha: 1.0).setStroke()
        path.lineWidth = 2
        path.stroke()
        
        let fillPath = path.copy() as! NSBezierPath
        fillPath.line(to: NSPoint(x: padding + CGFloat(prices.count - 1) * step, y: padding))
        fillPath.line(to: NSPoint(x: padding, y: padding))
        fillPath.close()
        
        NSColor(calibratedRed: 0.97, green: 0.58, blue: 0.04, alpha: 0.2).setFill()
        fillPath.fill()
        
        NSGraphicsContext.restoreGraphicsState()
        
        let image = NSImage(size: NSSize(width: width, height: height))
        image.addRepresentation(bitmap)
        chartView.image = image
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
