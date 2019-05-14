import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'idiomatic.dart';

class DbDefault implements Db {
  final Map<Type, Query> _queries = Map<Type, Query>();

  final DbSettings _dbSettings;

  Database _database;

  Queue<Transaction> _activeTransact = Queue<Transaction>();

  DbDefault(this._dbSettings) : assert(_dbSettings != null);

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
  void addQuery(Query query, Type type) => _queries[type] = query;

  @override
  Query getQuery(Type type) => _queries[type];

  @override
  Future<Database> get database async {
    if (!isOpen) {
      final databasesPath = await getDatabasesPath();

      final String path = join(databasesPath, _dbSettings.name);

      bool isExistsDb = await databaseExists(path);

      if (isExistsDb && (_dbSettings.isDeleteExists == true)) {
        await deleteDatabase(path);
        isExistsDb = false;
      }

      if (_isNeedCopyAssistDb() && !isExistsDb) {
        await _copyDbTo(_dbSettings.pathFileCopyDb, path);
      }

      _database = await openDatabase(path, version: _dbSettings.version ?? 1,
          onCreate: (Database db, int version) async {
        _createStructureTables(db);
      });
    }
    return _database;
  }

  bool _isNeedCopyAssistDb() => _dbSettings.pathFileCopyDb?.isNotEmpty == true;

  Future<void> _copyDbTo(String pathFrom, String pathTo) async {
    ByteData data = await rootBundle.load(pathFrom);

    List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

    await File(pathTo).writeAsBytes(bytes);
  }

  Future<void> _createStructureTables(Database db) async {
    if (_dbSettings.dataScriptSqlCreate?.isNotEmpty != true &&
        _dbSettings.pathFileScriptSqlCreate?.isNotEmpty != true) return;

    final String scriptText = _dbSettings.pathFileScriptSqlCreate?.isNotEmpty == true
        ? await _loadFromFile(_dbSettings.pathFileScriptSqlCreate)
        : _dbSettings.dataScriptSqlCreate;

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
