# WolfBite 🐺

<p align="center">
    <img src="https://img.shields.io/badge/Flutter-3.9.2-02569B?logo=flutter&logoColor=white" alt="Flutter Version">
    <a href="https://github.com/SuyeshJadhav/CSC510_G19/actions/workflows/flutter-ci.yml">
        <img src="https://github.com/SuyeshJadhav/CSC510_G19/actions/workflows/flutter-ci.yml/badge.svg" alt="CI/CD Status">
    </a>
    <a href="https://suyeshjadhav.github.io/CSC510_G19/">
        <img src="https://img.shields.io/badge/docs-live-brightgreen?logo=github" alt="Documentation">
    </a>
    <a href="LICENSE.md">
        <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License">
    </a>
    <a href="https://doi.org/10.5281/zenodo.17538613">
        <img src="https://zenodo.org/badge/DOI/10.5281/zenodo.17538613.svg" alt="DOI">
    </a>
    <img src="https://img.shields.io/github/issues/SuyeshJadhav/CSC510_G19" alt="GitHub Issues">
    <img src="https://img.shields.io/github/stars/SuyeshJadhav/CSC510_G19?style=social" alt="GitHub Stars">
</p>

<p align="center">
    <strong>A modern food delivery application with WIC eligibility verification</strong>
</p>

<p align="center">
    <a href="#-features">Features</a> •
    <a href="#-quick-start">Quick Start</a> •
    <a href="#-documentation">Documentation</a> •
    <a href="#-contributing">Contributing</a> •
    <a href="#-license">License</a>
</p>

---

## 📖 About

**WolfBite** is a cross-platform food delivery application developed for the CSC510 Software Engineering course at NC State University. The app features an innovative barcode scanning system that helps users verify WIC (Women, Infants, and Children) product eligibility in real-time.

### Key Highlights

- 🔍 **Smart Scanning**: Real-time barcode scanning with WIC eligibility verification
- 🔐 **Secure Authentication**: Firebase-powered user authentication
- 🎨 **Modern UI**: Intuitive and responsive design

---

## ✨ Features

- **Barcode Scanner**: Scan product barcodes to check WIC eligibility instantly
- **User Authentication**: Secure sign-up and login with Firebase
- **Shopping Cart**: Add items and manage your cart seamlessly
- **Order Management**: Track your orders in real-time
- **Responsive Design**: Optimized for mobile and web platforms

---

## 🚀 Quick Start

### Prerequisites

Before you begin, ensure you have the following installed:

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.9.2 or higher)
- [Dart SDK](https://dart.dev/get-dart) (included with Flutter)
- [Git](https://git-scm.com/downloads)
- A code editor (VS Code, Android Studio, or IntelliJ IDEA recommended)

### Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/SuyeshJadhav/CSC510_G19.git
   cd CSC510_G19/Project2
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Configure Firebase** (if applicable)

   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Update Firebase configuration in the project

4. **Run the application**

   ```bash
   # For web
   flutter run -d chrome

   # For mobile (with device connected)
   flutter run

   # For specific platform
   flutter run -d <device_id>
   ```

5. **Build for production**

   ```bash
   # Android APK
   flutter build apk --release

   # iOS
   flutter build ios --release

   # Web
   flutter build web --release
   ```

---

## 📦 Dependencies

Our project leverages these carefully selected packages:

| Package           | Version  | Purpose              | License      | Documentation                                    | Mandatory/Optional |
| ----------------- | -------- | -------------------- | ------------ | ------------------------------------------------ | ----------------- |
| `firebase_core`   | ^4.2.0   | Firebase integration | BSD 3-Clause | [Docs](https://pub.dev/packages/firebase_core)   | Mandatory         |
| `firebase_auth`   | Latest   | User authentication  | BSD 3-Clause | [Docs](https://pub.dev/packages/firebase_auth)   | Mandatory         |
| `cloud_firestore` | Latest   | Cloud database       | BSD 3-Clause | [Docs](https://pub.dev/packages/cloud_firestore) | Mandatory         |
| `go_router`       | ^16.2.5  | Navigation & routing | BSD 3-Clause | [Docs](https://pub.dev/packages/go_router)       | Mandatory         |
| `provider`        | ^6.1.5+1 | State management     | MIT          | [Docs](https://pub.dev/packages/provider)        | Mandatory         |
| `mobile_scanner`  | ^7.1.2   | Barcode scanning     | BSD 3-Clause | [Docs](https://pub.dev/packages/mobile_scanner)  | Mandatory         |
| `qr_flutter`      | ^4.1.0   | QR code generation   | BSD 3-Clause | [Docs](https://pub.dev/packages/qr_flutter)      | Optional          |

> **Note**: All dependencies are automatically installed via `flutter pub get

## 🧪 Testing

Run the test suite to ensure code quality:

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/screens/signup_page_test.dart
```

---

## 📚 Documentation

- [User Guide](https://suyeshjadhav.github.io/CSC510_G19/) - Comprehensive user documentation
- [Contributing Guidelines](https://github.com/SuyeshJadhav/CSC510_G19/blob/main/Project2/CONTRIBUTING.md) - How to contribute to this project
- [Code of Conduct](https://github.com/SuyeshJadhav/CSC510_G19/blob/main/Project2/CODE_OF_CONDUCT.md) - Community guidelines

---

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](https://github.com/SuyeshJadhav/CSC510_G19/blob/main/Project2/CONTRIBUTING.md) for details on:

- Setting up the development environment
- Code style and standards
- Submitting pull requests
- Reporting issues

### Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes and commit (`git commit -m 'feat: add amazing feature'`)
4. Push to your branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 👥 Team

**CSC510 - Group 19**

| Name                     | Role      | GitHub                                                 |
| ------------------------ | --------- | ------------------------------------------------------ |
| Suyesh Jadhav            | Developer | [@SuyeshJadhav](https://github.com/SuyeshJadhav)       |
| Digvijay Sanjeev Sonvane | Developer | [@digvijaysonvane](https://github.com/DVJAY11)         |
| Vanaja Binay Agarwal     | Developer | [@vanajaagarwal](https://github.com/PositivelyBookish) |

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE.md](https://github.com/SuyeshJadhav/CSC510_G19/blob/main/Project2/LICENSE.md) file for details.

---

## 📄 Demo

[![▶ Watch Demo](https://img.youtube.com/vi/jVnnK5uBznI/maxresdefault.jpg)](https://www.youtube.com/watch?v=jVnnK5uBznI)
---


## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/SuyeshJadhav/CSC510_G19/issues)
- **Discussions**: [GitHub Discussions](https://github.com/SuyeshJadhav/CSC510_G19/discussions)
- **Email**: [Contact Team](mailto:dsonvan@ncsu.edu)

---

<p align="center">
    Made with ❤️ by CSC510 Group 19
</p>

<p align="center">
    <sub>Built with Flutter • Powered by Firebase</sub>
</p>
