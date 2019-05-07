import 'package:flutter_first/test/cases/babloz_case.dart';
import 'package:flutter_first/test/gui/page/test_page.dart';

class BablozTestPage extends TestPage {
  BablozTestPage() : super("Babloz tests") {
    test("May be Not Empty Select Account&Currency", simpleSelectAccountCurrency);
  }
}
