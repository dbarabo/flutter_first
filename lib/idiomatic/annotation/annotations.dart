import 'package:reflectable/reflectable.dart';

enum DbOperation {
  mainSelect,
  select,
  insert,
  update,
  delete
}

class Calc {
  final String selectById;

  const Calc([this.selectById]);

  @override
  String toString() => "Calc $selectById";
}

const readOnly = Calc();

class Id {
  final String querySequence;

  const Id([this.querySequence]);

  @override
  String toString() => "ID $querySequence";
}

class Column {
  final String name;

  const Column([this.name]);

  @override
  String toString() => "Column $name";
}

class Entity extends Reflectable {
  final String tableName;

  const Entity([this.tableName])
      : super(metadataCapability,
    reflectedTypeCapability,
    invokingCapability
  );

  @override
  String toString() => "Entity $tableName";
}

const entity  = Entity();