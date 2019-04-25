import 'package:sqflite/sqflite.dart';

/// main db class
abstract class DbAbstract {

  bool get isOpen;

  Future<void> close();

  Future<Database> getDb();

  void addQuery(QueryAbstract query, Type type);

  QueryAbstract getQuery(Type type);
}

/// query service for entity T
abstract class QueryAbstract<T> {

  Future<List<T>> select(String query, {List<dynamic> params, bool isMain = true});

  Future<List<T>> get getMainEntityList;

  Future<T> selectOne(String query, [List<dynamic> params]);

  Future<T> getEntityById(Object id);

  Object getIdValueFromEntity(T entityObject);

  Future<T> save(T entityInstance);

  Future<void> delete(T entityInstance);
}