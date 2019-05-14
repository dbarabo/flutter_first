import 'dart:async';

import 'package:flutter_first/idiomatic/reflect.dart';
import 'package:flutter_first/idiomatic/sql_func.dart';
import 'package:reflectable/mirrors.dart';
import 'package:reflectable/reflectable.dart';
import 'package:sqflite/sqlite_api.dart';

import 'annotation/annotations.dart';
import 'idiomatic.dart';

enum DbOperation { mainSelect, select, insert, update, delete }

const String _CALC_MARKER = "*CALC*";

class _EntityMetaData {
  Map<String, ColumnInfo> _columnsInfo;

  _EntityMetaData(this._columnsInfo);
}

class _OperQuery {
  final _sqlQueries = Map<String, _EntityMetaData>();

  _OperQuery(String query, Map<String, ColumnInfo> columnsInfo) {
    _sqlQueries[query] = _EntityMetaData(columnsInfo);
  }

  put(String query, Map<String, ColumnInfo> columnsInfo) {
    _sqlQueries[query] = _EntityMetaData(columnsInfo);
  }
}

class QueryDefault<T> implements Query<T> {
  final Db _db;
  final Map<DbOperation, _OperQuery> _operQueries = Map<DbOperation, _OperQuery>();

  String _tableName;
  ClassMirror _typeInstance;

  TransformOperation _transform;
  List<T> mainList;

  StreamController _listenerController;

  @override
  bool isCalculateOnSave = true;

  @override
  QueryData mainQuery;

  QueryDefault(this._db, [String mainQuerySelect, List<dynamic> params]) {
    _db.addQuery(this, T);

    final entityByType = getEntityAnnotation(T);

    if (entityByType == null) throw Exception("$T is not contains @entity annotation");

    _tableName = entityByType.tableName;

    _typeInstance = entity.reflectType(T) as ClassMirror;

    if (mainQuerySelect?.isNotEmpty == true) {
      mainQuery = QueryData(mainQuerySelect, params);
    }
  }

  @override
  set transformOperation(TransformOperation transformOperation) => _transform = transformOperation;

  @override
  StreamSubscription<OperationData> addListener(ListenerStream listener) {
    _listenerController ??= StreamController<OperationData>();

    return _listenerController.stream.listen(listener);
  }

  @override
  Future<T> save(T entityInstance, [Transaction transaction]) async =>
      _processOperation(entityInstance, Operation.all, transaction);

  Future<T> _processOperation(T entityInstance, Operation srcOperation, Transaction transaction) async {
    if (_tableName?.isNotEmpty != true)
      throw Exception("$entity is not contains tableName for @Entity annotation");

    try {
      _db.activationTransaction = transaction;

      await _initSavedOperations();

      final InstanceMirror instanceMirror = entity.reflect(entityInstance);

      if (srcOperation == Operation.all) {
        srcOperation = _isNullPkEntity(instanceMirror) ? Operation.insert : Operation.update;
      }

      Operation transformOperation =
          _transform == null ? srcOperation : _transform(srcOperation, entityInstance);

      await _execOperation(transformOperation, instanceMirror, entityInstance);

      _sendListenerInfo([entityInstance], srcOperation);
    } finally {
      _db.removeLastTransact();
    }
    return entityInstance;
  }

  Future _execOperation(Operation operation, InstanceMirror instanceMirror, T entityInstance) async {
    switch (operation) {
      case Operation.insert:
        await _insertEntity(instanceMirror);
        await _insertToMainList(entityInstance);
        await _processCalc(instanceMirror, DbOperation.insert);
        break;

      case Operation.update:
        await _updateEntity(instanceMirror);
        await _processCalc(instanceMirror, DbOperation.update);
        break;

      case Operation.delete:
        await _deleteEntity(instanceMirror);
        await _removeFromMainList(entityInstance);
        break;

      case Operation.none:
        break;

      default:
        throw Exception("do not execute operation $operation");
    }
    return operation;
  }

  Future<void> _processCalc(InstanceMirror instanceMirror, DbOperation operType) async {
    if (!isCalculateOnSave) return;

    _initCalcFields(null);

    final Iterable<ColumnInfo> calcColumns = _operQueries[DbOperation.select]
        ?._sqlQueries[_CALC_MARKER]
        ?._columnsInfo
        ?.values
        ?.where((col) => col?.calcExpression?.isNotEmpty == true);

    if (calcColumns?.isNotEmpty != true) return;

    final ColumnInfo pkColumn = _operQueries[operType]
        ._sqlQueries
        .values
        .first
        ._columnsInfo
        .values
        .firstWhere((it) => it.relation == ColumnRelation.primaryKey, orElse: null);

    if (pkColumn == null) return;

    final Object pkValue = pkColumn.getterToSql(instanceMirror);

    for (final column in calcColumns) {
      Object calcValue = await _selectValue(column.calcExpression, [pkValue]);
      await column.setterFromSql(instanceMirror, calcValue);
    }
  }

  @override
  Future<void> delete(T entityInstance, [Transaction transaction]) async =>
      _processOperation(entityInstance, Operation.delete, transaction);

  @override
  Future<T> selectOne(QueryData queryData, {Transaction transaction}) async {
    final List<T> resultList = await select(queryData: queryData, transaction: transaction);

    return resultList?.isNotEmpty == true ? resultList.first : null;
  }

  @override
  Future<List<T>> select({QueryData queryData, Transaction transaction}) async {
    final String queryMainSelect = mainQuery?.query;

    final String querySelect = queryData?.query?.isNotEmpty == true ? queryData?.query : queryMainSelect;

    final isMain = querySelect == queryMainSelect;

    final paramsSelect = isMain && queryData?.params == null ? mainQuery?.params : queryData?.params;

    final List<T> result = _initResultList(isMain);

    try {
      _db.activationTransaction = transaction;

      List<Map<String, dynamic>> sqlResult = await _selectQuery(querySelect, paramsSelect);

      if (sqlResult?.isNotEmpty != true) {
        _sendListenerInfo(result, Operation.select);
        return result;
      }

      final queryUpper = querySelect.trim().toUpperCase();

      final DbOperation dbOperType = isMain ? DbOperation.mainSelect : DbOperation.select;

      await _initSelectOperations(queryUpper, sqlResult[0], dbOperType);

      final _OperQuery operQuery = _operQueries[dbOperType];

      final Map<String, ColumnInfo> columnsInfo = operQuery?._sqlQueries[queryUpper]?._columnsInfo;

      for (Map<String, dynamic> row in sqlResult) {
        result.add(await _fromSqlRow(row, columnsInfo));
      }
    } finally {
      _db.removeLastTransact();
    }

    _sendListenerInfo(result, Operation.select);

    return result;
  }

  @override
  Future<List<T>> get mainEntityList async {
    if (mainList != null) return mainList;

    mainQuery?.query?.isNotEmpty == true ? await select() : _resetMainList();

    return mainList;
  }

  @override
  Future<T> getEntityById(Object id) async {
    if (id == null) return null;

    List<T> list = await mainEntityList;

    if (list?.isNotEmpty != true) return null;

    ColumnInfo pkColumn = _getFirstPkColumnInfo();

    if (pkColumn == null) throw Exception("id annotation not found for entity $T");

    final T find =
        list.firstWhere((it) => pkColumn.getterToSql(entity.reflect(it)) == id, orElse: () => null);

    return find;
  }

  @override
  Object getIdValueFromEntity(T entityObject) {
    if (entityObject == null) return null;

    ColumnInfo pkColumn = _getFirstPkColumnInfo();

    if (pkColumn == null) throw Exception("id annotation not found for entity $T");

    return pkColumn.getterToSql(entity.reflect(entityObject));
  }

  _sendListenerInfo(List<T> items, Operation operation) =>
      _listenerController?.add(OperationData(items, operation));

  List<T> _initResultList(bool isMain) {
    if (isMain) {
      return _resetMainList();
    } else {
      return List<T>();
    }
  }

  List<T> _resetMainList() {
    if (mainList == null) {
      mainList = List<T>();
    } else {
      mainList.clear();
    }
    return mainList;
  }

  ColumnInfo _getFirstPkColumnInfo() {
    for (var oper in DbOperation.values) {
      final _OperQuery operQuery = _operQueries[oper];
      if (operQuery?._sqlQueries == null) continue;

      for (_EntityMetaData entityData in operQuery._sqlQueries.values) {
        ColumnInfo colInfo = entityData?._columnsInfo?.values
            ?.firstWhere((col) => col?.relation == ColumnRelation.primaryKey, orElse: () => null);

        if (colInfo != null) return colInfo;
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _selectQuery(String query, [List<dynamic> params]) async {
    print("_selectQuery:$query");

    final dbOpen = await _db.activeTransaction;

    print("_selectQuery TRANSACTION:$dbOpen");

    return await (params?.isNotEmpty == true ? dbOpen.rawQuery(query, params) : dbOpen.rawQuery(query));
  }

  Future<void> _execute(String query, [List<dynamic> params]) async {
    final dbOpen = await _db.activeTransaction;

    print("_execute=$query");
    for (var par in params) {
      print("par=$par");
    }

    print("_execute TRANSACTION:$dbOpen");
    try {
      await (params?.isNotEmpty == true ? dbOpen.execute(query, params) : dbOpen.execute(query));
    } catch (e) {
      print("EXCEPT!!! _execute=$query");
      for (var par in params) {
        print("par=$par");
      }
      print(e);

      throw Exception(e);
    }
  }

  Future<Object> _selectValue(String query, [List<dynamic> params]) async {
    List<Map<String, dynamic>> list = await _selectQuery(query, params);

    return (list?.isNotEmpty == true) ? list[0].values.first : null;
  }

  Future<T> _fromSqlRow(Map<String, dynamic> row, Map<String, ColumnInfo> columnsInfo) async {
    final T instance = _typeInstance.newInstance("", List());

    final InstanceMirror instanceMirror = entity.reflect(instance);

    for (final columnEntry in row.entries) {
      final columnInfo = columnsInfo[columnEntry.key];

      if (columnInfo == absentColumnInfo) continue;

      await columnInfo.setterFromSql(instanceMirror, columnEntry.value);
    }
    return instance;
  }

  Future<void> _deleteEntity(InstanceMirror instanceMirror) async =>
      _executeFirst(DbOperation.delete, instanceMirror);

  Future<void> _insertToMainList(T entityInstance) async {
    final mainList = await mainEntityList;

    mainList?.add(entityInstance);
  }

  Future<void> _removeFromMainList(T entityInstance) async {
    final mainList = await mainEntityList;

    mainList?.remove(entityInstance);
  }

  Future<void> _updateEntity(InstanceMirror instanceMirror) async =>
      _executeFirst(DbOperation.update, instanceMirror);

  Future<void> _insertEntity(InstanceMirror instanceMirror) async {
    final Iterable<ColumnInfo> pkCalc = _operQueries[DbOperation.insert]
        ._sqlQueries
        .values
        .first
        ._columnsInfo
        .values
        .where((it) => it.relation == ColumnRelation.primaryKey && it.calcExpression?.isNotEmpty == true);

    for (var pkColumn in pkCalc) {
      Object pkValue = await _selectValue(pkColumn.calcExpression);
      await pkColumn.setterFromSql(instanceMirror, pkValue);
    }
    await _executeFirst(DbOperation.insert, instanceMirror);
  }

  Future<void> _executeFirst(DbOperation operation, InstanceMirror instanceMirror) {
    final String execQuery = _operQueries[operation]._sqlQueries.keys.first;

    final params = _operQueries[operation]
        ._sqlQueries
        .values
        .first
        ._columnsInfo
        .values
        .map((it) => it.getterToSql(instanceMirror))
        .toList();

    return _execute(execQuery, params);
  }

  Future<void> _initSelectOperations(String query, Map<String, dynamic> row, DbOperation dbOperType) async {
    final _OperQuery operQuery = _operQueries[dbOperType];

    if (operQuery?._sqlQueries != null && operQuery?._sqlQueries[query] != null) return;

    Map<String, ColumnInfo> copyColumns =
        _operQueries.length != 0 ? _copyOperQueriesFromOther(row.keys) : await _initAllOperations(row);

    if (copyColumns.length < row.length) {
      copyColumns = addAbsentColumns(copyColumns, row, _typeInstance, _db);
    }
    await _setSelectOperation(query, copyColumns, dbOperType);
  }

  _setSelectOperation(String query, Map<String, ColumnInfo> columns, DbOperation dbOperType) async {
    final _OperQuery operQuery = _operQueries[dbOperType] ?? _OperQuery(query, columns);

    _operQueries[dbOperType] ??= operQuery;

    operQuery.put(query, columns);
  }

  Future<Map<String, ColumnInfo>> _initAllOperations(Map<String, dynamic> row) async {
    if (_tableName?.isNotEmpty == true) {
      await _initSavedOperations(isRaiseAbsentPk: false);

      _initCalcFields(row);

      return _copyOperQueriesFromOther(row.keys);
    }
    return Map<String, ColumnInfo>();
  }

  Map<String, ColumnInfo> _copyOperQueriesFromOther(Iterable<String> columnNames) {
    final Iterable<Map<String, ColumnInfo>> operMaps = _operQueries?.entries
        ?.where((it) =>
            [DbOperation.mainSelect, DbOperation.select, DbOperation.insert].contains(it.key) &&
            (it?.value?._sqlQueries?.values?.length ?? 0) > 0)
        ?.map((it) => it.value._sqlQueries.values)
        ?.expand((it) => it)
        ?.where((it) => it != null)
        ?.map((it) => it._columnsInfo);

    final Map<String, ColumnInfo> opers = Map<String, ColumnInfo>();
    for (final map in operMaps) {
      opers.addAll(map);
    }
    final Map<String, ColumnInfo> result = Map<String, ColumnInfo>();

    for (final columnName in columnNames) {
      final MapEntry<String, ColumnInfo> columnInfo = opers?.entries
          ?.firstWhere((it) => compareColumnByFieldName(it.key, columnName), orElse: () => null);

      if (columnInfo != null) {
        result[columnName] = columnInfo.value;
      }
    }
    return result;
  }

  bool _isNullPkEntity(InstanceMirror instanceMirror) {
    bool isNull = _operQueries[DbOperation.insert]
            ._sqlQueries
            .values
            .first
            ._columnsInfo
            .values
            .where((it) => it.relation == ColumnRelation.primaryKey)
            .firstWhere((it) => it.getterToSql(instanceMirror) == null, orElse: () => null) !=
        null;

    print("_isNullPkEntity=$isNull");

    return isNull;
  }

  Future<void> _initSavedOperations({bool isRaiseAbsentPk = true}) async {
    if (_operQueries[DbOperation.insert] != null) return;

    final Map<String, ColumnInfo> entityMetaData =
        await initColumnEntityByTable(_tableName, _typeInstance, _selectQuery, _db);

    if (isRaiseAbsentPk && isAbsentPkColumn(entityMetaData))
      throw Exception("for save operation must be primary key column for entity $entity");

    _fillSavedOperationData(entityMetaData);
  }

  _initCalcFields(Map<String, dynamic> row) {
    final _OperQuery operQuery = _operQueries[DbOperation.select];

    if (operQuery?._sqlQueries != null && operQuery?._sqlQueries[_CALC_MARKER] != null) return;

    final Map<String, ColumnInfo> calcFields = initCalcColumnsByType(_typeInstance, row);

    _setSelectOperation(_CALC_MARKER, calcFields, DbOperation.select);
  }

  _fillSavedOperationData(Map<String, ColumnInfo> entityMetaData) {
    _fillInsertData(entityMetaData);

    _fillUpdateData(entityMetaData);

    _fillDeleteData(entityMetaData);
  }

  _fillDeleteData(Map<String, ColumnInfo> entityMetaData) {
    Map<String, ColumnInfo> pkColumns = Map<String, ColumnInfo>.from(entityMetaData)
      ..removeWhere((k, v) => v.relation != ColumnRelation.primaryKey);

    final String deleteQuery = getDeleteQuery(_tableName, pkColumns.keys.toList());

    final operQuery = _OperQuery(deleteQuery, pkColumns);

    _operQueries[DbOperation.delete] = operQuery;
  }

  _fillUpdateData(Map<String, ColumnInfo> entityMetaData) {
    Map<String, ColumnInfo> updateColumns = Map<String, ColumnInfo>.from(entityMetaData)
      ..removeWhere(
          (k, v) => v.relation == ColumnRelation.calculated || v.relation == ColumnRelation.primaryKey);

    final columnsUpdateList = updateColumns.keys.toList();

    Map<String, ColumnInfo> pkColumns = Map<String, ColumnInfo>.from(entityMetaData)
      ..removeWhere((k, v) => v.relation != ColumnRelation.primaryKey);

    final pkColumnsList = pkColumns.keys.toList();

    updateColumns.addAll(pkColumns);

    final String updateQuery = getUpdateQuery(_tableName, columnsUpdateList, pkColumnsList);

    final operQuery = _OperQuery(updateQuery, updateColumns);

    _operQueries[DbOperation.update] = operQuery;
  }

  _fillInsertData(Map<String, ColumnInfo> entityMetaData) {
    Map<String, ColumnInfo> savedColumns = Map<String, ColumnInfo>.from(entityMetaData)
      ..removeWhere((k, v) => v.relation == ColumnRelation.calculated);

    final savedColumnNames = savedColumns.keys.toList();

    final String insertQuery = getInsertQuery(_tableName, savedColumnNames);

    final operQuery = _OperQuery(insertQuery, savedColumns);

    _operQueries[DbOperation.insert] = operQuery;
  }
}
