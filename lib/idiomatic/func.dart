
import 'annotation/annotations.dart';

enum SqlType {
  INTEGER, // up to 64bit
  REAL, // double type 64bit IEEE
  TEXT,
  BLOB
}

SqlType aliasToSqlType(String alias) {
  if(alias?.trim()?.isNotEmpty != true) return null;

  var endPos = alias.indexOf("(");
  if(endPos == -1) {
    endPos = alias.length;
  }
  final aliasUpper = alias.substring(0, endPos)?.trim()?.toUpperCase();

  final isDouble =  alias.contains(",");

  switch (aliasUpper) {
    case "INT":
    case "INTEGER":
    case "TINYINT":
    case "SMALLINT":
    case "MEDIUMINT":
    case "BIGINT":
    case "UNSIGNED BIG INT":
    case "INT2":
    case "INT8":

    case "BOOLEAN":
    case "DATE":
    case "DATETIME":
      return SqlType.INTEGER;

    case "CHARACTER":
    case "VARCHAR":
    case "VARYING CHARACTER":
    case "NCHAR":
    case "NATIVE CHARACTER":
    case "NVARCHAR":
    case "TEXT":
    case "CLOB":
      return SqlType.TEXT;

    case "REAL":
    case "DOUBLE":
    case "DOUBLE PRECISION":
    case "FLOAT":
      return SqlType.REAL;

    case "BLOB":
      return SqlType.BLOB;

    case "NUMERIC":
    case "DECIMAL":
      return isDouble ? SqlType.REAL : SqlType.INTEGER;

    default: throw Exception("unsupported type $alias");
  }
}

SqlType valueToSqlType(Object sqlValue) {

  if(sqlValue == null) return null;

  if(sqlValue is int) return SqlType.INTEGER;

  if((sqlValue is num) || (sqlValue is double)) return SqlType.REAL;

  if(sqlValue is String) return SqlType.TEXT;

  throw Exception("unsupported sql type from sql value $sqlValue");
}

typedef Object ConverterSql(Object sqlValue);

ConverterSql getFromSqlConverter(SqlType sqlType, Type reflectedType) {
  switch (reflectedType) {
    case String: return _stringSqlConverter;

    case int: return _getIntConverter(sqlType);

    case double:
    case num: return _getDoubleConverter(sqlType);

    case DateTime: return _getDateTimeConverter(sqlType);

    default: return _getEntityConvertor(sqlType, reflectedType); // throw UnsupportedError("do not convert from sql for type: $reflectedType");
  }
}

ConverterSql _getEntityConvertor(SqlType sqlType, Type reflectedType) {

  entity.reflectType(reflectedType); // check type by entity

  return stubEntityConverter;
}

ConverterSql stubEntityConverter(Object sqlValue) => null;

ConverterSql getToSqlConverter(SqlType sqlType, Type reflectedType) {

  if(_isEntityType(reflectedType) ) return stubEntityConverter;

  switch (sqlType) {
    case SqlType.INTEGER: return _getConverterToSqlInt(reflectedType);

    case SqlType.TEXT: return _stringSqlConverter;

    case SqlType.REAL: return _getConverterToSqlReal(reflectedType);

    default: throw UnsupportedError("do not convert to sql for sqltype: $sqlType");
  }
}

bool _isEntityType(Type reflectedType) => entity.canReflectType(reflectedType);

ConverterSql _getConverterToSqlInt(Type reflectedType) {

  switch (reflectedType) {
    case int:
    case double:
    case num: return _intFromNumConverter;

    case String: return _intFromStringConverter;

    case DateTime: return _intFromDateTimeConverter;

    default: throw UnsupportedError("do not convert to sql INTEGER for type: $reflectedType");
  }
}

ConverterSql _getConverterToSqlReal(Type reflectedType) {
  switch (reflectedType) {
    case int:
    case double:
    case num: return _doubleFromNumConverter;

    case String: return _doubleFromStringConverter;

    case DateTime: return _doubleFromDateTimeConverter;

    default: throw UnsupportedError("do not convert to sql REAL for type: $reflectedType");
  }
}

ConverterSql _getDateTimeConverter(SqlType sqlType) {
  if(sqlType == null) return _dateTimeFromSqlConverter;

  if(sqlType == SqlType.INTEGER || sqlType == SqlType.REAL)  return _dateTimeFromNumConverter;

  if(sqlType == SqlType.TEXT) return _dateTimeFromStringConverter;

  throw UnsupportedError("do not convert sqlType: $sqlType to DateTime");
}

ConverterSql _getDoubleConverter(SqlType sqlType) {
  if(sqlType == null) return _doubleFromSqlConverter;

  if(sqlType == SqlType.INTEGER || sqlType == SqlType.REAL)  return _doubleFromNumConverter;

  if(sqlType == SqlType.TEXT) return _doubleFromStringConverter;

  throw UnsupportedError("do not convert sqlType: $sqlType to double");
}

ConverterSql _getIntConverter(SqlType sqlType) {
  if(sqlType == null) return _intFromSqlConverter;

  if(sqlType == SqlType.INTEGER || sqlType == SqlType.REAL) return _intFromNumConverter;

  if(sqlType == SqlType.TEXT) return _intFromStringConverter;

  throw UnsupportedError("do not convert sqlType: $sqlType to int");
}

Object _stringSqlConverter(Object sqlValue) => sqlValue?.toString();

Object _intFromNumConverter(Object sqlValue) => sqlValue == null ? null : (sqlValue as num).toInt();

Object _intFromStringConverter(Object sqlValue) => sqlValue == null ? null : int.parse(sqlValue);

Object _intFromSqlConverter(Object sqlValue) {
  if(sqlValue == null) return null;

  if(sqlValue is num)  return sqlValue?.toInt() ;

  if (sqlValue is String) return int.parse(sqlValue);

  throw UnsupportedError("do not convert value: $sqlValue with value type ${sqlValue.runtimeType} to int");
}

Object _doubleFromNumConverter(Object sqlValue) => sqlValue == null ? null : (sqlValue as num).toDouble();

Object _doubleFromStringConverter(Object sqlValue) => sqlValue == null ? null : double.parse(sqlValue);

Object _doubleFromSqlConverter(Object sqlValue) {
  if(sqlValue == null) return null;

  if(sqlValue is num)  return sqlValue?.toDouble();

  if (sqlValue is String) return double.parse(sqlValue);

  throw UnsupportedError("do not convert value: $sqlValue with value type ${sqlValue.runtimeType} to double");
}

Object _intFromDateTimeConverter(Object sqlValue) =>
    sqlValue == null ? null : (sqlValue as DateTime).millisecondsSinceEpoch;

Object _doubleFromDateTimeConverter(Object sqlValue) =>
    sqlValue == null ? null : (sqlValue as DateTime).millisecondsSinceEpoch.toDouble();

Object _dateTimeFromNumConverter(Object sqlValue) => sqlValue == null ? null
    : DateTime.fromMillisecondsSinceEpoch((sqlValue as num).toInt());

Object _dateTimeFromStringConverter(Object sqlValue) => sqlValue == null ? null : DateTime.parse(sqlValue);

Object _dateTimeFromSqlConverter(Object sqlValue) {
  if(sqlValue == null) return null;

  if(sqlValue is num) return DateTime.fromMillisecondsSinceEpoch(sqlValue.toInt());

  if(sqlValue is String) {
    return DateTime.parse(sqlValue);
  }

  throw UnsupportedError("do not convert value: $sqlValue with value type ${sqlValue.runtimeType} to DateTime");
}