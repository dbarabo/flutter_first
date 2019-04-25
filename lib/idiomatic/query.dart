import 'package:flutter_first/idiomatic/reflect.dart';
import 'package:flutter_first/idiomatic/sql_func.dart';
import 'package:reflectable/mirrors.dart';
import 'package:reflectable/reflectable.dart';

import 'annotation/annotations.dart';
import 'idiomatic.dart';

class _EntityMetaData {

  Map<String, ColumnInfo> _columnsInfo;

  _EntityMetaData(this._columnsInfo);
}

class _OperQuery {
  final _sqlQueries = Map<String, _EntityMetaData>();

  _OperQuery(String query,  Map<String, ColumnInfo> columnsInfo) {
    _sqlQueries[query] = _EntityMetaData(columnsInfo);
  }

  put(String query,  Map<String, ColumnInfo> columnsInfo) {
    _sqlQueries[query] = _EntityMetaData(columnsInfo);
  }
}

class Query<T> implements QueryAbstract<T> {
  final DbAbstract _db;
  final Map<DbOperation, _OperQuery> _operQueries = Map<DbOperation, _OperQuery>();

  String _tableName;
  ClassMirror _typeInstance;

  List<T> mainList;

  Query(this._db ) {
    _db.addQuery(this, T);

    final entityByType = getEntityAnnotation(T);

    if(entityByType == null) throw Exception("$T is not contains @entity annotation");

    _tableName = entityByType.tableName;

    _typeInstance = entity.reflectType(T) as ClassMirror;
  }

  @override
  Future<T> save(T entityInstance) async {

    if(_tableName?.isNotEmpty != true) throw Exception("$entity is not contains tableName for @Entity annotation");

    await _initSavedOperations();

    final InstanceMirror instanceMirror = entity.reflect(entityInstance);

    if(_isNullPkEntity(instanceMirror) ) {
      await _insertEntity(instanceMirror);
      await _insertToMainList(entityInstance);
    } else {
      await _updateEntity(instanceMirror);
    }

    // TODO calc values and sent listener update
    return entityInstance;
  }

  @override
  Future<void> delete(T entityInstance) async {
    if(_tableName?.isNotEmpty != true) throw Exception("$entity is not contains tableName for @Entity annotation");

    await _initSavedOperations();

    final InstanceMirror instanceMirror = entity.reflect(entityInstance);

    await _deleteEntity(instanceMirror);

    await _removeFromMainList(entityInstance);
  }

  @override
  Future<T> selectOne(String query, [List params]) async {

    final List<T> resultList = await select(query, params);

    return resultList?.isNotEmpty == true ? resultList.first : null;
  }

  @override
  Future<List<T>> select(String query, [List<dynamic> params]) async {

    List<Map<String, dynamic>> sqlResult = await _selectQuery(query, params);

    if(sqlResult?.isNotEmpty != true) return null;

    final queryUpper = query.trim().toUpperCase();

    _initSelectOperations(queryUpper, sqlResult[0]);

    final Map<String, ColumnInfo> columnsInfo = _operQueries[DbOperation.select]?._sqlQueries[queryUpper]?._columnsInfo;

    final List<T> result = List<T>(sqlResult.length);
    int index = 0;
    for(Map<String, dynamic> row in sqlResult) {

      result[index] = await _fromSqlRow(row, columnsInfo);
      index++;
    }
    return result;
  }

  @override
  Future<List<T>> get getMainEntityList async {
    if(mainList == null) {
      mainList = await _initDefaultMainSelect();
    }
    return mainList;
  }

  @override
  Future<T> getEntityById(Object id) async {

    if(id == null) return null;

    List<T> list = await getMainEntityList;

    if(list?.isNotEmpty != true) return null;

    ColumnInfo pkColumn = _getFirstPkColumnInfo();

    if(pkColumn == null) throw Exception("id annotation not found for entity $T");

    final T find = list.firstWhere((it) => pkColumn.getterToSql( entity.reflect(it) ) == id, orElse: ()=> null);

    return find;
  }

  @override
  Object getIdValueFromEntity(T entityObject) {
    if(entityObject == null) return null;

    ColumnInfo pkColumn = _getFirstPkColumnInfo();

    if(pkColumn == null) throw Exception("id annotation not found for entity $T");

    return pkColumn.getterToSql( entity.reflect(entityObject) );
  }

  ColumnInfo _getFirstPkColumnInfo() {
    for (var oper in DbOperation.values) {
      final _OperQuery operQuery = _operQueries[oper];
      if(operQuery?._sqlQueries == null) continue;

      for(_EntityMetaData entityData in operQuery._sqlQueries.values) {
        ColumnInfo colInfo = entityData?._columnsInfo?.values
          ?.firstWhere((col)=> col?.relation == ColumnRelation.primaryKey, orElse: ()=> null);

        if(colInfo != null) return colInfo;
      }
    }
    return null;
  }

  Future<List<T>> _initDefaultMainSelect() async {
    List<T> list = List<T>();

    String query = defaultSelect(_tableName);

    List<T> selectList = await select(query);

    if(selectList?.isNotEmpty == true) {
      list.addAll(selectList);
    }

    return list;
  }

  Future<List<Map<String, dynamic>>> _selectQuery(String query, [List<dynamic> params]) async {

    print("_selectQuery:$query");

    final dbOpen = await _db.getDb();

    return await ( params?.isNotEmpty == true ? dbOpen.rawQuery(query, params) : dbOpen.rawQuery(query)  );
  }

  Future<void> _execute(String query, [List<dynamic> params]) async {
    final dbOpen = await _db.getDb();

    print("_execute=$query");

    for(var par in params) {
      print("par=$par");
    }

    return ( params?.isNotEmpty == true ? dbOpen.execute(query, params) : dbOpen.execute(query) );
  }

  Future<Object> _selectValue(String query, [List<dynamic> params]) async {
    print("_selectValue: $query");

    List<Map<String, dynamic>> list = await _selectQuery(query, params);

    return (list?.isNotEmpty == true) ? list[0].values.first : null;
  }

  Future<T> _fromSqlRow(Map<String, dynamic> row, Map<String, ColumnInfo> columnsInfo) async {

    final T instance = _typeInstance.newInstance("", List());

    final InstanceMirror instanceMirror = entity.reflect(instance);

    for(final columnEntry in row.entries) {

      final columnInfo = columnsInfo[columnEntry.key];

      if(columnInfo == absentColumnInfo) continue;

      await columnInfo.setterFromSql(instanceMirror, columnEntry.value);
    }
    return instance;
  }

  Future<void> _deleteEntity(InstanceMirror instanceMirror) async => _executeFirst(DbOperation.delete, instanceMirror);

  Future<void> _insertToMainList(T entityInstance) async {

    final mainList = await getMainEntityList;

    mainList?.add(entityInstance);
  }

  Future<void> _removeFromMainList(T entityInstance) async {

    final mainList = await getMainEntityList;

    mainList?.remove(entityInstance);
  }

  Future<void> _updateEntity(InstanceMirror instanceMirror) async => _executeFirst(DbOperation.update, instanceMirror);

  Future<void> _insertEntity(InstanceMirror instanceMirror) async {

    final Iterable<ColumnInfo> pkCalc = _operQueries[DbOperation.insert]._sqlQueries.values.first._columnsInfo.values
        .where((it)=> it.relation == ColumnRelation.primaryKey && it.calcExpression?.isNotEmpty == true);

    for (var pkColumn in pkCalc) {
      print("pkValue _selectValue calc:${pkColumn.calcExpression}");

      Object pkValue = await _selectValue(pkColumn.calcExpression);

      print("pkValue after calc:$pkValue");

      await pkColumn.setterFromSql(instanceMirror, pkValue);
    }
    return _executeFirst(DbOperation.insert, instanceMirror);
  }

  Future<void> _executeFirst(DbOperation operation, InstanceMirror instanceMirror) {

    final String execQuery = _operQueries[operation]._sqlQueries.keys.first;

    print("_executeFirst:$execQuery");

    final params = _operQueries[operation]._sqlQueries.values.first._columnsInfo.values
        .map((it)=> it.getterToSql(instanceMirror)).toList();

    print("_executeFirst params:$params");

    return _execute(execQuery, params);
  }

  Future<void> _initSelectOperations(String query, Map<String, dynamic> row) async {
    final _OperQuery operQuery = _operQueries[DbOperation.select];

    if(operQuery != null && operQuery?._sqlQueries != null && operQuery?._sqlQueries[query] != null) return;

    Map<String, ColumnInfo> copyColumns = _operQueries.length != 0
        ? _copyOperQueriesFromOther(row.keys) : await _initAllOperations(row.keys);

    if(copyColumns.length < row.length) {
      copyColumns = addAbsentColumns(copyColumns, row, _typeInstance, _db);
    }
    _setSelectOperation(query, copyColumns);
  }

  _setSelectOperation(String query, Map<String, ColumnInfo> columns) async {
    final _OperQuery operQuery = _operQueries[DbOperation.select] ?? _OperQuery(query, columns);

    _operQueries[DbOperation.select] ??= operQuery;

    operQuery.put(query, columns);
  }

  Future<Map<String, ColumnInfo>> _initAllOperations(Iterable<String> columnNames) async {

    if(_tableName?.isNotEmpty == true) {
      await _initSavedOperations(isRaiseAbsentPk: false);

      return _copyOperQueriesFromOther(columnNames);
    }
    return Map<String, ColumnInfo>();
  }

  Map<String, ColumnInfo> _copyOperQueriesFromOther(Iterable<String> columnNames) {

    final Iterable<Map<String, ColumnInfo>> operMaps = _operQueries?.entries
        ?.where((it) => it.key == DbOperation.insert || it.key == DbOperation.insert &&
        (it?.value?._sqlQueries?.values?.length ?? 0) > 0)
        ?.map((it) => it.value._sqlQueries.values)
        ?.expand((it) => it)?.where((it)=> it != null)
        ?.map((it) => it._columnsInfo);

    final Map<String, ColumnInfo> opers = Map<String, ColumnInfo>();
    for(final map in operMaps) {
      opers.addAll(map);
    }
    final Map<String, ColumnInfo> result = Map<String, ColumnInfo>();

    for (final columnName in columnNames) {

      final MapEntry<String, ColumnInfo> columnInfo = opers?.entries
          ?.firstWhere((it)=> compareColumnByFieldName(it.key, columnName), orElse: ()=>null);

      if(columnInfo != null) {
        result[columnName] = columnInfo.value;
      }
    }
    return result;
  }

  bool _isNullPkEntity(InstanceMirror instanceMirror) {
    bool isNull = _operQueries[DbOperation.insert]._sqlQueries.values.first
        ._columnsInfo.values.where((it)=> it.relation == ColumnRelation.primaryKey)
        .firstWhere((it)=> it.getterToSql(instanceMirror) == null, orElse: ()=>null) != null;

    print("_isNullPkEntity=$isNull");

    return isNull;
  }

  Future<void> _initSavedOperations({bool isRaiseAbsentPk = true}) async {

    if(_operQueries[DbOperation.insert] != null) return;

    final Map<String, ColumnInfo> entityMetaData = await initColumnEntityByTable(_tableName, _typeInstance, _selectQuery, _db);

    entityMetaData.forEach((key, value)=> print("$key $value"));

    if(isRaiseAbsentPk && isAbsentPkColumn(entityMetaData) )
      throw Exception("for save operation must be primary key column for entity $entity");

    _fillSavedOperationData(entityMetaData);
  }

  _fillSavedOperationData(Map<String, ColumnInfo> entityMetaData) {

    _fillInsertData(entityMetaData);

    _fillUpdateData(entityMetaData);

    _fillDeleteData(entityMetaData);
  }

  _fillDeleteData(Map<String, ColumnInfo> entityMetaData) {
    Map<String, ColumnInfo> pkColumns = Map<String, ColumnInfo>.from(entityMetaData)
      ..removeWhere( (k, v) => v.relation != ColumnRelation.primaryKey);

    final String deleteQuery = getDeleteQuery(_tableName, pkColumns.keys.toList() );

    final operQuery = _OperQuery(deleteQuery, pkColumns);

    _operQueries[DbOperation.delete] = operQuery;
  }

  _fillUpdateData(Map<String, ColumnInfo> entityMetaData) {
    Map<String, ColumnInfo> updateColumns = Map<String, ColumnInfo>.from(entityMetaData)
      ..removeWhere( (k, v)=> v.relation == ColumnRelation.calculated || v.relation == ColumnRelation.primaryKey);

    final columnsUpdateList = updateColumns.keys.toList();

    print("columnsUpdateList:$columnsUpdateList");

    Map<String, ColumnInfo> pkColumns = Map<String, ColumnInfo>.from(entityMetaData)
      ..removeWhere( (k, v) => v.relation != ColumnRelation.primaryKey);

    final pkColumnsList = pkColumns.keys.toList();

    print("pkColumnsList:$pkColumnsList");

    updateColumns.addAll(pkColumns);

    final String updateQuery = getUpdateQuery(_tableName, columnsUpdateList, pkColumnsList);

    print("updateQuery:$updateQuery");

    final operQuery = _OperQuery(updateQuery, updateColumns);

    _operQueries[DbOperation.update] = operQuery;
  }

  _fillInsertData(Map<String, ColumnInfo> entityMetaData) {

    print("entityMetaData:$entityMetaData");

    Map<String, ColumnInfo> savedColumns = Map<String, ColumnInfo>.from(entityMetaData)
      ..removeWhere( (k, v)=> v.relation == ColumnRelation.calculated );

    final savedColumnNames = savedColumns.keys.toList();

    print("savedColumnNames:$savedColumnNames");

    final String insertQuery = getInsertQuery(_tableName, savedColumnNames);

    print("insertQuery:$insertQuery");

    final operQuery = _OperQuery(insertQuery, savedColumns);

    _operQueries[DbOperation.insert] = operQuery;
  }
}