import 'package:sqflite/sqflite.dart';

enum Operation {
  none,
  select,
  insert,
  update,
  delete,
  all
}

typedef Operation TransformOperation(Operation srcOperation, Object entity);

typedef String SelectFunc();

typedef Future<List<dynamic>> ParamsSelectFunc();

typedef Future ListenerInfo<T>(List<T> entityList, Operation operation);

/// main db class
abstract class DbAbstract {

  bool get isOpen;

  Future<void> close();

  Future<Database> get database;

  void addQuery(QueryAbstract query, Type type);

  QueryAbstract getQuery(Type type);

  Future<DatabaseExecutor> get activeTransaction;
  set activationTransaction(Transaction transaction);
  Transaction removeLastTransact();
}

/// query service for entity T
abstract class QueryAbstract<T> {

  Future<List<T>> select({String query, List<dynamic> params, Transaction transaction});

  Future<List<T>> get mainEntityList;

  Future<T> selectOne(String query, [List<dynamic> params, Transaction transaction]);

  Future<T> getEntityById(Object id);

  Object getIdValueFromEntity(T entityObject);

  Future<T> save(T entityInstance, [Transaction transaction]);

  Future<void> delete(T entityInstance, [Transaction transaction]);

  void addListener(ListenerInfo listener);
  bool removeListener(ListenerInfo listener);

  set transformOperation(TransformOperation transformOperation);
}