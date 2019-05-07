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

  AccountType get accountType => AccountType.byDbValue(type);
  set categoryType(AccountType accountType) => type = accountType.dbValue;

  int sync;

  int isUseDebt = 0;

  DateTime closed;

  @readOnly
  double rest;

  Account([this.name, this.currency, this.type]);

  @override
  String toString() =>
      "Account id:$id name:$name description:$description currency:$currency type:$type accountType:$accountType accountisUseDebt:$isUseDebt closed:$closed rest:$rest";
}

class AccountType {
  final int dbValue;

  final String label;

  const AccountType._internal(this.dbValue, this.label);

  static const CURRENT = AccountType._internal(0, "Текущие (оборотные)");
  static const CREDIT = AccountType._internal(1, "Расходные (кредиты)");
  static const DEPOSIT = AccountType._internal(2, "Доходные (вклады)");

  static const List<AccountType> _values = [CURRENT, CREDIT, DEPOSIT];

  static AccountType byDbValue(int value) => value == null ? null : _values[value];

  @override
  String toString() => label;
}

@Entity("CATEGORY")
class Category {
  int id;

  String name;
  Category parent;

  int type = 0;

  CategoryType get categoryType => CategoryType.byDbValue(type);
  set categoryType(CategoryType categoryType) => type = categoryType.dbValue;

  @readOnly
  double turn;

  int isSelected;

  int sync;

  Category([this.name, this.parent, this.type]);

  @override
  String toString() =>
      "Category id:$id name:$name parent:${parent?.name} type:$type categoryType:$categoryType turn:$turn isSelected:$isSelected sync:$sync";
}

class CategoryType {
  final int dbValue;

  final String label;

  const CategoryType._internal(this.dbValue, this.label);

  static const COST = CategoryType._internal(0, "Расходы");
  static const INCOMES = CategoryType._internal(1, "Доходы");
  static const TRANSFER = CategoryType._internal(2, "Перевод");

  static const List<CategoryType> _values = [COST, INCOMES, TRANSFER];

  static CategoryType byDbValue(int value) => value == null ? null : _values[value];

  @override
  String toString() => label;
}

@Entity("PERSON")
class Person {
  int id;

  String name;

  Person parent;

  String description;

  @readOnly
  double debt;

  @readOnly
  double credit;

  int sync;

  @override
  String toString() => "Person id:$id name:$name parent:${parent?.name} debt:$debt credit:$credit sync:$sync";
}

@Entity("PROJECT")
class Project {
  int id;

  String name;

  Project parent;

  String description;

  int sync;

  @override
  String toString() => "Project id:$id name:$name parent:${parent?.name} sync:$sync";
}

@Entity("PAY")
class Pay {
  int id;

  Account account;

  DateTime created;

  Category category;

  double amount;

  Account accountTo;

  Person person;

  Project project;

  String description;

  double amountTo;

  int sync;

  @override
  String toString() =>
      "Pay id:$id created:$created amount:$amount account:${account?.name} category:${category?.name} accountTo:${accountTo?.name} person:${person?.name} project:${project?.name} description:$description";
}
