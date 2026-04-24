import 'package:business_manager/core/di/app_scope.dart';
import 'package:business_manager/shared/models/auth_session.dart';
import 'package:business_manager/shared/models/product.dart';
import 'package:business_manager/shared/models/service_type.dart';
import 'package:business_manager/shared/widgets/primary_scaffold.dart';
import 'package:flutter/material.dart';

enum _InventoryMode { products, services }

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  _InventoryMode _mode = _InventoryMode.products;
  Future<List<Product>>? _productsFuture;
  Future<List<ServiceTypeItem>>? _servicesFuture;
  bool _bootstrapped = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    _bootstrapped = true;
    _reload();
  }

  void _reload() {
    final app = AppScope.of(context);
    final token = app.session!.token;
    setState(() {
      _productsFuture = app.api.getProducts(token);
      _servicesFuture = app.api.getServices(token);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final isAdmin = app.session!.role == UserRole.admin;
    final theme = Theme.of(context);

    return PrimaryScaffold(
      title: 'Товары и услуги',
      action: IconButton(
        onPressed: () async {
          if (!isAdmin) {
            _reload();
            return;
          }
          final changed = await showDialog<bool>(
            context: context,
            builder: (_) => _CreateInventoryItemDialog(mode: _mode),
          );
          if (changed == true && mounted) {
            _reload();
          }
        },
        icon: Icon(isAdmin ? Icons.add_circle_outline : Icons.refresh_rounded),
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2DCE4)),
            ),
            padding: const EdgeInsets.all(6),
            child: SegmentedButton<_InventoryMode>(
              segments: const [
                ButtonSegment(
                  value: _InventoryMode.products,
                  label: Text('Товары'),
                  icon: Icon(Icons.inventory_2_outlined),
                ),
                ButtonSegment(
                  value: _InventoryMode.services,
                  label: Text('Услуги'),
                  icon: Icon(Icons.design_services_outlined),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (value) =>
                  setState(() => _mode = value.first),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _mode == _InventoryMode.products
                ? _buildProducts(theme)
                : _buildServices(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildProducts(ThemeData theme) {
    final future = _productsFuture;
    if (future == null) return const Center(child: CircularProgressIndicator());
    return FutureBuilder<List<Product>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Ошибка загрузки товаров: ${snapshot.error}'),
          );
        }
        final products = snapshot.data ?? const [];
        if (products.isEmpty) {
          return const Center(child: Text('Товаров пока нет'));
        }

        return ListView.separated(
          itemCount: products.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = products[index];
            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFDE7EF),
                  child: Icon(Icons.inventory_2_outlined),
                ),
                title: Text(item.title),
                subtitle: Text('${item.category} • Остаток: ${item.stock}'),
                trailing: Text(
                  '${item.price} ₽',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildServices(ThemeData theme) {
    final future = _servicesFuture;
    if (future == null) return const Center(child: CircularProgressIndicator());
    return FutureBuilder<List<ServiceTypeItem>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Ошибка загрузки услуг: ${snapshot.error}'),
          );
        }
        final services = snapshot.data ?? const [];
        if (services.isEmpty) {
          return const Center(child: Text('Услуг пока нет'));
        }

        return ListView.separated(
          itemCount: services.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = services[index];
            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFDE7EF),
                  child: Icon(Icons.design_services_outlined),
                ),
                title: Text(item.title),
                subtitle: Text(
                  '${item.category} • ${item.durationMinutes} мин',
                ),
                trailing: Text(
                  '${item.price} ₽',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CreateInventoryItemDialog extends StatefulWidget {
  const _CreateInventoryItemDialog({required this.mode});

  final _InventoryMode mode;

  @override
  State<_CreateInventoryItemDialog> createState() =>
      _CreateInventoryItemDialogState();
}

class _CreateInventoryItemDialogState
    extends State<_CreateInventoryItemDialog> {
  final _title = TextEditingController();
  final _category = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController(text: '0');
  final _duration = TextEditingController(text: '60');
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _category.dispose();
    _price.dispose();
    _stock.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final app = AppScope.of(context);
    final title = _title.text.trim();
    final category = _category.text.trim();
    final price = int.tryParse(_price.text.trim()) ?? -1;
    if (title.length < 2 || category.length < 2 || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Проверьте заполнение полей')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (widget.mode == _InventoryMode.products) {
        final stock = int.tryParse(_stock.text.trim()) ?? -1;
        if (stock < 0) {
          throw Exception('Остаток должен быть >= 0');
        }
        await app.api.createProduct(
          app.session!.token,
          title: title,
          category: category,
          stock: stock,
          price: price,
        );
      } else {
        final duration = int.tryParse(_duration.text.trim()) ?? -1;
        if (duration < 5) {
          throw Exception('Длительность должна быть не меньше 5 минут');
        }
        await app.api.createService(
          app.session!.token,
          title: title,
          category: category,
          price: price,
          durationMinutes: duration,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isProduct = widget.mode == _InventoryMode.products;
    return AlertDialog(
      title: Text(isProduct ? 'Новый товар' : 'Новая услуга'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _category,
                decoration: const InputDecoration(labelText: 'Категория'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Цена'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: isProduct ? _stock : _duration,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isProduct ? 'Остаток' : 'Длительность (мин)',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Сохранение...' : 'Сохранить'),
        ),
      ],
    );
  }
}
