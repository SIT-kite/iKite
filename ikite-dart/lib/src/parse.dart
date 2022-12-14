import 'dart:convert';

/// [IKiteParser] mixin is used to convert object from/to json.
mixin IKiteParser {
  final Map<String, IKiteDataAdapter> _name2Adapters = {};
  final Map<Type, IKiteDataAdapter> _type2Adapters = {};

  /// Register the [adapter].
  /// If the [adapter.typeName] was registered, the old one will be overridden.
  /// In debug mode, the assert will be failed.
  void registerAdapter<T>(IKiteDataAdapter<T> adapter) {
    assert(!_name2Adapters.containsKey(adapter.typeName),
        "Two adapters with the same type should be avoided.");
    assert(!_type2Adapters.containsKey(T),
        "Two adapters with the same type should be avoided.");
    _name2Adapters[adapter.typeName] = adapter;
    _type2Adapters[T] = adapter;
  }

  /// Return whether this [typeName] has been registered.
  bool hasAdapterWith({required String typeName}) =>
      _name2Adapters.containsKey(typeName);

  /// Return whether this [typeName] has been registered.
  bool removeAdapterWith({required String typeName}) =>
      _name2Adapters.containsKey(typeName);

  /// Parse an object of [T] from an json object by [json].
  /// [json] as a root must have a version map:
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
  /// It's useful to do migration if the versions are not matched.
  ///
  /// Return the object of exact [T] if it succeeded. Otherwise, null will be returned.
  /// In debug mode, the assert will be failed.
  T? parseFromJsonByTypeName<T>(String json) {
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
            if (rootAdapter is! IKiteDataAdapter<T>) {
              assert(false,
                  "The adapter of root object doesn't match its type $T but $rootAdapter.");
              return null;
            } else {
              final ctx = ParseContext(
                _name2Adapters,
                _type2Adapters,
                versionMap.cast<String, int>(),
              );
              return rootAdapter.fromJson(ctx, jObject.cast<String, dynamic>());
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

  /// Parse an object of [T] from an json object by [json].
  /// [json] as a root must have a version map:
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
  /// It's useful to do migration if the versions are not matched.
  ///
  /// Return the object of exact [T] if it succeeded. Otherwise, null will be returned.
  /// In debug mode, the assert will be failed.
  T? parseFromJsonByExactType<T>(String json) {
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
          if (rootAdapter is! IKiteDataAdapter<T>) {
            assert(false,
                "The adapter of root object doesn't match its type $T but $rootAdapter.");
            return null;
          } else {
            final ctx = ParseContext(
              _name2Adapters,
              _type2Adapters,
              versionMap.cast<String, int>(),
            );
            return rootAdapter.fromJson(ctx, jObject.cast<String, dynamic>());
          }
        } catch (e) {
          assert(false, "Cannot parse object from json. $e");
          return null;
        }
      }
    }
    return null;
  }
}

abstract class IKiteDataAdapter<T> {
  /// It corresponds to key, "@type" in json.
  String get typeName;

  /// Convert a json object to an object of [T].
  T fromJson(ParseContext ctx, Map<String, dynamic> json);

  /// Convert a [T] object to json object.
  Map<String, dynamic> toJson(ParseContext ctx, T obj);
}

class ParseContext {
  final Map<String, IKiteDataAdapter> _name2Adapters;
  final Map<Type, IKiteDataAdapter> _type2Adapters;
  final Map<String, int> _versionMap;

  const ParseContext(
      this._name2Adapters, this._type2Adapters, this._versionMap);

  /// Throw [NoSuchDataAdapterException] if [typeName] doesn't correspond to a [IKiteDataAdapter]
  IKiteDataAdapter<T> findAdapterBy<T>(String typeName) {
    final adapter = _name2Adapters[typeName];
    if (adapter == null) {
      throw NoSuchDataAdapterException(typeName);
    } else {
      return adapter as IKiteDataAdapter<T>;
    }
  }

  /// Find an adapter specified with the key,"@type", in the [json].
  /// Throw [NoTypeSpecifiedException] if [json] doesn't have the key,"@type", or "@type" is not a String.
  /// Throw [NoSuchDataAdapterException] if "@type" doesn't correspond to a [IKiteDataAdapter].
  IKiteDataAdapter<T> findAdapterIn<T>(Map<String, dynamic> json) {
    final typeName = json["@type"];
    if (typeName is! String) {
      throw NoTypeSpecifiedException(json);
    } else {
      final adapter = _name2Adapters[typeName];
      if (adapter == null) {
        throw NoSuchDataAdapterException(typeName);
      } else {
        return adapter as IKiteDataAdapter<T>;
      }
    }
  }

  T? parseFromJsonByExactType<T>(Map<String, dynamic> json) {
    final adapter = _type2Adapters[T];
    assert(adapter != null, 'Cannot find adapter of $T.');
    if (adapter != null) {
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

  T? parseFromJsonByTypeName<T>(Map<String, dynamic> json) {
    final typeName = json["@type"];
    if (typeName is! String) {
      assert(false, "@type must be a String but $typeName.");
      return null;
    } else {
      final adapter = _name2Adapters[typeName];
      assert(adapter != null, 'Cannot find adapter of "$typeName".');
      if (adapter != null) {
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

  List<T?> parseFormJsonNullableListByTypeName<T>(List<dynamic> list) {
    final res = <T?>[];
    for (final obj in list) {
      res.add(parseFromJsonByTypeName<T>(obj));
    }
    return res;
  }

  List<T> parseFormJsonNonnullListByTypeName<T>(List<dynamic> list) {
    final res = <T>[];
    for (final obj in list) {
      res.add(parseFromJsonByTypeName<T>(obj) as T);
    }
    return res;
  }

  List<T?> parseFormJsonNullableListByExactType<T>(List<dynamic> list) {
    final res = <T?>[];
    for (final obj in list) {
      res.add(parseFromJsonByExactType<T>(obj));
    }
    return res;
  }

  List<T> parseFormJsonNonnullListByExactType<T>(List<dynamic> list) {
    final res = <T>[];
    for (final obj in list) {
      res.add(parseFromJsonByExactType<T>(obj) as T);
    }
    return res;
  }
}

class NoSuchDataAdapterException implements Exception {
  final String message;

  const NoSuchDataAdapterException(this.message);
}

class NoTypeSpecifiedException implements Exception {
  final Map<String, dynamic> json;

  const NoTypeSpecifiedException(this.json);
}

class OverVersionException implements Exception {}
