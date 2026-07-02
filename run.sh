flutter clean
flutter pub get

TIME=$(date +"%m%d_%H%M%S")
APP_VER="PREVIEW_${TIME}"
flutter run --dart-define=APP_VERSION="${APP_VER}"