import 'package:flutter_test/flutter_test.dart';
import 'package:deel_wallet/data.dart';

void main() {
  test('money formats in FCFA without decimals', () {
    expect(money(813200), '813 200 FCFA');
  });

  test('phoneValid accepts 10-digit local numbers, rejects the rest', () {
    expect(phoneValid('0700000000'), isTrue);
    expect(phoneValid('07 00 00 00 00'), isTrue);
    expect(phoneValid('123'), isFalse);
    expect(phoneValid('1700000000'), isFalse);
  });
}
