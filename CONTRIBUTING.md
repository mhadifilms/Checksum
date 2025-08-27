# Contributing to Checksum

Thank you for your interest in contributing to Checksum! This document provides guidelines and information for contributors.

## 🤝 How to Contribute

### Reporting Bugs

- Use the [GitHub issue tracker](https://github.com/yourusername/checksum/issues)
- Include detailed steps to reproduce the bug
- Provide system information (macOS version, app version)
- Include screenshots or logs if relevant

### Suggesting Features

- Open a [GitHub discussion](https://github.com/yourusername/checksum/discussions)
- Describe the feature and its use case
- Consider if it aligns with the app's core purpose

### Code Contributions

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Make your changes**
4. **Add tests** for new functionality
5. **Commit your changes**: `git commit -m 'Add amazing feature'`
6. **Push to the branch**: `git push origin feature/amazing-feature`
7. **Open a Pull Request**

## 🏗️ Development Setup

### Prerequisites

- macOS 14.0 or later
- Xcode 15.0 or later
- Swift 6.1 or later

### Getting Started

```bash
# Clone your fork
git clone https://github.com/yourusername/checksum.git
cd checksum

# Add upstream remote
git remote add upstream https://github.com/originalusername/checksum.git

# Build the project
swift build

# Run tests
swift test

# Open in Xcode
open Package.swift
```

### Project Structure

```
Checksum/
├── Sources/
│   ├── ChecksumKit/          # Core library
│   ├── ChecksumApp/          # SwiftUI macOS app
│   └── checksum/             # CLI tool
├── Tests/                    # Unit tests
├── AppStore/                 # App Store metadata
└── Package.swift             # Package configuration
```

## 📝 Coding Standards

### Swift Style

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use SwiftLint for consistent formatting
- Prefer Swift Concurrency (async/await) over completion handlers
- Use `@MainActor` for UI updates

### Architecture

- Keep the core library (`ChecksumKit`) independent of UI
- Use MVVM pattern in the SwiftUI app
- Prefer composition over inheritance
- Write testable code with dependency injection

### Testing

- Aim for >80% code coverage
- Test both success and failure scenarios
- Mock external dependencies
- Use descriptive test names

## 🚀 Building for Distribution

### Development Build

```bash
swift build -c debug --product Checksum
.build/debug/Checksum
```

### Release Build

```bash
swift build -c release --product Checksum
.build/release/Checksum
```

### App Store Build

```bash
# Open in Xcode
open Package.swift

# Archive the project
# Product → Archive
```

## 📋 Pull Request Guidelines

### Before Submitting

- [ ] Code compiles without warnings
- [ ] All tests pass
- [ ] New functionality has tests
- [ ] Code follows style guidelines
- [ ] Documentation is updated
- [ ] Commit messages are clear and descriptive

### PR Description

- Describe what the PR accomplishes
- Link related issues
- Include screenshots for UI changes
- Mention any breaking changes

## 🐛 Debugging

### Common Issues

- **Build errors**: Clean build folder and rebuild
- **Runtime crashes**: Check entitlements and sandbox settings
- **UI issues**: Verify @MainActor usage

### Debug Tools

- Use Xcode's built-in debugger
- Enable logging in `CloneViewModel`
- Check Console.app for system logs

## 📚 Resources

- [Swift Documentation](https://swift.org/documentation/)
- [SwiftUI Guide](https://developer.apple.com/xcode/swiftui/)
- [macOS App Programming Guide](https://developer.apple.com/macos/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

## 🎯 Areas for Contribution

### High Priority

- Performance optimization
- Additional hash algorithms (SHA-256, SHA-512)
- Better error handling and recovery
- Accessibility improvements

### Medium Priority

- Additional file formats support
- Batch operations
- Advanced scheduling
- Cloud storage integration

### Low Priority

- Themes and customization
- Localization
- Advanced statistics
- Integration with other tools

## 📞 Getting Help

- **Issues**: [GitHub Issues](https://github.com/yourusername/checksum/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/checksum/discussions)
- **Code Review**: Tag maintainers in PRs

## 🙏 Recognition

Contributors will be recognized in:
- README.md contributors section
- App Store credits
- Release notes
- GitHub contributors page

---

Thank you for contributing to Checksum! 🚀
