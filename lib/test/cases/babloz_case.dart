import 'package:flutter_first/test/babloz/service/catalog_service.dart';
import 'package:sqflite/sqlite_api.dart';

Future simpleSelectAccountCurrency() async => await _selectAccountCurrency();

Future _selectAccountCurrency({Transaction trx}) async {
  final listAccount = await BablozDb().queryAccount.select(transaction: trx);
  for (var acc in listAccount) {
    print("acc=$acc");
  }

  print("before currency");
  final listCurrency = await BablozDb().queryCurrency.select(transaction: trx);
  for (var cur in listCurrency) {
    print("cur=$cur");
  }

  print("before category");
  final listCategory = await BablozDb().queryCategory.select(transaction: trx);
  for (var categ in listCategory) {
    print("categ=$categ");
  }

  print("before person");
  final listPerson = await BablozDb().queryPerson.select(transaction: trx);
  for (var person in listPerson) {
    print("person=$person");
  }

  print("before pay");
  final listPay = await BablozDb().queryPay.select(transaction: trx);
  for (var pay in listPay) {
    print("pay=$pay");
  }
}
