import 'package:ikite/src/parse.dart';
import 'package:test/test.dart';

class Parser with IKiteConverter {}

void main() {
  group('Test Adapter convert json to object', () {
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
      final student = parser.restoreByTypeName<Student>(rawJson);
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
      final group = parser.restoreByTypeName<LearningGroup>(rawJson);
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
      final group = parser.restoreByTypeName<LearningGroup>(rawJson);
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
      final course = parser.restoreByTypeName(rawJson);
      assert(course != null);
      assert(course!.name == "Compiler");
      assert(course!.groups.length == 2);
      assert(course!.groups[1].b.lastName == "Ekin");
    });
  });

  group("Test Adapter convert object to json and back", () {
    test("Convert Student to json and back", () {
      final parser = Parser();
      parser.registerAdapter(StudentDataAdapter());
      final a = Student("Narcisse", "Chan", "NarcisseChan@kite.com");
      final json = parser.parseToJson(a);
      assert(json != null);
      assert(json!.contains("NarcisseChan@kite.com"));

      final restored = parser.restoreByExactType<Student>(json!);
      assert(restored != null);
      assert(restored!.firstName == "Narcisse");
    });

    test("Convert Course to json and back", () {
      final parser = Parser();
      parser.registerAdapter(StudentDataAdapter());
      parser.registerAdapter(LearningGroupByExactTypeDataAdapter());
      parser.registerAdapter(CourseDataAdapter());

      final c = Course("Compiler", [
        LearningGroup(
            Student("A1", "A2", "A@email.net"),
            Student("B1", "B2", "B@email.net"),
            Student("C1", "C2", "C@email.net")),
        LearningGroup(
            Student("X1", "X2", "X@email.net"),
            Student("Y1", "Y2", "Y@email.net"),
            Student("Z1", "Z2", "Z@email.net")),
      ]);
      final json = parser.parseToJson(c);
      assert(json != null);
      assert(json!.contains("@versionMap"));
      assert(json!.contains("X@email.net"));

      final restored = parser.restoreByTypeName<Course>(json!);
      assert(restored != null);
      assert(restored!.groups[1].b.lastName == "Y2");
    });
  });

  group("Test Adapter convert json to object with migration", () {
    test("Migrate from 1 to 3", () {
      final parser = Parser();
      parser.registerAdapter(FreshmanDataAdapter());
      parser.registerAdapter(CounselorDataAdapter());
      parser.registerMigration(
          Migration<Freshman>.of("kite.Freshman", to: 2, (old) {
        final names = (old["name"] as String).split(" ");
        return {
          "firstName": names.isNotEmpty ? names[0] : "",
          "lastName": names.length > 1 ? names[1] : "",
        };
      }));
      parser.registerMigration(Migration<Freshman>.of(
          "kite.Freshman",
          to: 3,
          (old) => {
                "firstName": old["firstName"],
                "lastName": old["lastName"],
                "age": null,
              }));
      parser.registerMigration(Migration<Counselor>.of(
          "kite.Counselor",
          to: 2,
          (old) => {
                "name": "",
                "students": old["students"],
              }));
      parser.registerMigration(
          Migration<Counselor>.of("kite.Counselor", to: 3, (old) {
        final names = (old["name"] as String).split(" ");
        return {
          "firstName": names.isNotEmpty ? names[0] : "",
          "lastName": names.length > 1 ? names[1] : "",
          "students": old["students"],
        };
      }));

      final rawJson = """
{
  "@type": "kite.Counselor",
  "students": [
    {
      "@type": "kite.Freshman",
      "name": "Narcisse Chan"
    },
    {
      "@type": "kite.Freshman",
      "name": "Moana Ellery"
    },
    {
      "@type": "kite.Freshman",
      "name": "Justice Apoorva"
    },
    {
      "@type": "kite.Freshman",
      "name": "Kohaku Erdem"
    }
  ],
  "@versionMap": {
    "kite.Counselor": 1,
    "kite.Freshman": 1
  }
}
    """;
      final counselor = parser.restoreByExactType<Counselor>(rawJson);
      assert(counselor != null);
      assert(counselor!.students[1].lastName == "Ellery");
      final reJson = parser.parseToJson(counselor!);
      assert(reJson!.contains('"kite.Counselor":3,"kite.Freshman":3'));
    });
  });
}

class Student {
  final String firstName;
  final String lastName;
  final String email;

  const Student(this.firstName, this.lastName, this.email);
}

class StudentDataAdapter extends DataAdapter<Student> {
  @override
  String get typeName => "kite.Student";

  @override
  Student fromJson(RestoreContext ctx, Map<String, dynamic> json) {
    return Student(
      json["firstName"] as String,
      json["lastName"] as String,
      json["email"] as String,
    );
  }

  @override
  Map<String, dynamic> toJson(ParseContext ctx, Student obj) {
    return {
      "@type": typeName,
      "firstName": obj.firstName,
      "lastName": obj.lastName,
      "email": obj.email,
    };
  }
}

class LearningGroup {
  final Student a;
  final Student b;
  final Student c;

  const LearningGroup(this.a, this.b, this.c);
}

class LearningGroupByTypeNameDataAdapter extends DataAdapter<LearningGroup> {
  @override
  String get typeName => "kite.LearningGroup";

  @override
  LearningGroup fromJson(RestoreContext ctx, Map<String, dynamic> json) {
    return LearningGroup(
      ctx.restoreByTypeName<Student>(json["a"])!,
      ctx.restoreByTypeName<Student>(json["b"])!,
      ctx.restoreByTypeName<Student>(json["c"])!,
    );
  }

  @override
  Map<String, dynamic> toJson(ParseContext ctx, LearningGroup obj) {
    return {
      "@type": typeName,
      "a": ctx.parseToJson(obj.a),
      "b": ctx.parseToJson(obj.b),
      "c": ctx.parseToJson(obj.c),
    };
  }
}

class LearningGroupByExactTypeDataAdapter extends DataAdapter<LearningGroup> {
  @override
  String get typeName => "kite.LearningGroup";

  @override
  LearningGroup fromJson(RestoreContext ctx, Map<String, dynamic> json) {
    return LearningGroup(
      ctx.restoreByExactType<Student>(json["a"])!,
      ctx.restoreByExactType<Student>(json["b"])!,
      ctx.restoreByExactType<Student>(json["c"])!,
    );
  }

  @override
  Map<String, dynamic> toJson(ParseContext ctx, LearningGroup obj) {
    return {
      "@type": typeName,
      "a": ctx.parseToJson(obj.a),
      "b": ctx.parseToJson(obj.b),
      "c": ctx.parseToJson(obj.c),
    };
  }
}

class Course {
  final String name;
  final List<LearningGroup> groups;

  const Course(this.name, this.groups);
}

class CourseDataAdapter extends DataAdapter<Course> {
  @override
  String get typeName => "kite.Course";

  @override
  Course fromJson(RestoreContext ctx, Map<String, dynamic> json) {
    return Course(
      json["name"] as String,
      ctx.restoreNonnullListByExactType<LearningGroup>(json["groups"]),
    );
  }

  @override
  Map<String, dynamic> toJson(ParseContext ctx, Course obj) {
    return {
      "@type": typeName,
      "name": obj.name,
      "groups": ctx.parseToNonnullList(obj.groups),
    };
  }
}

/// Version 2:
/// - Removed "name" field.
/// - Added "firstName" and "lastName" instead.
///
/// Version 3:
/// - Added optional "age" field.
class Freshman {
  final String firstName;
  final String lastName;
  final int? age;

  const Freshman(this.firstName, this.lastName, this.age);
}

class FreshmanDataAdapter extends DataAdapter<Freshman> {
  @override
  String get typeName => "kite.Freshman";

  @override
  int get version => 3;

  @override
  Freshman fromJson(RestoreContext ctx, Map<String, dynamic> json) {
    return Freshman(
      json["firstName"] as String,
      json["lastName"] as String,
      json["age"] as int?,
    );
  }

  @override
  Map<String, dynamic> toJson(ParseContext ctx, Freshman obj) {
    return {
      "@type": typeName,
      "firstName": obj.firstName,
      "lastName": obj.lastName,
      "age": obj.age,
    };
  }
}

/// Version 2:
/// - Added name.
///
/// Version 3:
/// - Removed name.
/// - Added "firstName" and "lastName" instead.
class Counselor {
  final String firstName;
  final String lastName;
  final List<Freshman> students;

  const Counselor(this.students, this.firstName, this.lastName);
}

class CounselorDataAdapter extends DataAdapter<Counselor> {
  @override
  String get typeName => "kite.Counselor";

  @override
  int get version => 3;

  @override
  Counselor fromJson(RestoreContext ctx, Map<String, dynamic> json) {
    return Counselor(
      ctx.restoreNonnullListByExactType(json["students"]),
      json["firstName"] as String,
      json["lastName"] as String,
    );
  }

  @override
  Map<String, dynamic> toJson(ParseContext ctx, Counselor obj) {
    return {
      "@type": typeName,
      "students": ctx.parseToNonnullList(obj.students),
      "firstName": obj.firstName,
      "lastName": obj.lastName,
    };
  }
}
