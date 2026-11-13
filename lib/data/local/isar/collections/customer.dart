import 'package:isar/isar.dart';

part 'customer.g.dart';

@collection
class Customer {
  Id id = Isar.autoIncrement;

  late String name;

  String? phone;

  String? address;

  double creditLimit = 100.0;

  double currentDebt = 0.0;

  late DateTime createdAt;
}

