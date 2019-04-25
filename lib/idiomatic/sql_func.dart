
String getDeleteQuery(String tableName, List<String> pkColumnsList) {

  final whereColumns = pkColumnsList.map((name) => "$name = ?").join(", ");

  return "DELETE FROM $tableName WHERE $whereColumns";
}

String getUpdateQuery(String tableName, List<String> columnsUpdateList, List<String> pkColumnsList) {

  final columnsUpdate = columnsUpdateList.map((name)=> "$name = ?").join(", ");

  final whereColumns = pkColumnsList.map((name) => "$name = ?").join(", ");

  return "UPDATE $tableName SET $columnsUpdate WHERE $whereColumns";
}

String getInsertQuery(String tableName, List<String> columnList) {

  final columns = columnList.join(", ");

  final quest = columnList.map((it) => "?").join(", ");

  return "INSERT INTO $tableName ($columns) VALUES ($quest)";
}

String defaultSelect(String tableName) => "SELECT * FROM $tableName";