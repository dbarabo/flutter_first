
import 'package:flutter_first/idiomatic/annotation/annotations.dart';
import 'package:flutter_first/idiomatic/idiomatic.dart';
import 'package:reflectable/mirrors.dart';

@Entity("CURRENCY")
class Currency {
  int id;

  String name;

  String ext;

  int sync;

  Currency([this.name, this.ext]);

  @override
  String toString() => "Currency id:$id name:$name ext:$ext sync:$sync";
}

@Entity("ACCOUNT")
class Account {

  int id;

  String name;

  String description;

  Currency currency;

  int type = 0;

  int sync;

  int isUseDebt = 0;

  Account([this.name, this.currency, this.type]);

  @override
  String toString() => "Account id:$id name:$name description:$description currency:$currency type:$type isUseDebt:$isUseDebt";
}

Operation transformOperationDef(Operation srcOperation, Object entityItem) {

  switch(srcOperation) {
    case Operation.delete:
      final InstanceMirror instanceMirror = entity.reflect(entityItem);
      instanceMirror.invokeSetter("sync", 2);
      print("delete entity:$entityItem");
      return Operation.update;

    case Operation.insert:
      final InstanceMirror instanceMirror = entity.reflect(entityItem);
      instanceMirror.invokeSetter("sync", 0);
      print("insert entity:$entityItem");
      return Operation.insert;

    case Operation.update:
      final InstanceMirror instanceMirror = entity.reflect(entityItem);
      instanceMirror.invokeSetter("sync", 1);
      print("update entity:$entityItem");
      return Operation.update;

    default: throw Exception("operation not found $srcOperation");
  }
}
