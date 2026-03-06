
# 获取当前versionCode
#VERSION_LINE=$(grep -m1 "^version:" pubspec.yaml)
#VERSION_NAME=$(echo $VERSION_LINE | cut -d' ' -f2 | cut -d'+' -f1)
#VERSION_CODE=$(echo $VERSION_LINE | cut -d'+' -f2)
#
## 自增 versionCode
#NEW_VERSION_CODE=$((VERSION_CODE + 1))
#
## 修改 pubspec.yaml
#sed -i '' "s/version: $VERSION_NAME+$VERSION_CODE/version: $VERSION_NAME+$NEW_VERSION_CODE/" pubspec.yaml
#
#echo "📦 new version: $VERSION_NAME+$NEW_VERSION_CODE"

flutter clean
flutter pub get
flutter build apk

SRC='build/app/outputs/flutter-apk/app-release.apk'
DEST="build/app/outputs/flutter-apk"
TIME=$(date +"%Y%m%d_%H%M")
NEW_NAME="app_${TIME}.apk"
mv "$SRC" "${DEST}/${NEW_NAME}"
echo "已生成 APK：${DEST}/${NEW_NAME}"
open ./build/app/outputs/flutter-apk