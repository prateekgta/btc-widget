import AppKit

class ChartView: NSView {
    var priceData: [PriceData] = []
    var indicatorSettings = IndicatorSettings()
    
    override var isFlipped: Bool { false }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        NSColor(calibratedWhite: 0.12, alpha: 1.0).setFill()
        bounds.fill()
        
        let prices = priceData.map { $0.price }
        guard prices.count > 2 else {
            drawPlaceholder()
            return
        }
        
        let chartPoints = Array(prices.suffix(90))
        guard chartPoints.count > 2 else { return }
        
        let padding: CGFloat = 30
        let chartRect = bounds.insetBy(dx: padding, dy: padding)
        
        let minVal = chartPoints.min()!
        let maxVal = chartPoints.max()!
        let range = maxVal - minVal
        
        let step = chartRect.width / CGFloat(chartPoints.count - 1)
        
        var points: [CGPoint] = []
        for i in 0..<chartPoints.count {
            let price = chartPoints[i]
            let x = chartRect.minX + CGFloat(i) * step
            let normalizedY = (price - minVal) / range
            let y = chartRect.minY + CGFloat(normalizedY) * chartRect.height
            points.append(CGPoint(x: x, y: y))
        }
        
        let linePath = NSBezierPath()
        linePath.move(to: points[0])
        for point in points.dropFirst() {
            linePath.line(to: point)
        }
        NSColor(calibratedRed: 0.97, green: 0.58, blue: 0.04, alpha: 1.0).setStroke()
        linePath.lineWidth = 2
        linePath.stroke()
        
        let fillPath = linePath.copy() as! NSBezierPath
        fillPath.line(to: CGPoint(x: points.last!.x, y: chartRect.minY))
        fillPath.line(to: CGPoint(x: points[0].x, y: chartRect.minY))
        fillPath.close()
        
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.97, green: 0.58, blue: 0.04, alpha: 0.3),
            NSColor(calibratedRed: 0.97, green: 0.58, blue: 0.04, alpha: 0.0)
        ])
        gradient?.draw(in: fillPath, angle: 90)
        
        drawYAxis(minVal: minVal, maxVal: maxVal, chartRect: chartRect)
        drawXAxis(chartRect: chartRect)
    }
    
    func drawYAxis(minVal: Double, maxVal: Double, chartRect: NSRect) {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 8, weight: .regular),
            .foregroundColor: NSColor(calibratedWhite: 0.6, alpha: 1.0)
        ]
        
        for i in 0...4 {
            let ratio = Double(i) / 4.0
            let value = maxVal - (maxVal - minVal) * ratio
            let y = chartRect.minY + chartRect.height * CGFloat(ratio)
            
            let priceStr = formatter.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
            priceStr.draw(at: NSPoint(x: 2, y: y - 5), withAttributes: attrs)
        }
    }
    
    func drawXAxis(chartRect: NSRect) {
        let timestamps = Array(priceData.map { $0.timestamp }.suffix(90))
        guard timestamps.count > 2 else { return }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 8, weight: .regular),
            .foregroundColor: NSColor(calibratedWhite: 0.6, alpha: 1.0)
        ]
        
        let startDate = formatter.string(from: timestamps.first!)
        let midDate = formatter.string(from: timestamps[timestamps.count / 2])
        let endDate = formatter.string(from: timestamps.last!)
        
        startDate.draw(at: NSPoint(x: chartRect.minX - 5, y: 2), withAttributes: attrs)
        
        let midX = chartRect.minX + chartRect.width / 2
        midDate.draw(at: NSPoint(x: midX - 12, y: 2), withAttributes: attrs)
        
        let endSize = endDate.size(withAttributes: attrs)
        endDate.draw(at: NSPoint(x: chartRect.maxX - endSize.width + 5, y: 2), withAttributes: attrs)
    }
    
    func drawPlaceholder() {
        let text = "📊 Chart"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor(calibratedWhite: 0.5, alpha: 1.0)
        ]
        let size = text.size(withAttributes: attrs)
        let point = NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
        text.draw(at: point, withAttributes: attrs)
    }
    
    func updateChart(with data: [PriceData], settings: IndicatorSettings) {
        priceData = data
        indicatorSettings = settings
        needsDisplay = true
    }
}
