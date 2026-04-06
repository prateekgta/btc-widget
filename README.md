# BTC Widget

A sleek macOS desktop widget that displays real-time Bitcoin prices with technical analysis. Updates automatically every 30 minutes.

![BTC Widget](https://img.shields.io/badge/macOS-12.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- Real-time Bitcoin price from CoinGecko API
- 24-hour price change indicator (green/red)
- Interactive price chart with multiple timeframes
- Technical indicators: SMA, EMA, MACD, RSI, Bollinger Bands
- Trend analysis with confidence score
- BUY/HOLD/SELL recommendations
- Auto-refresh every 30 minutes
- Floating window (stays on top)
- Works across all macOS spaces

## Quick Start

### One-Command Launch
```bash
btc
```

That's it! Just type `btc` in terminal and the widget opens instantly.

### First Time Setup (Run Once)
```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

The `btc` command will be available in all future terminal sessions.

## Installation

### From Source

```bash
# Clone the repository
git clone https://github.com/prateekgta/btc-widget.git
cd btc-widget

# Generate Xcode project
xcodegen generate

# Open in Xcode
open BTCWidget.xcodeproj

# Build and Run (Cmd+R)
```

### Manual Build

```bash
swiftc -o BTCWidget.app Sources/main.swift Sources/AppDelegate.swift Sources/TechnicalAnalysis.swift
open BTCWidget.app
```

### Install Shortcut

```bash
mkdir -p ~/bin
echo '#!/bin/bash
open "/FULL/PATH/TO/btc-widget/BTCWidget.app"' > ~/bin/btc
chmod +x ~/bin/btc
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
```

## Usage

1. Launch the app - a floating widget appears in the top-right corner
2. The widget shows:
   - Current BTC/USD price
   - 24-hour change percentage
   - 7-day price chart
3. Drag the widget anywhere on screen
4. Use **Cmd+R** to manually refresh
5. Use **Cmd+Q** or close button to quit

## Requirements

- macOS 12.0 (Monterey) or later
- Internet connection (for price data)

## API

Uses the free [CoinGecko API](https://www.coingecko.com/en/api) for Bitcoin price data.

## License

MIT License - See LICENSE file for details
