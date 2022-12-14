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
  T? parseFromJson<T>(String json) {
    final dynamic jObject;
    try {
      jObject = jsonDecode(json);
    } catch (e) {
      assert(false, 'Cannot decode json from "$json". $e');
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
          final ctx =
              ParseContext(_name2Adapters, versionMap.cast<String, int>());
          final rootType = jObject["@type"];
          if (rootType is! String) {
            assert(false, "RootType must be a String.");
            return null;
          } else {
            final rootAdapter = _name2Adapters[rootType];
            if (rootAdapter is! IKiteDataAdapter<T>) {
              assert(false, "RootAdapter doesn't match its type. $T");
              return null;
            } else {
              return rootAdapter.fromJson(ctx, jObject.cast<String, dynamic>());
            }
          }
        } catch (e) {
          assert(false, "Cannot parse object from $json. $e");
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
  Map<String, dynamic> toJson(ParseContext ctx, Map<String, dynamic> json);
}

class ParseContext {
  final Map<String, IKiteDataAdapter> _adapters;
  final Map<String, int> _versionMap;

  const ParseContext(this._adapters, this._versionMap);

  /// Throw [NoSuchDataAdapterException] if [typeName] doesn't correspond to a [IKiteDataAdapter]
  IKiteDataAdapter<T> findAdapterBy<T>(String typeName) {
    final adapter = _adapters[typeName];
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
      final adapter = _adapters[typeName];
      if (adapter == null) {
        throw NoSuchDataAdapterException(typeName);
      } else {
        return adapter as IKiteDataAdapter<T>;
      }
    }
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
