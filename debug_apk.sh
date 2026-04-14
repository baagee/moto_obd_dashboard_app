flutter clean
flutter pub get
flutter build apk --debug

SRC='build/app/outputs/flutter-apk/app-debug.apk'
DEST="build/app/outputs/flutter-apk"
TIME=$(date +"%Y%m%d_%H%M")
NEW_NAME="app_debug_${TIME}.apk"
mv "$SRC" "${DEST}/${NEW_NAME}"
echo "已生成 APK：${DEST}/${NEW_NAME}"
open ./build/app/outputs/flutter-apk