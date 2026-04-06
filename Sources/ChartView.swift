import AppKit

class ChartView: NSView {
    var priceData: [PriceData] = []
    var indicatorSettings = IndicatorSettings()
    
    override var isFlipped: Bool { false }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        NSColor(calibratedWhite: 0.12, alpha: 1.0).setFill()
        dirtyRect.fill()
        
        let axisPadding: CGFloat = 40
        let chartRect = bounds.insetBy(dx: axisPadding + 5, dy: axisPadding)
        
        let prices = priceData.map { $0.price }
        guard prices.count > 2 else {
            drawPlaceholder()
            return
        }
        
        let chartPoints = Array(prices.suffix(90))
        guard chartPoints.count > 2 else { return }
        
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
        
        let axisColor = NSColor(calibratedWhite: 0.5, alpha: 1.0)
        
        for i in 0...4 {
            let y = chartRect.minY + (chartRect.height / 4) * CGFloat(i)
            let value = maxVal - ((maxVal - minVal) / 4.0) * Double(i)
            
            let priceStr = formatter.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
            
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 8, weight: .regular),
                .foregroundColor: axisColor
            ]
            priceStr.draw(at: NSPoint(x: 2, y: y - 5), withAttributes: attrs)
            
            let gridPath = NSBezierPath()
            gridPath.move(to: NSPoint(x: chartRect.minX, y: y))
            gridPath.line(to: NSPoint(x: chartRect.maxX, y: y))
            NSColor(calibratedWhite: 0.15, alpha: 0.5).setStroke()
            gridPath.lineWidth = 0.5
            gridPath.stroke()
        }
    }
    
    func drawXAxis(chartRect: NSRect) {
        let chartPoints = Array(priceData.map { $0.timestamp }.suffix(90))
        guard chartPoints.count > 2 else { return }
        
        let axisColor = NSColor(calibratedWhite: 0.5, alpha: 1.0)
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        
        let positions = [0, chartPoints.count / 2, chartPoints.count - 1]
        
        for (index, pos) in positions.enumerated() {
            guard pos < chartPoints.count else { continue }
            let x = chartRect.minX + (chartRect.width / CGFloat(chartPoints.count - 1)) * CGFloat(pos)
            
            let dateStr: String
            if index == 0 {
                dateStr = formatter.string(from: chartPoints[pos])
            } else if index == 1 {
                dateStr = formatter.string(from: chartPoints[pos])
            } else {
                dateStr = formatter.string(from: chartPoints[pos])
            }
            
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 8, weight: .regular),
                .foregroundColor: axisColor
            ]
            let size = dateStr.size(withAttributes: attrs)
            dateStr.draw(at: NSPoint(x: x - size.width / 2, y: 2), withAttributes: attrs)
        }
    }
    
    func drawPlaceholder() {
        let text = "📊 Chart Loading..."
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
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
