flutter clean
flutter pub get

TIME=$(date +"%m%d_%H%M%S")
APP_VER="Test_${TIME}"
flutter run --dart-define=APP_VERSION="${APP_VER}"