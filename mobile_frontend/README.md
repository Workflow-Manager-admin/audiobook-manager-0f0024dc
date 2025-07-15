# mobile_frontend

A modern minimalist Flutter app for audiobook store, library, and player (with purchase via Stripe).

## Features

- Bottom navigation: Store, Library, Player
- Purchase audiobooks (Stripe integration, via backend)
- Playback with resume & skip 15s, progress tracking
- Modern light UI with custom colors (`primary #1E88E5`, `secondary #43A047`, `accent #FFC107`)
- Persistent local storage (library + progress)
- Environment variable support for sensitive data (.env file; see `.env.example`)

## Getting Started

1. Copy `.env.example` to `.env` in this directory and fill with your Stripe keys (demo logic is mocked).
2. Install dependencies:

    ```bash
    flutter pub get
    ```

3. Run

    ```bash
    flutter run
    ```

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
