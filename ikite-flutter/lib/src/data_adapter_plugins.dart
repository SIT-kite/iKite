import 'dart:ui';
import 'package:ikite/ikite.dart';

class ColorDataAdapter extends DataAdapter<Color> {
  @override
  String get typeName => "dart.ui.Color";

  @override
  Color fromJson(RestoreContext ctx, Map<String, dynamic> json) {
    return Color(
      json["value"] as int,
    );
  }

  @override
  Map<String, dynamic> toJson(ParseContext ctx, Color obj) {
    return {
      "value": obj.value
    };
  }
}
