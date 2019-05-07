import 'package:flutter_first/idiomatic/db.dart';
import 'package:flutter_first/idiomatic/idiomatic.dart';
import 'package:flutter_first/idiomatic/query.dart';
import 'package:flutter_first/test/babloz/entity/catalog.dart';
import 'package:sqflite/sqlite_api.dart';

DbAbstract _db;

DbAbstract _getDb() {
  if (_db?.isOpen != true) {
    _db = Db("babloz.db", _SCRIPT_PATH, true, true);
  }
  return _db;
}

Future simpleSelectAccountCurrency() async => await _selectAccountCurrency();

Future _selectAccountCurrency({Transaction trx}) async {
  final db = _getDb();

  final queryCurrency = db.getQuery(Currency) ?? Query<Currency>(db, () => "select * from CURRENCY");
  final queryAccount = db.getQuery(Account) ?? Query<Account>(db, () => "select * from ACCOUNT");

  final listAccount = await queryAccount.select(transaction: trx);
  for (var acc in listAccount) {
    print("acc=$acc");
  }

  print("before currency");
  final listCurrency = await queryCurrency.select(transaction: trx);
  for (var cur in listCurrency) {
    print("cur=$cur");
  }
}

const _SCRIPT_PATH = "assets/babloz.db";
