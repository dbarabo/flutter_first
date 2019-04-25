
import 'package:flutter_first/test/cases/raw_case.dart';
import 'package:flutter_first/test/gui/page/test_page.dart';

class RawTestPage extends TestPage {
  RawTestPage() : super("Raw tests") {

    test("May be Not Empty Select Account&Currency", firstMayBeNotEmptySelectAccountCurrency);

    test("Empty Select Account&Currency", simpleEmptySelectAccountCurrency);

    test("First Insert/Update Account&Currency", simpleInsertUpdateAccountCurrency);

    test("First Delete Account&Currency", simpleDeleteAccountCurrency);
  }
}