import 'package:reflectable/mirrors.dart';

import 'annotation/annotations.dart';
import 'func.dart';
import 'idiomatic.dart';

Entity getEntityAnnotation(Type type) =>
    entity.reflectType(type)?.metadata?.firstWhere((it) => it is Entity, orElse: () => null);

enum ColumnRelation {
  normal,
  primaryKey,
  calculated // readonly
}

class ColumnInfo {
  final String _varName;
  final ConverterSql _converterFromSql;
  final ConverterSql _converterToSql;

  final String _calcExpression; // for primaryKey without params, for calculated - one param - id Entity

  final ColumnRelation _relation;
  final QueryAbstract _queryRef;

  const ColumnInfo(
      [this._varName,
      this._converterFromSql,
      this._converterToSql,
      this._calcExpression,
      this._queryRef,
      this._relation = ColumnRelation.normal]);

  ColumnRelation get relation => _relation;

  String get calcExpression => _calcExpression;

  Future<void> setterFromSql(InstanceMirror instance, Object sqlValue) async {
    Object value =
        _queryRef != null ? (await _queryRef.getEntityById(sqlValue)) : _converterFromSql(sqlValue);

    instance.invokeSetter(_varName, value);
  }

  Object getterToSql(InstanceMirror instance) => _queryRef != null
      ? (_queryRef.getIdValueFromEntity(instance.invokeGetter(_varName)))
      : _converterToSql(instance.invokeGetter(_varName));

  @override
  String toString() => "ColumnInfo _varName:$_varName relation:$relation calcExpression:$calcExpression "
      "_converterFromSql: $_converterFromSql _converterToSql: $_converterToSql _queryRef:$_queryRef";
}

const absentColumnInfo = ColumnInfo();

bool compareColumnByFieldName(String fieldName, String sqlColumn) =>
    sqlColumn?.replaceAll('_', '')?.toUpperCase() == fieldName?.replaceAll('_', '')?.toUpperCase();

bool compareColumnByAnnotationName(String annotationName, String sqlColumn) =>
    annotationName?.toUpperCase() == sqlColumn?.toUpperCase();

bool _isExistsColumn(String columnName, Iterable<String> columnNames) =>
    columnNames?.firstWhere((it) => compareColumnByFieldName(columnName, it), orElse: () => null) != null;

typedef Future<List<Map<String, dynamic>>> QuerySelectyData(String query, [List<dynamic> params]);

Future<Map<String, ColumnInfo>> initColumnEntityByTable(
    String tableName, ClassMirror typeInstance, QuerySelectyData selectFunc, DbAbstract db) async {
  print("initColumnEntityByTable typeInstance:$typeInstance");

  List<Map<String, dynamic>> infoColumnsTable = await selectFunc(_tableInfoSelect(tableName));

  final result = Map<String, ColumnInfo>();

  for (final row in infoColumnsTable) {
    final columnName = row["name"].toString();

    final MapEntry<String, VariableMirror> field = _getFieldByColumnName(typeInstance, columnName);

    if (field == null) continue;

    final SqlType sqlType = aliasToSqlType(row["type"].toString());
    final ConverterSql converterFromSql = getFromSqlConverter(sqlType, field.value.reflectedType);

    final QueryAbstract query = (converterFromSql == stubEntityConverter)
        ? _getFieldEntityQuery(field.value.reflectedType, db)
        : null;

    final ConverterSql converterToSql = getToSqlConverter(sqlType, field.value.reflectedType);

    MapEntry<ColumnRelation, String> relationCalc =
        _getColumnRelationCalc(tableName, columnName, row["pk"].toString(), field.value.metadata);

    final columnInfo =
        ColumnInfo(field.key, converterFromSql, converterToSql, relationCalc.value, query, relationCalc.key);

    result[columnName] = columnInfo;
  }
  return result;
}

Map<String, ColumnInfo> initCalcColumnsByType(ClassMirror typeInstance, Map<String, dynamic> row) {
  final Iterable<MapEntry<String, DeclarationMirror>> calcList = typeInstance?.declarations?.entries?.where(
      (it) =>
          (it?.value is VariableMirror) &&
          (it?.value?.metadata != null) &&
          it?.value?.metadata?.firstWhere(
                  (annot) => annot is Calc /*&& annot.selectById?.isNotEmpty == true*/,
                  orElse: () => null) !=
              null);

  final Map<String, ColumnInfo> opers = Map<String, ColumnInfo>();

  if (calcList?.isNotEmpty != true) return opers;

  for (final calcField in calcList) {
    final columnName = _getColumnNameByVariable(calcField.value) ?? calcField.key;

    final sqlValue = row == null ? null : (row[columnName.toUpperCase()] ?? row[columnName.toLowerCase()]);

    opers[columnName] = _createCalcColumnInfo(calcField, sqlValue);
  }
  return opers;
}

ColumnInfo _createCalcColumnInfo(MapEntry<String, DeclarationMirror> calcField, Object sqlValue) {
  MapEntry<ColumnRelation, String> relation = _getCalcRelation(calcField.value?.metadata);

  SqlType sqlType = valueToSqlType(sqlValue);

  final ConverterSql converterFromSql =
      getFromSqlConverter(sqlType, (calcField.value as VariableMirror).reflectedType);

  return ColumnInfo(calcField.key, converterFromSql, null, relation.value, null, relation.key);
}

QueryAbstract _getFieldEntityQuery(Type entityType, DbAbstract db) {
  final QueryAbstract query = db.getQuery(entityType);

  if (query == null) throw Exception("Query не создан для entity $entityType");

  return query;
}

Map<String, ColumnInfo> addAbsentColumns(
    Map<String, ColumnInfo> columns, Map<String, dynamic> row, ClassMirror typeInstance, DbAbstract db) {
  for (final columnEntry in row.entries) {
    if (_isExistsColumn(columnEntry.key, columns.keys)) continue;

    columns[columnEntry.key] = _initSelectColumn(columnEntry.key, columnEntry.value, typeInstance, db);
  }
  return columns;
}

bool isAbsentPkColumn(Map<String, ColumnInfo> entityMetaData) =>
    entityMetaData.values.firstWhere((it) => it.relation == ColumnRelation.primaryKey, orElse: () => null) ==
    null;

ColumnInfo _initSelectColumn(String columnName, Object sqlValue, ClassMirror typeInstance, DbAbstract db) {
  final MapEntry<String, VariableMirror> field = _getFieldByColumnName(typeInstance, columnName);

  if (field == null) return absentColumnInfo;

  final SqlType sqlType = sqlValue == null ? null : valueToSqlType(sqlValue);
  final ConverterSql converterFromSql = getFromSqlConverter(sqlType, field.value.reflectedType);

  final QueryAbstract query =
      (converterFromSql == stubEntityConverter) ? _getFieldEntityQuery(field.value.reflectedType, db) : null;

  MapEntry<ColumnRelation, String> relationCalc = _getCalcRelation(field.value.metadata);

  return ColumnInfo(field.key, converterFromSql, null, relationCalc.value, query, relationCalc.key);
}

MapEntry<ColumnRelation, String> _getColumnRelationCalc(
    String table, String columnTable, String isPkColumn, List<Object> metadata) {
  return _getPrimaryKeyRelation(table, columnTable, isPkColumn, metadata) ?? _getCalcRelation(metadata);
}

MapEntry<ColumnRelation, String> _getPrimaryKeyRelation(
    String table, String columnTable, String isPkColumn, List<Object> metadata) {
  var relation = isPkColumn == "1" ? ColumnRelation.primaryKey : ColumnRelation.normal;

  String idAnnotation = _getIdAnnotation(metadata);
  if (idAnnotation != null) {
    relation = ColumnRelation.primaryKey;
  }

  if (relation != ColumnRelation.primaryKey) return null;

  if (idAnnotation?.isNotEmpty != true) {
    idAnnotation = _defaultGenerateId(columnTable, table);
  }

  return MapEntry(relation, idAnnotation);
}

MapEntry<ColumnRelation, String> _getCalcRelation(List<Object> metadata) {
  String calcAnnotation = _getCalcAnnotation(metadata);

  final relation = calcAnnotation != null ? ColumnRelation.calculated : ColumnRelation.normal;

  return MapEntry(relation, calcAnnotation);
}

String _defaultGenerateId(String idColumn, String table) =>
    "select COALESCE( MAX($idColumn), 0) + 1 MAX_ID from $table";

String _tableInfoSelect(String tableName) => "pragma table_info($tableName)";

MapEntry<String, VariableMirror> _getFieldByColumnName(ClassMirror typeInstance, String columnName) =>
    _getFieldByAnnotation(typeInstance, columnName) ?? _getFieldByName(typeInstance, columnName);

MapEntry<String, VariableMirror> _getFieldByAnnotation(ClassMirror typeInstance, String annotationName) {
  final annot = typeInstance?.declarations?.entries?.firstWhere(
      (it) =>
          (it?.value is VariableMirror) &&
          (it?.value?.metadata != null) &&
          it?.value?.metadata?.firstWhere(
                  (annotation) =>
                      annotation is Column && compareColumnByAnnotationName(annotation?.name, annotationName),
                  orElse: () => null) !=
              null,
      orElse: () => null);

  return annot;
}

MapEntry<String, VariableMirror> _getFieldByName(ClassMirror typeInstance, String columnName) {
  final field = typeInstance?.declarations?.entries?.firstWhere(
      (it) =>
          (it.value is VariableMirror) &&
          compareColumnByFieldName(it.key, columnName) &&
          it.value.metadata?.firstWhere((annot) => annot is Column, orElse: () => null) == null,
      orElse: () => null);

  if (field == null) return null;

  return MapEntry<String, VariableMirror>(field.key, field.value);
}

String _getColumnNameByVariable(VariableMirror variable) {
  final Column firstColumn = variable?.metadata
      ?.firstWhere((col) => col is Column && col?.name?.isNotEmpty == true, orElse: () => null);

  return firstColumn?.name;
}

String _getIdAnnotation(List<Object> metadataColumn) {
  final Id id = metadataColumn?.firstWhere((it) => it is Id, orElse: () => null);

  return id == null ? null : (id.querySequence == null ? "" : id.querySequence.trim());
}

String _getCalcAnnotation(List<Object> metadataColumn) {
  final Calc calc = metadataColumn?.firstWhere((it) => it is Calc, orElse: () => null);

  return calc == null ? null : (calc.selectById == null ? "" : calc.selectById.trim());
}
