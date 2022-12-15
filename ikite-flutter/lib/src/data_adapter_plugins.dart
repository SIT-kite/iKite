import 'dart:ui';
import 'package:ikite/src/parse.dart';

class ColorDataAdapter extends DataAdapter<Color> {
  @override
  Color fromJson(RestoreContext ctx, Map<String, dynamic> json) {
    // TODO: implement fromJson
    throw UnimplementedError();
  }

  @override
  Map<String, dynamic> toJson(ParseContext ctx, Color obj) {
    // TODO: implement toJson
    throw UnimplementedError();
  }

  @override
  // TODO: implement typeName
  String get typeName => throw UnimplementedError();
}
