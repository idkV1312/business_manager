import '../models/appointment.dart';
import '../models/discount_rule.dart';
import '../models/expense.dart';
import '../models/product.dart';

class MockDataRepository {
  const MockDataRepository();

  List<Appointment> getWeekAppointments() => const [
        Appointment(
          client: 'Elina',
          service: 'Lash lift',
          start: '08:00',
          end: '08:40',
          column: 0,
          durationBlocks: 2,
          tint: 0xFFCBE9C0,
        ),
        Appointment(
          client: 'Mia',
          service: 'Brow lamination',
          start: '08:30',
          end: '09:10',
          column: 1,
          durationBlocks: 2,
          tint: 0xFFF8E67A,
        ),
        Appointment(
          client: 'Adele',
          service: '2D extension',
          start: '08:00',
          end: '09:20',
          column: 2,
          durationBlocks: 4,
          tint: 0xFFF6DD63,
        ),
        Appointment(
          client: 'Tamar',
          service: 'Brow shape',
          start: '08:00',
          end: '08:40',
          column: 3,
          durationBlocks: 2,
          tint: 0xFFCBE9C0,
        ),
        Appointment(
          client: 'Anna',
          service: '3D extension',
          start: '08:30',
          end: '09:50',
          column: 4,
          durationBlocks: 4,
          tint: 0xFFFF7272,
        ),
      ];

  List<Product> getProducts() => const [
        Product(
          title: 'Lash Serum Nova',
          category: 'Lashes',
          stock: 12,
          price: 24,
          badge: 'new',
        ),
        Product(
          title: 'Brow Gel AirFix',
          category: 'Brows',
          stock: 22,
          price: 19,
          badge: 'hit',
        ),
        Product(
          title: 'Cream Remover Soft',
          category: 'Care',
          stock: 8,
          price: 31,
          badge: 'low',
        ),
      ];

  List<Expense> getExpenses() => const [
        Expense(date: '02.11', category: 'Lash materials', amount: 2300, payment: 'Card'),
        Expense(date: '10.11', category: 'Brow pigments', amount: 1200, payment: 'Cash'),
        Expense(date: '16.11', category: 'Sterilization', amount: 950, payment: 'Cash'),
      ];

  List<DiscountRule> getDiscountRules() => const [
        DiscountRule(service: 'Manicure', price: 200, duration: 40),
        DiscountRule(service: 'Lash correction', price: 200, duration: 60),
        DiscountRule(service: 'Brow shape', price: 180, duration: 35),
      ];

  List<String> getMessageTemplates() => const [
        'Open Day: free consultation and -20% for first visit.',
        'Holiday rush: book your slot before the weekend.',
        'Winter promo: combo service with special price.',
      ];
}