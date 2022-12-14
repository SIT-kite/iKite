class IKiteParser {}

abstract class IKiteDataAdapter<T> {
  String get typeName;

  T fromJson(ParseContext ctx, Map<String, dynamic> json);

  Map<String, dynamic> toJson(ParseContext ctx, Map<String, dynamic> json);
}

class ParseContext {
  final Map<String, IKiteDataAdapter> _adapters;

  const ParseContext(this._adapters);

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
