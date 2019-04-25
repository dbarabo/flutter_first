
import 'package:flutter_first/idiomatic/db.dart';
import 'package:flutter_first/idiomatic/query.dart';
import 'package:flutter_first/test/entity/account.dart';

class QueryAccount extends Query<Account> {
  QueryAccount(Db db) : super(db);
}

accountTest() async {

  print("before DB run");
  final db = Db("test.db", _SCRIPT_DB);

  final queryCurrency = Query<Currency>(db);
  final queryAccount = QueryAccount(db);
/*
  print("before save Currency");
  final Currency rub = await queryCurrency.save(Currency("Рубль", "руб"));
  print("rub= $rub");

  print("before save Account");


  Currency copyRub = rub;
  print("copyRub.type = ${copyRub.runtimeType}");

  final Account account = await queryAccount.save(Account("Test", copyRub, 1));
  print("account= $account");
*/
  final listCurrency = await queryCurrency.getMainEntityList;
  for(var cur in listCurrency) {
    print("cur=$cur");
  }

  final listAccount = await queryAccount.getMainEntityList;
  for(var acc in listAccount) {
    print("acc=$acc");
  }

  print("after select");
}

const _SELECT_ACCOUNT = "select * from account";

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