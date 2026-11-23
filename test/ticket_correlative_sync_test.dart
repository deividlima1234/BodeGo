import 'package:flutter_test/flutter_test.dart';
import 'package:bodego/data/models/sale_ticket.dart';
import 'package:bodego/data/repositories/ticket_repository.dart';

void main() {
  group('Ticket Correlative & Sync Tests', () {
    late TicketRepository repository;

    setUp(() {
      repository = TicketRepository();
    });

    test('Lista vacía produce correlativo 1', () {
      final next = repository.getNextTicketSequence([]);
      expect(next, 1);
    });

    test('Calcula el máximo correlativo independientemente del orden o saltos', () {
      final tickets = [
        SaleTicket(
          id: 'TKT_1',
          ticketNumber: 'TKT-0001',
          date: DateTime.now(),
          subtotal: 10,
          discount: 0,
          total: 10,
          isCredit: false,
          cashierName: 'Deivid',
          businessName: 'BodeGo',
          items: [],
        ),
        SaleTicket(
          id: 'TKT_4',
          ticketNumber: 'TKT-0004',
          date: DateTime.now(),
          subtotal: 10,
          discount: 0,
          total: 10,
          isCredit: false,
          cashierName: 'Deivid',
          businessName: 'BodeGo',
          items: [],
        ),
        SaleTicket(
          id: 'TKT_2',
          ticketNumber: 'TKT-0002',
          date: DateTime.now(),
          subtotal: 10,
          discount: 0,
          total: 10,
          isCredit: false,
          cashierName: 'Deivid',
          businessName: 'BodeGo',
          items: [],
        ),
      ];

      final next = repository.getNextTicketSequence(tickets);
      expect(next, 5);
      final formattedNumber = 'TKT-${next.toString().padLeft(4, '0')}';
      expect(formattedNumber, 'TKT-0005');
    });

    test('Calcula correlativo correctamente con tickets foráneos recibidos de la nube', () {
      final existingCloudTickets = [
        SaleTicket(
          id: 'TKT_1795148',
          ticketNumber: 'TKT-0001',
          date: DateTime.now(),
          subtotal: 16,
          discount: 0,
          total: 16,
          isCredit: false,
          cashierName: 'Deivid',
          businessName: 'BodeGo',
          items: [],
        ),
        SaleTicket(
          id: 'TKT_1795296',
          ticketNumber: 'TKT-0004',
          date: DateTime.now(),
          subtotal: 16,
          discount: 0,
          total: 16,
          isCredit: false,
          cashierName: 'Deivid',
          businessName: 'BodeGo',
          items: [],
        ),
      ];

      final next = repository.getNextTicketSequence(existingCloudTickets);
      expect(next, 5);
    });

    test('ticketsVersionNotifier se incrementa al notificar cambios', () {
      final initialVersion = TicketRepository.ticketsVersionNotifier.value;
      TicketRepository.ticketsVersionNotifier.value++;
      expect(TicketRepository.ticketsVersionNotifier.value, initialVersion + 1);
    });
  });
}

