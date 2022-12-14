import 'package:ikite/src/parse.dart';
import 'package:test/test.dart';

class Parser with IKiteParser {}

void main() {
  group('Test Adapter convert json to object', () {
    setUp(() {});

    test('Convert json to a 1-depth object', () {
      final parser = Parser();
      parser.registerAdapter(StudentDataAdapter());
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
      final student = parser.parseFromJsonByTypeName<Student>(rawJson);
      assert(student != null);
      assert(student!.firstName == "Narcisse");
      assert(student!.lastName == "Chan");
      assert(student!.email == "NarcisseChan@kite.com");
    });

    test("Convert json to a two-depth object by exact type", () {
      final parser = Parser();
      parser.registerAdapter(StudentDataAdapter());
      parser.registerAdapter(LearningGroupByExactTypeDataAdapter());
      final rawJson = """
{
  "@type": "kite.LearningGroup",
  "@versionMap": {
    "kite.Student": 1,
    "kite.LearningGroup": 1
  },
  "a": {
    "firstName": "Narcisse",
    "lastName": "Chan",
    "email": "NarcisseChan@kite.com"
  },
  "b": {
    "firstName": "Moana",
    "lastName": "Ellery",
    "email": "MoanaEllery@kite.com"
  },
  "c": {
    "firstName": "Justice",
    "lastName": "Apoorva",
    "email": "JusticeApoorva@kite.com"
  }
}
    """;
      final group = parser.parseFromJsonByTypeName<LearningGroup>(rawJson);
      assert(group != null);
      assert(group!.b.email == "MoanaEllery@kite.com");
    });
    test("Convert json to a two-depth object by type name", () {
      final parser = Parser();
      parser.registerAdapter(StudentDataAdapter());
      parser.registerAdapter(LearningGroupByTypeNameDataAdapter());
      final rawJson = """
{
  "@type": "kite.LearningGroup",
  "@versionMap": {
    "kite.Student": 1,
    "kite.LearningGroup": 1
  },
  "a": {
    "@type": "kite.Student",
    "firstName": "Narcisse",
    "lastName": "Chan",
    "email": "NarcisseChan@kite.com"
  },
  "b": {
    "@type": "kite.Student",
    "firstName": "Moana",
    "lastName": "Ellery",
    "email": "MoanaEllery@kite.com"
  },
  "c": {
    "@type": "kite.Student",
    "firstName": "Justice",
    "lastName": "Apoorva",
    "email": "JusticeApoorva@kite.com"
  }
}
    """;
      final group = parser.parseFromJsonByTypeName<LearningGroup>(rawJson);
      assert(group != null);
      assert(group!.c.firstName == "Justice");
    });
    test("Convert json to an object with list by exact type", () {
      final parser = Parser();
      parser.registerAdapter(StudentDataAdapter());
      parser.registerAdapter(LearningGroupByExactTypeDataAdapter());
      parser.registerAdapter(CourseDataAdapter());
      final rawJson = """
{
  "@type": "kite.Course",
  "@versionMap": {
    "kite.Student": 1,
    "kite.LearningGroup": 1,
    "kite.Course": 1
  },
  "name":"Compiler",
  "groups": [
    {
      "a": {
        "firstName": "Narcisse",
        "lastName": "Chan",
        "email": "NarcisseChan@kite.com"
      },
      "b": {
        "firstName": "Moana",
        "lastName": "Ellery",
        "email": "MoanaEllery@kite.com"
      },
      "c": {
        "firstName": "Justice",
        "lastName": "Apoorva",
        "email": "JusticeApoorva@kite.com"
      }
    },
    {
      "a": {
        "firstName": "Kohaku",
        "lastName": "Erdem",
        "email": "KohakuErdem@kite.com"
      },
      "b": {
        "firstName": "Hà",
        "lastName": "Ekin",
        "email": "HàEkin@kite.com"
      },
      "c": {
        "firstName": "Suman",
        "lastName": "Aanakwad",
        "email": "SumanAanakwad@kite.com"
      }
    }
  ]
}
      """;
      final course = parser.parseFromJsonByTypeName(rawJson);
      assert(course != null);
      assert(course!.name == "Compiler");
      assert(course!.groups.length == 2);
      assert(course!.groups[1].b.lastName == "Ekin");
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
  Map<String, dynamic> toJson(ParseContext ctx, Student obj) {
    throw UnimplementedError();
  }
}

class LearningGroup {
  final Student a;
  final Student b;
  final Student c;

  LearningGroup(this.a, this.b, this.c);
}

class LearningGroupByTypeNameDataAdapter
    implements IKiteDataAdapter<LearningGroup> {
  @override
  String get typeName => "kite.LearningGroup";

  @override
  LearningGroup fromJson(ParseContext ctx, Map<String, dynamic> json) {
    return LearningGroup(
      ctx.parseFromJsonByTypeName<Student>(json["a"])!,
      ctx.parseFromJsonByTypeName<Student>(json["b"])!,
      ctx.parseFromJsonByTypeName<Student>(json["c"])!,
    );
  }

  @override
  Map<String, dynamic> toJson(ParseContext ctx, LearningGroup obj) {
    throw UnimplementedError();
  }
}

class LearningGroupByExactTypeDataAdapter
    implements IKiteDataAdapter<LearningGroup> {
  @override
  String get typeName => "kite.LearningGroup";

  @override
  LearningGroup fromJson(ParseContext ctx, Map<String, dynamic> json) {
    return LearningGroup(
      ctx.parseFromJsonByExactType<Student>(json["a"])!,
      ctx.parseFromJsonByExactType<Student>(json["b"])!,
      ctx.parseFromJsonByExactType<Student>(json["c"])!,
    );
  }

  @override
  Map<String, dynamic> toJson(ParseContext ctx, LearningGroup obj) {
    throw UnimplementedError();
  }
}

class Course {
  final String name;
  final List<LearningGroup> groups;

  Course(this.name, this.groups);
}

class CourseDataAdapter implements IKiteDataAdapter<Course> {
  @override
  String get typeName => "kite.Course";

  @override
  Course fromJson(ParseContext ctx, Map<String, dynamic> json) {
    return Course(
      json["name"] as String,
      ctx.parseFormJsonNonnullListByExactType<LearningGroup>(json["groups"]),
    );
  }

  @override
  Map<String, dynamic> toJson(ParseContext ctx, Course obj) {
    throw UnimplementedError();
  }
}
