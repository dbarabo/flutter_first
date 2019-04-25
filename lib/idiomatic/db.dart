import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'idiomatic.dart';

class Db implements DbAbstract {

  final Map<Type, QueryAbstract> _queries = Map<Type, QueryAbstract>();

  final String _path;
  final String _scriptSqlCreate;
  final int _version;
  final bool _isDeleteExists;

  Database _database;

  Db(this._path, [this._scriptSqlCreate, this._isDeleteExists = false, this._version = 1,]);

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

      if(_isDeleteExists) {
        await deleteDatabase(databasesPath);
      }

      print("databasesPath:$databasesPath");
      final String path = join(databasesPath, _path);

      print("path:$path");

      _database = await openDatabase(path, version: _version,
          onCreate: (Database db, int version) async {
            _createStructureTables(db);
          });

    }

    return _database;
  }

  Future<void> _createStructureTables(Database db) async {
    print("_createStructureTables:$_scriptSqlCreate");

    if(_scriptSqlCreate == null) return;

    final List<String> commands = _scriptSqlCreate.split(";");

    final batch = db.batch();

    for(final cmd in commands) {

      print("cmd:$cmd");

      if((cmd?.trim()?.length ?? 0) < 5) continue;

      batch.execute(cmd);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> close() async {
    if(isOpen) {
      return _database.close();
    }
  }
}