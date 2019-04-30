
import 'package:flutter_first/idiomatic/db.dart';
import 'package:flutter_first/idiomatic/idiomatic.dart';
import 'package:flutter_first/idiomatic/query.dart';
import 'package:flutter_first/test/entity/account.dart';
import 'package:sqflite/sqlite_api.dart';

DbAbstract _db;

DbAbstract _getDb({bool isDelete = true}) {
  if(_db?.isOpen != true) {
    _db = Db("test.db", _SCRIPT_PATH, isDelete, true);
  }
  return _db;
}

Future firstMayBeNotEmptySelectAccountCurrency() async => await _selectAccountCurrency(isDeleteDb:false);

Future simpleEmptySelectAccountCurrency() async {

  await _getDb(isDelete: false)?.close();

  await _selectAccountCurrency(isDeleteDb:true);
}

Future simpleInsertUpdateAccountCurrency() async {
  final db = _getDb();

  final queryCurrency = db.getQuery(Currency) ?? Query<Currency>(db, ()=> "select * from CURRENCY");
  final queryAccount = db.getQuery(Account) ?? Query<Account>(db, ()=> "select * from ACCOUNT");

  queryCurrency.transformOperation = transformOperationDef;

  final List<Currency> curList = await queryCurrency.mainEntityList;
  final Currency curRur = curList?.firstWhere((it)=> it.name == "Рубль" || it.ext == "Руб", orElse: ()=> null)
      ?? await queryCurrency.save(Currency("Рубль", "Руб"));
  print("curRur=$curRur");

  final Currency curUsd = curList?.firstWhere((it)=> it.name == "Dollar" || it.ext == "Usd", orElse: ()=> null)
      ?? await queryCurrency.save(Currency("Dollar", "Usd"));
  print("curUsd=$curUsd");

  curUsd.name = "Доллар США";
  curUsd.ext = "USD";

  Currency dolUsd = curList?.firstWhere((it)=> it.name == curUsd.name || it.ext == curUsd.ext, orElse: ()=> null);

  print("dolUsd:$dolUsd");

  /*
  if(dolUsd == null) {
    dolUsd = await queryCurrency.save(curUsd);
  } else {
    dolUsd.name = "dolUsd";
    dolUsd = await queryCurrency.save(curUsd);
  }
  print("dolUsd 2:$dolUsd");
*/
  final List<Account> accountList = await queryAccount.mainEntityList;

  final Account accountCash = accountList?.firstWhere( (it)=> it.name == "Cash", orElse: ()=> null) ??
    await queryAccount.save(Account("Cash", curRur, 1));
  print("accountCash=$accountCash");

  accountCash.description = "update desc 0";
  accountCash.type = 0;
  accountCash.name = "Налик";
  accountCash.currency = curUsd;

  accountList?.firstWhere( (it)=> it.name == accountCash.name, orElse: ()=> null) ??
      await queryAccount.save(accountCash);

  await _selectAccountCurrency();
}

Future simpleTransactOperations() async {
  final db = _getDb(isDelete:false);

  final database = await db.database;

  final queryCurrency = db.getQuery(Currency) ?? Query<Currency>(db, ()=> "select * from CURRENCY");

  queryCurrency.transformOperation = transformOperationDef;

  //final queryAccount = db.getQuery(Account) ?? Query<Account>(db, ()=> "select * from ACCOUNT");

  await database.transaction( (trx) async {
    await _selectAccountCurrency(trx: trx);

    await queryCurrency.save(Currency("test0", "ex1"), trx);
    await queryCurrency.save(Currency("test1", "ex2"), trx);
    await queryCurrency.save(Currency("test2", "ex3"), trx);
    await queryCurrency.save(Currency("test3", "ex4"), trx);
    await queryCurrency.save(Currency("test4", "ex5"), trx);

    await _selectAccountCurrency(trx: trx);

    await queryCurrency.save(Currency("test5", "ex6"), trx);
    await queryCurrency.save(Currency("test6", "ex7"), trx);
    await queryCurrency.save(Currency("test7", "ex8"), trx);
    await queryCurrency.save(Currency("test8", "ex9"), trx);
    await queryCurrency.save(Currency("test9", "ex0"), trx);

    await _selectAccountCurrency(trx: trx);
  });
}

Future simpleDeleteAccountCurrency() async {
  final db = _getDb();

  final queryCurrency = db.getQuery(Currency) ?? Query<Currency>(db, ()=> "select * from CURRENCY");
  final queryAccount = db.getQuery(Account) ?? Query<Account>(db, ()=> "select * from ACCOUNT");

  queryCurrency.transformOperation = transformOperationDef;

  final Currency usd = await queryCurrency.getEntityById(2);
  if(usd == null) {
    print("usd:$usd");
    await simpleInsertUpdateAccountCurrency();
  }

  final Account cash = await queryAccount.getEntityById(1);
  await queryAccount.delete(cash);

  await queryCurrency.delete(usd);

  await _selectAccountCurrency();

  await simpleInsertUpdateAccountCurrency();
}

Future _selectAccountCurrency({bool isDeleteDb = false, Transaction trx}) async {

  final db = _getDb(isDelete: isDeleteDb);

  final queryCurrency = db.getQuery(Currency) ?? Query<Currency>(db, ()=> "select * from CURRENCY");
  final queryAccount = db.getQuery(Account) ?? Query<Account>(db, ()=> "select * from ACCOUNT");

  final listAccount = await queryAccount.select(transaction: trx);
  for(var acc in listAccount) {
    print("acc=$acc");
  }

  print("before currency");
  final listCurrency = await queryCurrency.select(transaction: trx);
  for(var cur in listCurrency) {
    print("cur=$cur");
  }
}

Future simpleTransform() {
  final db = _getDb(isDelete: false);

  Query<Currency>(db, ()=> "select * from CURRENCY");
}

const _SCRIPT_PATH = "assets/db.sql";
