import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:obd_dashboard/data/amap/models.dart';

/// 分享状态归一测试（表驱动）
///
/// 依据 `amap-user-route-share-info.md`：
/// - **两个端点、两套取值域**：行前 `data.status`、行中 `data.shareInfo.shareStatus`；
/// - `code` 是字符串，比较前转数值；
/// - `code == 2/3` 是**参数问题**，绝不能当"行程结束"；
/// - `status == 4` **不是结束**，是"该切到行中端点"；
/// - 未知取值一律 `unknown`（调用方据此什么都不做）。
///
/// 这些用例是"误停导航"这一最坏后果的守门人：任何映射错位都会让本 app 在骑手
/// 正常行驶时把导航掐掉，所以取值域之间的串味必须被断言挡住。
void main() {
  // ---------------------------------------------------------------------------
  // 行前：GET /ws/user/route/share/info -> data.status
  // ---------------------------------------------------------------------------

  group('ShareStatusEnvelope（行前）', () {
    String body({required Object? code, Object? status, String? safe}) =>
        jsonEncode({
          'code': code,
          'result': code == 1 ? true : false,
          'message': 'Successful.',
          'data': status == null && safe == null
              ? null
              : {'status': status, if (safe != null) 'safeReportParameter': safe},
          'timestamp': '1791615141',
          'version': 'v3-557faf3',
        });

    final cases = <({String name, String json, ShareAlive expected})>[
      (
        name: 'status=1 行前分享中',
        json: body(code: '1', status: 1),
        expected: ShareAlive.waiting,
      ),
      (
        name: 'status=4 = 分享者已开始导航（不是结束）',
        json: body(code: '1', status: 4, safe: 'SAFE_PARAM'),
        expected: ShareAlive.navigating,
      ),
      (
        name: 'status=2 路线分享已停止',
        json: body(code: '1', status: 2),
        expected: ShareAlive.stopped,
      ),
      (
        name: 'status=3 路线分享已停止',
        json: body(code: '1', status: 3),
        expected: ShareAlive.stopped,
      ),
      (
        name: 'code=10001 该共享已过期（实测逐字）',
        json: '{"code":"10001","data":null,"errMsg":"Record Not Exist.",'
            '"message":"Record Not Exist.","result":false,'
            '"timestamp":"1791615141","version":"v3-557faf3"}',
        expected: ShareAlive.expired,
      ),
      (
        name: 'code=2 DecodeUrlParameterError 是参数问题，不是结束',
        json: '{"code":"2","data":null,"errMsg":"DecodeUrlParameterError",'
            '"message":"Failure.","result":false,"timestamp":"1791615141"}',
        expected: ShareAlive.unknown,
      ),
      (
        name: 'code=3 param 缺失 是参数问题，不是结束',
        json: '{"code":"3","errMsg":"Key: \'RouteShareInfoRequestPayload.Param\' '
            'Error:Field validation for \'Param\' failed on the \'required\' tag",'
            '"message":"Params error.","result":false,"timestamp":"1791615141"}',
        expected: ShareAlive.unknown,
      ),
      (
        name: '未知 status（99）不好当结束',
        json: body(code: '1', status: 99),
        expected: ShareAlive.unknown,
      ),
      (
        name: 'data=null 且 code=1 → 未知',
        json: body(code: '1'),
        expected: ShareAlive.unknown,
      ),
    ];

    for (final c in cases) {
      test(c.name, () {
        expect(ShareStatusEnvelope.parse(c.json).alive, c.expected);
      });
    }

    test('status 给字符串也能解析（接口可能给 int 也可能给字符串）', () {
      final env = ShareStatusEnvelope.parse(body(code: '1', status: '2'));
      expect(env.status, 2);
      expect(env.alive, ShareAlive.stopped);
    });

    test('status 给非法字符串 → null 且 unknown（不当成 0）', () {
      final env = ShareStatusEnvelope.parse(body(code: '1', status: 'abc'));
      expect(env.status, isNull);
      expect(env.alive, ShareAlive.unknown);
    });

    test('code 给数字（非字符串）同样按数值判定', () {
      final env = ShareStatusEnvelope.parse(body(code: 10001));
      expect(env.code, '10001');
      expect(env.alive, ShareAlive.expired);
    });

    test('status=4 同时给出 safeReportParameter 与 shouldSwitchToNavi', () {
      final env = ShareStatusEnvelope.parse(
        body(code: '1', status: 4, safe: 'SAFE_PARAM'),
      );
      expect(env.shouldSwitchToNavi, isTrue);
      expect(env.safeReportParameter, 'SAFE_PARAM');
    });

    test('错误响应没有 trace_id 也不抛异常，缺字段按可空处理', () {
      final env = ShareStatusEnvelope.parse('{"code":"2","message":"Failure."}');
      expect(env.alive, ShareAlive.unknown);
      expect(env.status, isNull);
      expect(env.safeReportParameter, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 行中：POST /ws/share/lbs/info -> data.shareInfo.shareStatus
  // ---------------------------------------------------------------------------

  group('ShareInfoEnvelope（行中）', () {
    String body({Object? shareStatus, bool includeShareInfo = true}) => jsonEncode({
          'code': '1',
          'result': true,
          'message': 'Successful.',
          'data': {
            if (includeShareInfo)
              'shareInfo': {
                if (shareStatus != null) 'shareStatus': shareStatus,
              },
            'shareMembers': [
              {
                'uid': 235110563,
                'nickName': 'Dyfkhi',
                'battery': 50,
                'online': false, // 实测：分享活跃时也可能一直是 false，不可用于判活
                'locInfo': {
                  'lon': 116.2948275,
                  'lat': 40.05403111111111,
                  'locationUpdateTime': 1791435362,
                  'nowTime': 1791435399,
                  'speed': 4,
                },
              },
            ],
          },
        });

    final cases = <({String name, Object? shareStatus, ShareAlive expected})>[
      (name: 'shareStatus=1 正在分享', shareStatus: 1, expected: ShareAlive.navigating),
      (name: 'shareStatus=5 已停止（实测值）', shareStatus: 5, expected: ShareAlive.stopped),
      (name: 'shareStatus=7 已停止（实测值）', shareStatus: 7, expected: ShareAlive.stopped),
      (name: 'shareStatus=6 已结束', shareStatus: 6, expected: ShareAlive.stopped),
    ];

    for (final c in cases) {
      test(c.name, () {
        final env = ShareInfoEnvelope.parse(body(shareStatus: c.shareStatus));
        expect(env.shareStatus, c.shareStatus);
        expect(env.alive, c.expected);
      });
    }

    test('行前取值域的值出现在 shareStatus 里 → unknown（绝不串味）', () {
      for (final v in [0, 2, 3, 4, 99]) {
        final env = ShareInfoEnvelope.parse(body(shareStatus: v));
        expect(env.alive, ShareAlive.unknown,
            reason: 'shareStatus=$v 不在 ${{1, 5, 6, 7}} 里，必须落 unknown');
      }
    });

    test('shareStatus 给字符串也能解析', () {
      expect(
        ShareInfoEnvelope.parse(body(shareStatus: '5')).alive,
        ShareAlive.stopped,
      );
    });

    test('缺 shareInfo / 缺 shareStatus → null 且 unknown', () {
      final noBlock =
          ShareInfoEnvelope.parse(body(includeShareInfo: false));
      expect(noBlock.shareStatus, isNull);
      expect(noBlock.alive, ShareAlive.unknown);

      final noField = ShareInfoEnvelope.parse(body());
      expect(noField.shareStatus, isNull);
      expect(noField.alive, ShareAlive.unknown);
    });

    test('新增 shareStatus 解析不影响 shareMembers / locInfo（回归）', () {
      final env = ShareInfoEnvelope.parse(body(shareStatus: 1));
      expect(env.first!.nickName, 'Dyfkhi');
      expect(env.first!.locationLagSeconds, 1791435399 - 1791435362);
    });
  });
}
