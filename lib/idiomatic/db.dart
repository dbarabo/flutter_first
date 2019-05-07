import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'idiomatic.dart';

class Db implements DbAbstract {
  final Map<Type, QueryAbstract> _queries = Map<Type, QueryAbstract>();

  final String _path;
  final String _scriptSqlCreate;
  final int _version;
  final bool _isDeleteExists;
  final bool _isScriptFilePath;

  Database _database;

  Queue<Transaction> _activeTransact = Queue<Transaction>();

  Db(this._path,
      [this._scriptSqlCreate,
      this._isDeleteExists = false,
      this._isScriptFilePath = false,
      this._version = 1]);

  @override
  Future<DatabaseExecutor> get activeTransaction async {
    final transact = _activeTransact.length > 0 ? _activeTransact.last : null;

    return transact != null ? transact : await database;
  }

  @override
  set activationTransaction(Transaction transaction) => _activeTransact.addLast(transaction);

  @override
  Transaction removeLastTransact() => _activeTransact.length == 0 ? null : _activeTransact.removeLast();

  @override
  bool get isOpen => _database?.isOpen ?? false;

  @override
  void addQuery(QueryAbstract query, Type type) => _queries[type] = query;

  @override
  QueryAbstract getQuery(Type type) => _queries[type];

  @override
  Future<Database> get database async {
    if (!isOpen) {
      final databasesPath = await getDatabasesPath();

      final String path = join(databasesPath, _path);
      print("databasesPath:$path");

      bool isExistsDb = await databaseExists(path);
      print("isExistsDb:$isExistsDb");

      print("_isDeleteExists=$_isDeleteExists");
      if (isExistsDb && _isDeleteExists) {
        await deleteDatabase(path);
        isExistsDb = false;
      }

      if (_isNeedCopyAssistDb() && !isExistsDb) {
        await _copyDbTo(path);
      }

      _database = await openDatabase(path, version: _version, onCreate: (Database db, int version) async {
        _createStructureTables(db);
      });
    }
    return _database;
  }

  Future<void> _copyDbTo(String pathTo) async {
    print("_scriptSqlCreate=$_scriptSqlCreate");

    final String dbNamePath = join("assets", "babloz.db");
    print("dbNamePath=$dbNamePath");

    ByteData data = await rootBundle.load(dbNamePath); //rootBundle.load(_scriptSqlCreate);

    List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

    await File(pathTo).writeAsBytes(bytes);
  }

  bool _isNeedCopyAssistDb() {
    if (!_isScriptFilePath || _scriptSqlCreate?.isNotEmpty != true || _path?.isNotEmpty != true) return false;

    final int separ = _scriptSqlCreate.lastIndexOf(RegExp(r'(/|\\)')) + 1;

    final String dbName = _scriptSqlCreate.substring(separ)?.toUpperCase();

    return _path?.toUpperCase() == dbName;
  }

  Future<void> _createStructureTables(Database db) async {
    if (_scriptSqlCreate == null) return;

    final String scriptText = _isScriptFilePath ? await _loadFromFile(_scriptSqlCreate) : _scriptSqlCreate;

    final List<String> commands = scriptText.split(";");

    final batch = db.batch();

    for (final cmd in commands) {
      if ((cmd?.trim()?.length ?? 0) < 5) continue;

      batch.execute(cmd);
    }
    await batch.commit(noResult: true);
  }

  Future<String> _loadFromFile(String filePath) async => rootBundle.loadString(filePath);

  @override
  Future<void> close() async {
    if (isOpen) {
      return _database.close();
    }
  }
}
