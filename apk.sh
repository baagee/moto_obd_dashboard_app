flutter clean
flutter pub get

TIME=$(date +"%m%d_%H%M%S")
APP_VER="v_${TIME}"
flutter build apk --release --dart-define=APP_VERSION="${APP_VER}"

SRC='build/app/outputs/flutter-apk/app-release.apk'
DEST="build/app/outputs/flutter-apk"
NEW_NAME="app_${APP_VER}.apk"
mv "$SRC" "${DEST}/${NEW_NAME}"
echo "已生成 APK：${DEST}/${NEW_NAME}"
open ./build/app/outputs/flutter-apk
