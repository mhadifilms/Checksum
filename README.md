# Checksum

A fast, reliable macOS application for cloning and verifying files with MD5 checksums. Built with SwiftUI and designed for macOS 14+.

![Checksum App](https://img.shields.io/badge/macOS-14+-000000?style=for-the-badge&logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-6.1-orange.svg?style=for-the-badge&logo=swift)
![License](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)

## ✨ Features

- **MD5 Verification**: Ensures file integrity during copying with streaming MD5 hashing
- **Multi-Source/Destination**: Copy files and folders to multiple locations simultaneously
- **Drag & Drop**: Intuitive drag-and-drop interface for easy file selection
- **Progress Tracking**: Real-time progress with accurate time estimates
- **Job History**: Track and reload previous copy operations
- **Modern UI**: Beautiful, native macOS design with liquid glass effects
- **High Performance**: Optimized for speed with concurrent file operations

## 🎯 Use Cases

- **Content Creators**: Safely copy footage from SD cards to multiple drives
- **Developers**: Verify file integrity during deployments
- **System Administrators**: Reliable file transfers with verification
- **Anyone**: Replace unreliable Finder copying with verified alternatives

## 🚀 Getting Started

### Prerequisites

- macOS 14.0 or later
- Xcode 15.0 or later (for development)

### Installation

#### Option 1: Download from Mac App Store
*Coming soon!*

#### Option 2: Build from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/checksum.git
cd checksum

# Build the application
swift build -c release --product Checksum

# Run the app
.build/release/Checksum
```

#### Option 3: Command Line Tool

```bash
# Build the CLI tool
swift build -c release --product checksum

# Use the CLI
.build/release/checksum --help
```

## 📱 Usage

### Basic Operation

1. **Add Sources**: Drag files/folders or click "Add Files or Folders"
2. **Add Destinations**: Select destination folders (files not allowed)
3. **Configure Options**: Choose whether to overwrite existing files
4. **Start Copying**: Click "Start" and monitor progress
5. **View History**: Access previous jobs via the history button

### Advanced Features

- **Concurrent Copying**: Multiple files copy simultaneously for speed
- **Progress Monitoring**: Real-time progress with ETA
- **Job Management**: Stop operations mid-copy if needed
- **Verification**: Every copied file is verified with MD5 checksums

## 🏗️ Architecture

```
Checksum/
├── Sources/
│   ├── ChecksumKit/          # Core library (hashing, verification)
│   ├── ChecksumApp/          # SwiftUI macOS application
│   └── checksum/             # Command-line interface
├── Tests/                    # Unit tests
└── Package.swift             # Swift Package Manager configuration
```

### Core Components

- **`CopyVerifier`**: Handles file copying with MD5 verification
- **`Planner`**: Manages multi-source/destination file operations
- **`CloneViewModel`**: App state management and business logic
- **`ContentView`**: Main SwiftUI interface

## 🧪 Testing

```bash
# Run all tests
swift test

# Run specific test target
swift test --target ChecksumKitTests
```

## 📦 Distribution

### Mac App Store Preparation

The project is configured for Mac App Store submission with:

- Proper code signing setup
- Sandbox entitlements
- App Store metadata
- Privacy descriptions

### Code Signing

```bash
# Build for distribution
xcodebuild -scheme Checksum -configuration Release archive
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes
4. Add tests for new functionality
5. Commit your changes: `git commit -m 'Add amazing feature'`
6. Push to the branch: `git push origin feature/amazing-feature`
7. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [SwiftUI](https://developer.apple.com/xcode/swiftui/)
- Uses [CryptoKit](https://developer.apple.com/documentation/cryptokit) for MD5 hashing
- Inspired by professional tools like DaVinci Resolve's clone functionality

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/checksum/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/checksum/discussions)
- **Email**: support@checksum.app

---

Made with ❤️ for the macOS community

