#!/bin/bash

# APK 打包脚本
# 用法:
#   ./apk.sh          # 默认打 release 包
#   ./apk.sh release  # release 包
#   ./apk.sh debug    # debug 包(含 Phase 0 高德广播抓包探针等调试入口)

MODE="${1:-release}"

if [[ "$MODE" != "release" && "$MODE" != "debug" ]]; then
  echo "未知模式: $MODE (仅支持 release / debug)"
  exit 1
fi

flutter clean
flutter pub get

TIME=$(date +"%m%d_%H%M%S")
APP_VER="v_${TIME}"
flutter build apk --"${MODE}" --dart-define=APP_VERSION="${APP_VER}"

SRC="build/app/outputs/flutter-apk/app-${MODE}.apk"
DEST="build/app/outputs/flutter-apk"
NEW_NAME="app_${MODE}_${APP_VER}.apk"
mv "$SRC" "${DEST}/${NEW_NAME}"
echo "已生成 APK：${DEST}/${NEW_NAME}"
open ./build/app/outputs/flutter-apk
