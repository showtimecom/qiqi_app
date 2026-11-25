import 'package:flutter_test/flutter_test.dart';
import 'package:qiqi_app/main.dart';

void main() {
  test('App 根组件可实例化', () {
    expect(const QiqiBrowserApp(), isNotNull);
  });

  test('常量配置合法', () {
    expect(kHomeUrl.startsWith('https://'), isTrue);
    expect(kAppName.isNotEmpty, isTrue);
  });
}
