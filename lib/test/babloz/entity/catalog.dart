import 'package:flutter_first/idiomatic/annotation/annotations.dart';

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

  DateTime closed;

  Account([this.name, this.currency, this.type]);

  @override
  String toString() =>
      "Account id:$id name:$name description:$description currency:$currency type:$type isUseDebt:$isUseDebt closed:$closed";
}
