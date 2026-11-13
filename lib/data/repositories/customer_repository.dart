import 'package:isar/isar.dart';
import 'package:bodego/data/local/isar/database_service.dart';
import 'package:bodego/data/local/isar/collections/customer.dart';

/// Repositorio para la gestión de clientes, límites de crédito y cuentas por cobrar ("Fiados").
class CustomerRepository {
  final Isar _isar;

  CustomerRepository({Isar? isar}) : _isar = isar ?? DatabaseService.db;

  /// Obtiene todos los clientes registrados ordenados por nombre.
  Future<List<Customer>> getCustomers() async {
    return await _isar.customers.where().sortByName().findAll();
  }

  /// Registra un nuevo cliente con su límite de crédito asignado.
  Future<void> addCustomer(
    String name,
    String? phone,
    String? address,
    double creditLimit,
  ) async {
    final customer = Customer()
      ..name = name.trim()
      ..phone = (phone != null && phone.trim().isNotEmpty) ? phone.trim() : null
      ..address = (address != null && address.trim().isNotEmpty) ? address.trim() : null
      ..creditLimit = creditLimit
      ..currentDebt = 0.0
      ..createdAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.customers.put(customer);
    });
  }

  /// Registra una nueva deuda (fiado) a un cliente.
  Future<bool> addDebt(int customerId, double amount) async {
    final customer = await _isar.customers.get(customerId);
    if (customer == null || amount <= 0) return false;

    customer.currentDebt += amount;

    await _isar.writeTxn(() async {
      await _isar.customers.put(customer);
    });
    return true;
  }

  /// Registra un abono o pago parcial a la cuenta del cliente.
  Future<bool> payDebt(int customerId, double amount) async {
    final customer = await _isar.customers.get(customerId);
    if (customer == null || amount <= 0) return false;

    customer.currentDebt = (customer.currentDebt - amount).clamp(0.0, double.infinity);

    await _isar.writeTxn(() async {
      await _isar.customers.put(customer);
    });
    return true;
  }

  /// Elimina un cliente por su ID.
  Future<void> deleteCustomer(int id) async {
    await _isar.writeTxn(() async {
      await _isar.customers.delete(id);
    });
  }
}

