import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:flutter/services.dart' show rootBundle;

import 'idiomatic.dart';

class Db implements DbAbstract {

  final Map<Type, QueryAbstract> _queries = Map<Type, QueryAbstract>();

  final String _path;
  final String _scriptSqlCreate;
  final int _version;
  final bool _isDeleteExists;
  final bool _isScriptFilePath;

  Database _database;

  Db(this._path, [this._scriptSqlCreate, this._isDeleteExists = false, this._isScriptFilePath = false, this._version = 1]);

  @override
  bool get isOpen => _database?.isOpen ?? false;

  @override
  void addQuery(QueryAbstract query, Type type) => _queries[type] = query;

  @override
  QueryAbstract getQuery(Type type) => _queries[type];

  @override
  Future<Database> getDb() async {
    if(!isOpen) {
      final databasesPath = await getDatabasesPath();

      print("_isDeleteExists=$_isDeleteExists");
      if(_isDeleteExists) {
        await deleteDatabase(databasesPath);
      }
      final String path = join(databasesPath, _path);
      print("databasesPath:$path");

      _database = await openDatabase(path, version: _version,
          onCreate: (Database db, int version) async {
            _createStructureTables(db);
          });

    }
    return _database;
  }

  Future<void> _createStructureTables(Database db) async {
    if(_scriptSqlCreate == null) return;

    final String scriptText = _isScriptFilePath ? await _loadFromFile(_scriptSqlCreate) : _scriptSqlCreate;

    final List<String> commands = scriptText.split(";");

    final batch = db.batch();

    for(final cmd in commands) {
      if((cmd?.trim()?.length ?? 0) < 5) continue;

      batch.execute(cmd);
    }
    await batch.commit(noResult: true);
  }

  Future<String> _loadFromFile(String filePath) async => rootBundle.loadString(filePath);

  @override
  Future<void> close() async {
    if(isOpen) {
      return _database.close();
    }
  }
}