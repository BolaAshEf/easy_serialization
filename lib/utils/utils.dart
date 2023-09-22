import '../src/easy_serialization_base.dart';

typedef AnyObj = dynamic;

/// Currently refer to json object.
typedef MarkupObj = Map<String, AnyObj>;

typedef TypeProviderCallback<RET> = RET Function<OBJ>();
typedef TypeProviderType<RET> = RET Function(TypeProviderCallback<RET>);

mixin class TypeProvider<OBJ> {
  const TypeProvider();

  RET provType<RET>(TypeProviderCallback<RET> callback) => callback<OBJ>();

  bool equalInType(TypeProvider other) =>
      provType(<MINE>() => other.provType(<OTHER>() => MINE == OTHER));

  TypeProvider setNullability(bool nullable) =>
      nullable ? TypeProvider<OBJ?>() : this;
}

bool isSubtype<T1, T2>() => <T1>[] is List<T2>;

extension ListUtilsExt on List {
  List _mapWhere((bool, dynamic) Function(dynamic) callback) {
    List list = toList()..clear();
    for (final item in this) {
      final res = callback(item);
      if (res.$1) {
        list.add(res.$2);
      }
    }
    return list;
  }

  List withoutEmpties() {
    final rec = this;

    (bool, List) removeEmpties(List rec) {
      bool keepRec = false;

      final list = rec._mapWhere((subList) {
        if (subList is List) {
          final res = removeEmpties(subList);
          if (res.$1) {
            keepRec = true;
          }
          return res;
        }

        return (keepRec = true, subList);
      }).toList();

      return (keepRec, list);
    }

    return (removeEmpties(rec)).$2;
  }

  /// Cast the list (and its sub-lists) to the most-specific-registered-types.
  ///
  /// **Note we call [withoutEmpties] first.**
  List withSpecificTypes() => castDynamically(this).toList();
}

/// Basic mixin to provide [toMarkupObj] implementation.
mixin SerializableMixin {
  MarkupObj toMarkupObj();
}
