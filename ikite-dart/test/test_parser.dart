import 'package:ikite/ikite.dart';
import 'package:ikite/src/parse.dart';
import 'package:test/test.dart';

class Parser with IKiteParser {}

void main() {
  group('Test Adapter convert object to json', () {
    final parser = Parser();
    setUp(() {
      parser.registerAdapter(StudentDataAdapter());
    });

    test('Convert json to a single-depth object', () {
      final rawJson = """
{
  "@type":"kite.Student",
  "@versionMap": {
    "kite.Student": 1
  },
  "firstName": "Narcisse",
  "lastName": "Chan",
  "email": "NarcisseChan@kite.com"
}
    """;
      final student = parser.parseFromJson<Student>(rawJson);
      assert(student != null);
      assert(student!.firstName == "Narcisse");
      assert(student!.lastName == "Chan");
      assert(student!.email == "NarcisseChan@kite.com");
    });
  });
}

class Student {
  final String firstName;
  final String lastName;
  final String email;

  Student(this.firstName, this.lastName, this.email);
}

class StudentDataAdapter implements IKiteDataAdapter<Student> {
  @override
  String get typeName => "kite.Student";

  @override
  Student fromJson(ParseContext ctx, Map<String, dynamic> json) {
    return Student(
      json["firstName"] as String,
      json["lastName"] as String,
      json["email"] as String,
    );
  }

  @override
  Map<String, dynamic> toJson(ParseContext ctx, Map<String, dynamic> json) {
    throw UnimplementedError();
  }
}
