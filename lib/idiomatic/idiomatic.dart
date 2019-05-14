import 'dart:async';

import 'package:sqflite/sqflite.dart';

enum Operation { none, select, insert, update, delete, all }

typedef Operation TransformOperation(Operation srcOperation, Object entity);

class OperationData<T> {
  final List<T> entityData;
  final Operation operation;

  const OperationData(this.entityData, this.operation);
}

typedef ListenerStream(OperationData operData);

class QueryData {
  final String query;
  final List<dynamic> params;

  const QueryData(this.query, [this.params]) : assert(query != null);
}

class DbSettings {
  final String name;
  final int version;
  final String dataScriptSqlCreate;
  final String pathFileScriptSqlCreate;
  final String pathFileCopyDb;
  final bool isDeleteExists;

  const DbSettings(
      {this.name,
      this.version,
      this.dataScriptSqlCreate,
      this.pathFileScriptSqlCreate,
      this.pathFileCopyDb,
      this.isDeleteExists})
      : assert(name != null);
}

/// main db class
abstract class Db {
  bool get isOpen;

  Future<void> close();

  Future<Database> get database;

  void addQuery(Query query, Type type);
  Query getQuery(Type type);

  Future<DatabaseExecutor> get activeTransaction;
  set activationTransaction(Transaction transaction);
  Transaction removeLastTransact();
}

/// query service for entity T
abstract class Query<T> {
  QueryData get mainQuery;
  set mainQuery(QueryData mainQuery);

  Future<List<T>> select({QueryData queryData, Transaction transaction});
  Future<T> selectOne(QueryData queryData, {Transaction transaction});

  Future<T> save(T entityInstance, [Transaction transaction]);
  Future<void> delete(T entityInstance, [Transaction transaction]);

  Future<List<T>> get mainEntityList;
  Future<T> getEntityById(Object id);
  Object getIdValueFromEntity(T entityObject);

  StreamSubscription<OperationData> addListener(ListenerStream listener);

  set transformOperation(TransformOperation transformOperation);

  bool get isCalculateOnSave;
  set isCalculateOnSave(bool isCalculateOnSave);
}
