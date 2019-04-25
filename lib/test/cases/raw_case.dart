
import 'package:flutter_first/idiomatic/db.dart';
import 'package:flutter_first/idiomatic/idiomatic.dart';
import 'package:flutter_first/idiomatic/query.dart';
import 'package:flutter_first/test/entity/account.dart';

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

  final queryCurrency = db.getQuery(Currency) ?? Query<Currency>(db, isGenerateSelect: true);
  final queryAccount = db.getQuery(Account) ?? Query<Account>(db, isGenerateSelect: true);

  final List<Currency> curList = await queryCurrency.getMainEntityList;
  final Currency curRur = curList?.firstWhere((it)=> it.name == "Рубль" || it.ext == "Руб", orElse: ()=> null)
      ?? await queryCurrency.save(Currency("Рубль", "Руб"));
  print("curRur=$curRur");

  final Currency curUsd = curList?.firstWhere((it)=> it.name == "Dollar" || it.ext == "Usd", orElse: ()=> null)
      ?? await queryCurrency.save(Currency("Dollar", "Usd"));
  print("curUsd=$curUsd");

  curUsd.name = "Доллар США";
  curUsd.ext = "USD";

  curList?.firstWhere((it)=> it.name == curUsd.name || it.ext == curUsd.ext, orElse: ()=> null)
    ?? await queryCurrency.save(curUsd);

  final List<Account> accountList = await queryAccount.getMainEntityList;

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

Future simpleDeleteAccountCurrency() async {
  final db = _getDb();

  final queryCurrency = db.getQuery(Currency) ?? Query<Currency>(db, isGenerateSelect: true);
  final queryAccount = db.getQuery(Account) ?? Query<Account>(db, isGenerateSelect: true);

  final Currency usd = await queryCurrency.getEntityById(2);
  if(usd == null) {
    await simpleInsertUpdateAccountCurrency();
  }

  final Account cash = await queryAccount.getEntityById(1);
  await queryAccount.delete(cash);

  await queryCurrency.delete(usd);

  await _selectAccountCurrency();

  await simpleInsertUpdateAccountCurrency();
}

Future _selectAccountCurrency({bool isDeleteDb = false}) async {

  final db = _getDb(isDelete: isDeleteDb);

  final queryCurrency = db.getQuery(Currency) ?? Query<Currency>(db, isGenerateSelect: true);
  final queryAccount = db.getQuery(Account) ?? Query<Account>(db, isGenerateSelect: true);

  final listAccount = await queryAccount.getMainEntityList;
  for(var acc in listAccount) {
    print("acc=$acc");
  }

  print("before currency");
  final listCurrency = await queryCurrency.getMainEntityList;
  for(var cur in listCurrency) {
    print("cur=$cur");
  }
}

const _SCRIPT_PATH = "assets/db.sql";
