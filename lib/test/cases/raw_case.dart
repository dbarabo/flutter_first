
import 'package:flutter_first/idiomatic/db.dart';
import 'package:flutter_first/idiomatic/idiomatic.dart';
import 'package:flutter_first/idiomatic/query.dart';
import 'package:flutter_first/test/entity/account.dart';
import 'package:flutter_first/test/service/account_service.dart';

DbAbstract _db;

DbAbstract _getDb() {
  if(_db?.isOpen != true) {
    _db = Db("test.db", _SCRIPT_DB, true);
  }
  return _db;
}

Future simpleSelectAccountCurrency() async => await _selectAccountCurrency();

Future simpleInsertUpdateAccountCurrency() async {
  final db = _getDb();

  final queryCurrency = db.getQuery(Currency) ?? Query<Currency>(db);
  final queryAccount = db.getQuery(Account) ?? QueryAccount(db);

  final Currency curRur = await queryCurrency.save(Currency("Рубль", "Руб"));
  print("curRur=$curRur");

  final Currency curUsd = await queryCurrency.save(Currency("Dollar", "Usd"));
  print("curUsd=$curUsd");

  curUsd.name = "Доллар США";
  curUsd.ext = "USD";
  await queryCurrency.save(curUsd);

  final Account accountCash = await queryAccount.save(Account("Cash", curRur, 1));
  print("accountCash=$accountCash");

  accountCash.description = "update desc 0";
  accountCash.type = 0;
  accountCash.name = "Налик";
  accountCash.currency = curUsd;

  await _selectAccountCurrency();
}

Future simpleDeleteAccountCurrency() async {
  final db = _getDb();

  final queryCurrency = db.getQuery(Currency) ?? Query<Currency>(db);
  final queryAccount = db.getQuery(Account) ?? QueryAccount(db);

  final Currency usd = await queryCurrency.getEntityById(2);
  if(usd == null) {
    await simpleInsertUpdateAccountCurrency();
  }

  final Account cash = await queryAccount.getEntityById(1);
  await queryAccount.delete(cash);

  await queryCurrency.delete(usd);

  await _selectAccountCurrency();
}

Future _selectAccountCurrency() async {

  final db = _getDb();

  final queryCurrency = db.getQuery(Currency) ?? Query<Currency>(db);
  final queryAccount = db.getQuery(Account) ?? QueryAccount(db);

  final listCurrency = await queryCurrency.getMainEntityList;
  for(var cur in listCurrency) {
    print("cur=$cur");
  }

  final listAccount = await queryAccount.getMainEntityList;
  for(var acc in listAccount) {
    print("acc=$acc");
  }
}


const _SCRIPT_DB = """
/* 1. Валюты - DEF RUR */
create table CURRENCY (
ID INT NOT NULL PRIMARY KEY,
NAME varchar(10) NOT NULL UNIQUE,
EXT varchar(3) NOT NULL UNIQUE,
SYNC INT
);

/* 2.  Счета */
create table ACCOUNT (
ID INT NOT NULL PRIMARY KEY,
NAME varchar(100) NOT NULL,
DESCRIPTION varchar(1024),
CURRENCY INT NOT NULL REFERENCES CURRENCY(ID),
TYPE INT NOT NULL DEFAULT 0, /* 0-текущие счета, 1-Кредиты, 2-Депозиты */
CLOSED DATE,
IS_USE_DEBT INT NOT NULL DEFAULT 0, /* 1-учитывать в долгах субъекта */
SYNC INT,
CHECK (TYPE in (0, 1, 2)),
CHECK (IS_USE_DEBT in (0, 1))
);
""";