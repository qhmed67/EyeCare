# EyeCare AI – On-Device Eye Health Monitoring

**EyeCare AI** is a cutting-edge mobile application designed to monitor eye health using a hybrid on-device and cloud-assisted architecture. It leverages powerful machine learning and computer vision to identify eye-related risks such as fatigue, dryness, and inflammation.

## 🚀 Features

- **On-Device Vision Pipeline:** Utilizes **MediaPipe** and **Native Kotlin** for real-time eye detection and landmark analysis, ensuring speed and privacy.
- **Hybrid Risk Analysis:** Combines local processing with a cloud-based verification stage powered by **Google Gemini (via OpenRouter)** for highly accurate results.
- **Real-Time Monitoring:** Track indicators for:
    - 😫 **Eye Fatigue**
    - 🌵 **Dry Eye**
    - 💊 **Inflammation**
- **Find a Specialist:** Integrated map feature to locate nearby eye specialists and ophthalmologists.
- **Privacy First:** Core detection happens on-device; cloud verification is optional and anonymized.

## 🛠️ Tech Stack

- **Framework:** [Flutter](https://flutter.dev/) (3.x)
- **Native Implementation:** Kotlin (Method Channel integration)
- **Computer Vision:** Google MediaPipe
- **AI Backend:** Gemini Flash 1.5 (OpenRouter API)
- **Maps & Location:** Flutter Map & Geolocator
- **State Management:** Provider-like architecture with clean service separation

## 📦 Project Structure

```text
lib/
├── models/         # Data structures (RiskResult, Specialist, etc.)
├── pages/          # UI Screens (Upload, Analytics, Results, Find Specialist)
├── services/       # Core Logic (AnalysisService, LocationService)
└── main.dart       # App entry point

android/
└── app/src/main/   # Native Kotlin implementation for MediaPipe vision logic
```

## ⚙️ Setup & Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/[your-username]/eyecare.git
    cd eyecare
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Configure API Keys:**
    - Open `lib/services/analysis_service.dart`.
    - Replace `"API KEY HERE ↓"` with your [OpenRouter](https://openrouter.ai/) API key.

4.  **Run the app:**
    ```bash
    flutter run
    ```

## 📄 License

Project by **Ahmed Youssef**. All rights reserved.
