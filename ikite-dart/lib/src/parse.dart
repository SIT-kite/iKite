import 'dart:convert';

/// [IKiteConverter] mixin is used to convert object from/to json.
mixin IKiteConverter {
  final Map<String, DataAdapter> _name2Adapters = {};
  final Map<Type, DataAdapter> _type2Adapters = {};
  final Map<String, List<Migration>> _name2Migrations = {};

  /// Register the [adapter].
  /// If the [adapter.typeName] was registered, the old one will be overridden.
  /// In debug mode, the assert will be failed.
  void registerAdapter<T>(DataAdapter<T> adapter) {
    assert(!_name2Adapters.containsKey(adapter.typeName),
        "Two adapters with the same type should be avoided.");
    assert(!_type2Adapters.containsKey(T),
        "Two adapters with the same type should be avoided.");
    _name2Adapters[adapter.typeName] = adapter;
    _type2Adapters[T] = adapter;
  }

  /// Register the [migration].
  /// And resort them by [Migration.migrateTo].
  void registerMigration<T>(Migration<T> migration) {
    final migrations = _name2Migrations[migration.typeName] ?? <Migration<T>>[];
    migrations.add(migration);
    migrations.sort((a, b) => a.migrateTo.compareTo(b.migrateTo));
    _name2Migrations[migration.typeName] = migrations;
  }

  /// Return whether the adapter of [typeName] has been registered.
  bool hasAdapterOf(String typeName) => _name2Adapters.containsKey(typeName);

  /// Return whether the migration of [typeName] has been registered.
  /// If [to] is not null, the specific migration version will be checked.
  bool hasMigrationOf(String typeName, {int? to}) {
    if (to == null) {
      return _name2Migrations.containsKey(typeName);
    } else {
      final migrations = _name2Migrations[typeName];
      return migrations != null
          ? migrations.any((m) => m.migrateTo == to)
          : false;
    }
  }

  /// Restore an object of [T] from an json object by its type name.
  /// [json] as a root must have a type and a version map as mentioned below:
  /// ```json
  /// {
  ///   "@type": "kite.Student",
  ///   "@versionMap":{
  ///     "kite.Credential": 1,
  ///     "kite.Parent": 1
  ///   }
  /// }
  /// ```
  /// The version map is used to determine how many types are used and what their versions exactly are in this object.
  /// If the versions between two json are not matched, the migrations will be performed in sequence.
  ///
  /// Return the object of exact [T] if it succeeded. Otherwise, null will be returned.
  /// In debug mode, the assert will be failed.
  T? restoreByTypeName<T>(String json, {bool strict = false}) {
    final dynamic jObject;
    try {
      jObject = jsonDecode(json);
    } catch (e) {
      assert(false, 'Cannot decode json from "json". $e');
      return null;
    }
    if (jObject is! Map) {
      assert(false, "Only json object is allowed to parse.");
      return null;
    } else {
      final versionMap = jObject["@versionMap"];
      if (versionMap is! Map) {
        assert(false, "@versionMap must be a Map.");
      } else {
        try {
          final rootTypeName = jObject["@type"];
          if (rootTypeName is! String) {
            assert(false,
                "The @type of root object must be a String.$rootTypeName");
            return null;
          } else {
            final rootAdapter = _name2Adapters[rootTypeName];
            if (rootAdapter is! DataAdapter<T>) {
              assert(false,
                  "The adapter of root object doesn't match its type $T but $rootAdapter.");
              return null;
            } else {
              final versions = versionMap.cast<String, int>();
              final ctx = RestoreContext(
                _name2Adapters,
                _type2Adapters,
                _name2Migrations,
                versions,
                strict: strict,
              );
              final version = versions[rootAdapter.typeName];
              assert(version != null,
                  "${rootAdapter.typeName} is not in version map.");
              var jMap = jObject.cast<String, dynamic>();
              if (version != null && version < rootAdapter.version) {
                jMap = _doMigration(_name2Migrations,
                    from: jMap, by: rootAdapter.typeName);
              }
              return rootAdapter.fromJson(ctx, jMap);
            }
          }
        } catch (e) {
          assert(false, "Cannot parse object from json. $e");
          return null;
        }
      }
    }
    return null;
  }

  /// Restore an object of [T] from an json object by [json].
  /// [json] as a root must have a version map as mentioned below:
  /// ```json
  /// {
  ///   "@versionMap":{
  ///     "kite.Credential": 1,
  ///     "kite.Parent": 1
  ///   }
  /// }
  /// ```
  /// The version map is used to determine how many types are used and what their versions exactly are in this object.
  /// If the versions between two json are not matched, the migrations will be performed in sequence.
  ///
  /// Return the object of exact [T] if it succeeded. Otherwise, null will be returned.
  /// In debug mode, the assert will be failed.
  T? restoreByExactType<T>(String json, {bool strict = false}) {
    final dynamic jObject;
    try {
      jObject = jsonDecode(json);
    } catch (e) {
      assert(false, 'Cannot decode json from "json". $e');
      return null;
    }
    if (jObject is! Map) {
      assert(false,
          "Only json object is allowed to parse but ${jObject.runtimeType}.");
      return null;
    } else {
      final versionMap = jObject["@versionMap"];
      if (versionMap is! Map) {
        assert(
            false, "@versionMap must be a Map but ${versionMap.runtimeType}.");
      } else {
        try {
          final rootAdapter = _type2Adapters[T];
          if (rootAdapter is! DataAdapter<T>) {
            assert(false,
                "The adapter of root object doesn't match its type $T but $rootAdapter.");
            return null;
          } else {
            final versions = versionMap.cast<String, int>();
            final ctx = RestoreContext(
              _name2Adapters,
              _type2Adapters,
              _name2Migrations,
              versions,
              strict: strict,
            );
            final version = versions[rootAdapter.typeName];
            assert(version != null,
                "${rootAdapter.typeName} is not in version map.");
            var jMap = jObject.cast<String, dynamic>();
            if (version != null && version < rootAdapter.version) {
              jMap = _doMigration(_name2Migrations,
                  from: jMap, by: rootAdapter.typeName);
            }
            return rootAdapter.fromJson(ctx, jMap);
          }
        } catch (e) {
          if (strict) {
            rethrow;
          } else {
            return null;
          }
        }
      }
    }
    return null;
  }

  /// Parse an object of [T] to Json.
  /// The corresponding [DataAdapter] of [obj] should be registered.
  ///
  /// [enableTypeAnnotation]: When type annotation is enabled, the @type should be added in each json object.
  /// If so, the restoration can determine the type dynamically.
  String? parseToJson<T>(T obj,
      {bool enableTypeAnnotation = true, bool strict = false}) {
    final adapter = _type2Adapters[T];
    if (adapter is! DataAdapter<T>) {
      assert(false, 'Cannot find adapter of $T but $adapter.');
      return null;
    } else {
      final versionMap = <String, int>{};
      final ctx = ParseContext(
        _type2Adapters,
        versionMap,
        enableTypeAnnotation: enableTypeAnnotation,
        strict: strict,
      );
      ctx.addToVersionMap(adapter);
      final Map<String, dynamic> json;
      try {
        json = adapter.toJson(ctx, obj);
      } catch (e) {
        if (strict) {
          rethrow;
        } else {
          return null;
        }
      }
      ctx.attachVersionMap(json);
      return jsonEncode(json);
    }
  }
}

abstract class DataAdapter<T> {
  /// It corresponds to key, "@type" in json.
  String get typeName;

  /// The [version] of this data adapter.
  /// If it's higher than the json object, the available migrations will be performed.
  int get version => 1;

  /// Convert a json object to an object of [T].
  T fromJson(RestoreContext ctx, Map<String, dynamic> json);

  /// Convert a [T] object to json object.
  Map<String, dynamic> toJson(ParseContext ctx, T obj);
}

/// [Migration] is designed to upgrade the data if the version of [DataAdapter] is higher.
abstract class Migration<T> {
  /// The unique [typeName].
  /// Reserved domain is the naming convention.
  String get typeName;

  /// The target version that will be migrated to.
  int get migrateTo;

  /// Migrate the [old] data to [migrateTo] version.
  Map<String, dynamic> migrate(Map<String, dynamic> old);

  /// Create a migration with delegate.
  factory Migration.of(
    String typeName,
    Map<String, dynamic> Function(Map<String, dynamic> from) delegate, {
    required int to,
  }) =>
      _MigrationDelegateImpl(to, typeName, delegate);
}

class _MigrationDelegateImpl<T> implements Migration<T> {
  @override
  final int migrateTo;

  @override
  final String typeName;

  final Map<String, dynamic> Function(Map<String, dynamic> from) delegate;

  _MigrationDelegateImpl(this.migrateTo, this.typeName, this.delegate);

  @override
  Map<String, dynamic> migrate(Map<String, dynamic> from) => delegate(from);
}

/// Perform the migrations until the latest version in sequence.
Map<String, dynamic> _doMigration(
  Map<String, List<Migration>> name2Migrations, {
  required Map<String, dynamic> from,
  required String by,
}) {
  final migrations = name2Migrations[by];
  assert(migrations != null, "No such migration of $by.");
  if (migrations != null) {
    for (final migration in migrations) {
      from = migration.migrate(from);
    }
    return from;
  } else {
    return from;
  }
}

class RestoreContext {
  final Map<String, DataAdapter> _name2Adapters;
  final Map<Type, DataAdapter> _type2Adapters;
  final Map<String, List<Migration>> _name2Migrations;
  final Map<String, int> _versionMap;
  final bool strict;

  const RestoreContext(
    this._name2Adapters,
    this._type2Adapters,
    this._name2Migrations,
    this._versionMap, {
    this.strict = false,
  });

  DataAdapter<T>? findAdapterOf<T>(String typeName) {
    final adapter = _name2Adapters[typeName];
    if (adapter is! DataAdapter<T>) {
      assert(false, 'Cannot find adapter of $typeName but $adapter.');
      return null;
    } else {
      return adapter;
    }
  }

  /// Find an adapter specified with the key,"@type", in the [json].
  DataAdapter<T>? findAdapterIn<T>(Map<String, dynamic> json) {
    final typeName = json["@type"];
    if (typeName is! String) {
      assert(false, '@type must be a String but $typeName.');
      return null;
    } else {
      final adapter = _name2Adapters[typeName];
      if (adapter is! DataAdapter<T>) {
        assert(false, 'Cannot find adapter of $typeName but $adapter.');
        return null;
      } else {
        return adapter;
      }
    }
  }

  T? restoreByExactType<T>(Map<String, dynamic> json) {
    final adapter = _type2Adapters[T];
    assert(adapter != null, 'Cannot find adapter of $T.');
    if (adapter != null) {
      final version = _versionMap[adapter.typeName];
      assert(version != null, "${adapter.typeName} is not in version map.");
      if (version != null && version < adapter.version) {
        json = _doMigration(_name2Migrations, from: json, by: adapter.typeName);
      }
      final res = adapter.fromJson(this, json);
      if (res is T) {
        return res;
      } else {
        assert(false, 'Cannot parse $T from json.');
        return null;
      }
    }
    return null;
  }

  T? restoreByTypeName<T>(Map<String, dynamic> json) {
    final typeName = json["@type"];
    if (typeName is! String) {
      assert(false, "@type must be a String but $typeName.");
      return null;
    } else {
      final adapter = _name2Adapters[typeName];
      assert(adapter != null, 'Cannot find adapter of "$typeName".');
      if (adapter != null) {
        final version = _versionMap[adapter.typeName];
        assert(version != null, "${adapter.typeName} is not in version map.");
        if (version != null && version < adapter.version) {
          json =
              _doMigration(_name2Migrations, from: json, by: adapter.typeName);
        }
        final res = adapter.fromJson(this, json);
        if (res is T) {
          return res;
        } else {
          assert(false, 'Cannot parse $T from json.');
          return null;
        }
      }
      return null;
    }
  }

  List<T?> restoreNullableListByTypeName<T>(List<dynamic> list) {
    final res = <T?>[];
    for (final obj in list) {
      res.add(obj != null
          ? (_isPrimitive(obj) ? obj : restoreByTypeName<T>(obj))
          : null);
    }
    return res;
  }

  List<T> restoreListByTypeName<T>(List<dynamic> list) {
    final res = <T>[];
    for (final obj in list) {
      res.add(_isPrimitive(obj) ? obj : restoreByTypeName<T>(obj) as T);
    }
    return res;
  }

  List<T?> restoreNullableListByExactType<T>(List<dynamic> list) {
    final res = <T?>[];
    for (final obj in list) {
      res.add(obj != null
          ? (_isPrimitive(obj) ? obj : restoreByExactType<T>(obj))
          : null);
    }
    return res;
  }

  List<T> restoreListByExactType<T>(List<dynamic> list) {
    final res = <T>[];
    for (final obj in list) {
      res.add(_isPrimitive(obj) ? obj : restoreByExactType<T>(obj) as T);
    }
    return res;
  }

  Map<TK, TV?> restoreNullableMapByTypeName<TK, TV>(Map<dynamic, dynamic> map) {
    final res = <TK, TV?>{};
    map.forEach((k, v) {
      res[k as TK] =
          v != null ? (_isPrimitive(v) ? v : restoreByTypeName<TV>(v)) : null;
    });
    return res;
  }

  Map<TK, TV> restoreMapByTypeName<TK, TV>(Map<dynamic, dynamic> map) {
    final res = <TK, TV>{};
    map.forEach((k, v) {
      res[k as TK] = _isPrimitive(v) ? v : restoreByTypeName<TV>(v) as TV;
    });
    return res;
  }

  Map<TK, TV?> restoreNullableMapByExactType<TK, TV>(
      Map<dynamic, dynamic> map) {
    final res = <TK, TV?>{};
    map.forEach((k, v) {
      res[k as TK] =
          v != null ? (_isPrimitive(v) ? v : restoreByExactType<TV>(v)) : null;
    });
    return res;
  }

  Map<TK, TV> restoreMapByExactType<TK, TV>(Map<dynamic, dynamic> map) {
    final res = <TK, TV>{};
    map.forEach((k, v) {
      res[k as TK] = _isPrimitive(v) ? v : restoreByExactType<TV>(v) as TV;
    });
    return res;
  }
}

class ParseContext {
  final Map<Type, DataAdapter> _type2Adapters;
  final Map<String, int> _versionMap;
  final bool strict;

  /// When type annotation is enabled, the @type should be added in each json object.
  /// If so, the restoration can determine the type dynamically.
  final bool enableTypeAnnotation;

  const ParseContext(
    this._type2Adapters,
    this._versionMap, {
    this.enableTypeAnnotation = true,
    this.strict = false,
  });

  Map<String, dynamic> parseToJson<T>(T obj) {
    final adapter = _type2Adapters[T];
    if (adapter is! DataAdapter<T>) {
      throw NoSuchDataAdapterException(obj.runtimeType.toString());
    } else {
      addToVersionMap(adapter);
      return adapter.toJson(this, obj);
    }
  }

  List<Map<String, dynamic>> parseToList<T>(List<T> list) {
    return list.map((e) => parseToJson(e)).toList(growable: false);
  }

  List<Map<String, dynamic>?> parseToNullableList<T>(List<T?> list) {
    return list
        .map((e) => e != null ? parseToJson(e) : null)
        .toList(growable: false);
  }

  Map<dynamic, dynamic> parseToMap<TV>(Map<dynamic, TV> map) {
    return map.map((k, v) => MapEntry(k, _isPrimitive(v) ? v : parseToJson(v)));
  }

  Map<dynamic, dynamic> parseToNullableMap<TV>(Map<dynamic, TV?> map) {
    return map.map((k, v) =>
        MapEntry(k, v != null ? (_isPrimitive(v) ? v : parseToJson(v)) : null));
  }

  /// Add the [adapter.version] into the json.
  void addToVersionMap(DataAdapter adapter) {
    _versionMap[adapter.typeName] = adapter.version;
  }

  /// Attach the version map into the json.
  void attachVersionMap(Map<String, dynamic> json) {
    json["@versionMap"] = _versionMap;
  }
}

class NoSuchDataAdapterException implements Exception {
  final String message;

  const NoSuchDataAdapterException(this.message);

  @override
  String toString() => "NoSuchDataAdapterException($message)";
}

bool _isPrimitive(dynamic v) =>
    v is int || v is bool || v is String || v is double;
