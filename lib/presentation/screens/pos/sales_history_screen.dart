import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bodego/data/models/sale_ticket.dart';
import 'package:bodego/data/repositories/ticket_repository.dart';
import 'package:bodego/core/services/google_sheets_sync_service.dart';
import 'package:bodego/presentation/screens/pos/widgets/ticket_preview_modal.dart';

/// Pantalla del Historial de Ventas y Comprobantes Emitidos (Tickets).
class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final TicketRepository _ticketRepository = TicketRepository();
  final TextEditingController _searchController = TextEditingController();

  List<SaleTicket> _allTickets = [];
  List<SaleTicket> _filteredTickets = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'cash', 'credit'
  String _searchQuery = '';

  Map<String, dynamic> _todaySummary = {
    'count': 0,
    'total': 0.0,
    'cashTotal': 0.0,
    'creditTotal': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _loadTickets();
    TicketRepository.ticketsVersionNotifier.addListener(_onTicketsChanged);
    // Sincronización en segundo plano silenciosa al entrar
    unawaited(GoogleSheetsSyncService().pullUpdates());
  }

  @override
  void dispose() {
    TicketRepository.ticketsVersionNotifier.removeListener(_onTicketsChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onTicketsChanged() {
    if (mounted) {
      _loadTicketsSilently();
    }
  }

  Future<void> _loadTicketsSilently() async {
    final tickets = await _ticketRepository.getTickets();
    final summary = await _ticketRepository.getTodaySummary();

    if (mounted) {
      setState(() {
        _allTickets = tickets;
        _todaySummary = summary;
        _applyFilters();
      });
    }
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    final tickets = await _ticketRepository.getTickets();
    final summary = await _ticketRepository.getTodaySummary();

    if (mounted) {
      setState(() {
        _allTickets = tickets;
        _todaySummary = summary;
        _isLoading = false;
        _applyFilters();
      });
    }
  }

  Future<void> _handleManualRefresh() async {
    setState(() => _isLoading = true);
    try {
      await GoogleSheetsSyncService().pullUpdates();
    } catch (_) {}
    await _loadTickets();
  }

  void _applyFilters() {
    List<SaleTicket> list = _allTickets;

    // Filtro por tipo de venta
    if (_selectedFilter == 'cash') {
      list = list.where((t) => !t.isCredit).toList();
    } else if (_selectedFilter == 'credit') {
      list = list.where((t) => t.isCredit).toList();
    }

    // Filtro por búsqueda de texto
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((t) {
        final matchesNumber = t.ticketNumber.toLowerCase().contains(q);
        final matchesCustomer = t.customerName?.toLowerCase().contains(q) ?? false;
        final matchesProduct = t.items.any((item) => item.name.toLowerCase().contains(q));
        return matchesNumber || matchesCustomer || matchesProduct;
      }).toList();
    }

    _filteredTickets = list;
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim();
      _applyFilters();
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
      _applyFilters();
    });
  }

  String _formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$day/$month  $hour:$min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Tickets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
            onPressed: _handleManualRefresh,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Tarjeta resumen del día (Métricas Financieras)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ventas Totales Hoy:',
                              style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'S/ ${(_todaySummary['total'] as double).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_todaySummary['count']} tickets emitidos',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Contado: S/ ${(_todaySummary['cashTotal'] as double).toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Fiados: S/ ${(_todaySummary['creditTotal'] as double).toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 2. Buscador y Filtros Rápidos (Chips)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Buscar por N° ticket, cliente o producto...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Filtros tipo chip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Todos'),
                    selected: _selectedFilter == 'all',
                    onSelected: (_) => _onFilterChanged('all'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Al Contado'),
                    selected: _selectedFilter == 'cash',
                    onSelected: (_) => _onFilterChanged('cash'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Fiados'),
                    selected: _selectedFilter == 'credit',
                    onSelected: (_) => _onFilterChanged('credit'),
                  ),
                ],
              ),
            ),

            // 3. Lista de Comprobantes (Tickets)
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredTickets.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 54, color: Colors.grey.withOpacity(0.4)),
                              const SizedBox(height: 10),
                              const Text(
                                'No se encontraron tickets',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Los tickets emitidos en Caja aparecerán registrados aquí.',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                          itemCount: _filteredTickets.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final ticket = _filteredTickets[index];
                            return _buildTicketCard(context, ticket);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tarjeta individual para cada ticket en la lista cronológica
  Widget _buildTicketCard(BuildContext context, SaleTicket ticket) {
    final theme = Theme.of(context);
    final bool isCredit = ticket.isCredit;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => TicketPreviewModal.show(context, ticket),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Ícono de comprobante
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isCredit
                      ? Colors.orange.withOpacity(0.15)
                      : Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCredit ? Icons.handshake_rounded : Icons.receipt_rounded,
                  color: isCredit ? Colors.orange[800] : Colors.green[800],
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              // Información del ticket
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ticket.ticketNumber,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _formatDate(ticket.date),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: isCredit
                                ? Colors.orange.withOpacity(0.12)
                                : Colors.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isCredit
                                ? 'Fiado: ${ticket.customerName?.split(' ').first ?? 'Cliente'}'
                                : 'Contado',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isCredit ? Colors.orange[900] : Colors.green[900],
                            ),
                          ),
                        ),
                        if (ticket.discount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '-S/ ${ticket.discount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Text(
                          '${ticket.items.length} ${ticket.items.length == 1 ? 'producto' : 'productos'}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Total en grande y flecha para abrir
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'S/ ${ticket.total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isCredit ? Colors.orange[900] : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

