import 'package:flutter_test/flutter_test.dart';

import 'package:just_a_work_app/ui/jobs/job_edit_page.dart';

void main() {
  group('职位学历一致性校验', () {
    test('内容无学历表述 -> 通过', () {
      expect(
        educationConsistencyHint('本科', ['负责核心系统开发', '熟悉常见框架']),
        isNull,
      );
    });

    test('内容与所选一致 -> 通过', () {
      expect(
        educationConsistencyHint('本科', ['要求本科及以上学历', '负责产品研发']),
        isNull,
      );
    });

    test('内容提及其他学历 -> 拦截', () {
      final hint = educationConsistencyHint('硕士', ['要求本科以上学历']);
      expect(hint, isNotNull);
      expect(hint, contains('硕士'));
      expect(hint, contains('本科'));
    });

    test('学历不限但内容点名学历 -> 拦截', () {
      final hint = educationConsistencyHint(null, ['需要硕士学历优先']);
      expect(hint, isNotNull);
      expect(hint, contains('学历不限'));
    });

    test('多段文本拼接后校验（描述+要求）', () {
      final hint = educationConsistencyHint('大专', ['岗位职责描述', '任职要求：本科及以上']);
      expect(hint, isNotNull);
    });
  });
}
