import AppKit

class ChartView: NSView {
    var priceData: [PriceData] = []
    var indicatorSettings = IndicatorSettings()
    
    override var isFlipped: Bool { false }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        NSColor(calibratedWhite: 0.12, alpha: 1.0).setFill()
        dirtyRect.fill()
        
        NSColor(calibratedWhite: 0.2, alpha: 1.0).setStroke()
        let borderPath = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5))
        borderPath.lineWidth = 1
        borderPath.stroke()
        
        let prices = priceData.map { $0.price }
        guard prices.count > 2 else {
            drawPlaceholder()
            return
        }
        
        let chartPoints = Array(prices.suffix(90))
        guard chartPoints.count > 2 else { return }
        
        let padding: CGFloat = 8
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
