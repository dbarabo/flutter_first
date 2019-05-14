import 'package:flutter_first/idiomatic/db.dart';
import 'package:flutter_first/idiomatic/idiomatic.dart';
import 'package:flutter_first/idiomatic/query.dart';
import 'package:flutter_first/test/babloz/entity/catalog.dart';

class BablozDb {
  static final BablozDb _instance = new BablozDb._internal();

  static final DbSettings dbSettings =
      DbSettings(name: "babloz.db", pathFileCopyDb: "assets/babloz.db", isDeleteExists: true);

  static final Db _db = DbDefault(dbSettings);

  final _queryAccount = QueryDefault<Account>(_db, _ACCOUNT_SELECT);
  final _queryCurrency = QueryDefault<Currency>(_db, _CURRENCY_SELECT);
  final _queryCategory = QueryDefault<Category>(_db, _CATEGORY_SELECT, _CATEGORY_PARAMS);
  final _queryPerson = QueryDefault<Person>(_db, _PERSON_SELECT);
  final _queryProject = QueryDefault<Project>(_db, _PROJECT_SELECT);
  final _queryPay = QueryDefault<Pay>(_db, _PAY_SELECT);

  QueryDefault<Account> get queryAccount => _queryAccount;
  QueryDefault<Currency> get queryCurrency => _queryCurrency;
  QueryDefault<Category> get queryCategory => _queryCategory;
  QueryDefault<Person> get queryPerson => _queryPerson;
  QueryDefault<Project> get queryProject => _queryProject;
  QueryDefault<Pay> get queryPay => _queryPay;

  factory BablozDb() {
    return _instance;
  }

  BablozDb._internal();

  static const _CURRENCY_SELECT = "select * from CURRENCY where COALESCE(SYNC, 0) != 2 order by ID";

  static const _ACCOUNT_SELECT = """
  select a.*,
  (select COALESCE(sum(case when a.ID = p.ACCOUNT then p.AMOUNT else COALESCE(p.amount_to, -1*p.AMOUNT) end), 0)
    from PAY p where a.ID in (p.ACCOUNT, p.ACCOUNT_TO) and COALESCE(p.SYNC, 0) != 2) REST

  from ACCOUNT a
  where (CLOSED IS NULL OR CLOSED > CURRENT_DATE)
    and COALESCE(a.SYNC, 0) != 2
  order by a.TYPE
""";

  static const _CATEGORY_SELECT = """select c.*,
(select COALESCE(sum(p.AMOUNT), 0) from PAY p, category chi where c.ID in (chi.id, chi.parent) and p.CATEGORY = chi.ID and p.CREATED >= ? and p.CREATED < ?) TURN
from category c where COALESCE(c.SYNC, 0) != 2
order by case when c.parent is null then 1000000*c.id else 1000000*c.parent + c.id end""";

  static const List<dynamic> _CATEGORY_PARAMS = [0, 9223372036854775807];

  static const _PERSON_SELECT = """
    select p.*,

    (select -1* sum(case when a.id = pp.account then pp.amount else -1*pp.amount end)
       from pay pp
          , account a
       where pp.person = p.id
         and coalesce(a.is_use_debt, 0) != 0
         and a.id in (pp.account, pp.ACCOUNT_TO)
         and a.type = 1) DEBT,

    (select sum(case when a.id = pp.account then pp.amount else -1*pp.amount end)
       from pay pp
          , account a
       where pp.person = p.id
         and coalesce(a.is_use_debt, 0) != 0
         and a.id in (pp.account, pp.ACCOUNT_TO)
         and a.type = 2) CREDIT

      from PERSON p
     where COALESCE(p.SYNC, 0) != 2
  order by case when p.parent is null then 1000000*p.id else 1000000*p.parent + p.id end  
  """;

  static const _PROJECT_SELECT =
      "select * from PROJECT where COALESCE(SYNC, 0) != 2 order by case when parent is null then 1000000*id else 1000000*parent + id end";

  static const _PAY_SELECT = "select p.* from pay p where COALESCE(p.SYNC, 0) != 2 order by p.created desc";
}
