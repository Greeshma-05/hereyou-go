import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:route_rescue/core/utils/navigation.dart';
import 'package:route_rescue/models/category.dart';
import 'package:route_rescue/models/product_model.dart';
import 'package:route_rescue/models/vendor_model.dart';
import 'package:route_rescue/widgets/common.dart';
import '../state/merchant_state.dart';
import '../state/product_validation.dart';

class ProductEditor extends StatefulWidget {
  const ProductEditor({super.key, required this.shop, this.product});
  final Vendor shop;
  final Product? product;
  @override
  State<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<ProductEditor> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  bool _published = true, _prescription = false, _busy = false;
  String? _error;
  bool get _medicine => widget.shop.category == Category.medicine;
  String _value(String key) => _fields[key]!.text.trim();
  @override
  void initState() {
    super.initState();
    final p = widget.product;
    final values = {
      'name': p?.name ?? '',
      'price': p == null ? '' : (p.pricePaise / 100).toStringAsFixed(2),
      'stock': '${p?.stock ?? 0}',
      'unit': p?.unit ?? '',
      'description': p?.description ?? '',
      'strength': p?.strength ?? '',
      'form': p?.dosageForm ?? '',
      'generic': p?.genericName ?? '',
      'brand': p?.brand ?? '',
      'manufacturer': p?.manufacturer ?? '',
      'expiry': p?.expiryDate ?? '',
    };
    for (final e in values.entries) {
      _fields[e.key] = TextEditingController(text: e.value);
    }
    _published = p?.published ?? true;
    _prescription = p?.prescriptionRequired ?? _medicine;
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final state = context.read<MerchantState>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await state.repository.saveProduct(
        state.uid,
        Product(
          id: widget.product?.id ?? '',
          vendorId: state.uid,
          name: _value('name'),
          category: widget.shop.category,
          pricePaise: priceInPaise(_value('price'))!,
          stock: int.parse(_value('stock')),
          unit: _value('unit'),
          description: _value('description'),
          strength: _medicine ? _value('strength') : null,
          dosageForm: _medicine ? _value('form') : null,
          genericName: _medicine ? _value('generic') : '',
          brand: _value('brand'),
          manufacturer: _value('manufacturer'),
          expiryDate: _value('expiry'),
          prescriptionRequired: _medicine && _prescription,
          published: _published,
        ),
        creating: widget.product == null,
      );
      if (!mounted) return;
      Navigator.pop(context);
      showMessage(
        context,
        'Product saved. Published items update in nearby customer searches.',
      );
    } catch (e) {
      if (mounted) setState(() => _error = merchantError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    String key,
    String label,
    int max, {
    bool required = true,
    int lines = 1,
    String? hint,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: _fields[key],
      enabled: !_busy,
      maxLength: max,
      maxLines: lines,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
      ),
      validator:
          validator ??
          (s) =>
              required && (s?.trim().isEmpty ?? true) ? 'Enter $label.' : null,
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.product == null ? 'Add product' : 'Edit product'),
    ),
    body: SafeArea(
      child: PageBody(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusBadge(text: widget.shop.category.label.toUpperCase()),
              const SizedBox(height: 18),
              Text(
                _medicine ? 'Medicine details' : 'Product details',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
              _field('name', _medicine ? 'Medicine name' : 'Product name', 160),
              _field('brand', 'Brand (optional)', 120, required: false),
              if (_medicine) ...[
                _field(
                  'generic',
                  'Generic name / composition (optional)',
                  160,
                  required: false,
                ),
                _field(
                  'strength',
                  'Strength / concentration',
                  80,
                  hint: 'Copy the strength printed on the pack',
                ),
                _field(
                  'form',
                  'Dosage form',
                  40,
                  hint: 'Tablet, capsule, syrup, drops…',
                ),
                const Notice(
                  'Enter the product label details. Do not add personalized dose recommendations.',
                ),
                const SizedBox(height: 16),
              ],
              _field(
                'unit',
                'Pack size / unit',
                80,
                hint: 'For example: strip of 10, 100 ml, 1 meal',
              ),
              _field(
                'manufacturer',
                _medicine ? 'Manufacturer' : 'Manufacturer (optional)',
                160,
                required: _medicine,
              ),
              _field(
                'expiry',
                _medicine
                    ? 'Expiry date (YYYY-MM-DD)'
                    : 'Expiry date (optional)',
                10,
                required: _medicine,
                keyboard: TextInputType.datetime,
                validator: (s) =>
                    expiryError(s, required: _medicine, allowPast: !_published),
              ),
              if (_medicine)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Prescription required'),
                  subtitle: const Text(
                    'Use the requirement printed on the product and applicable to its sale.',
                  ),
                  value: _prescription,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _prescription = v),
                ),
              const SectionHeading('Price & availability'),
              _field(
                'price',
                'Price (₹)',
                10,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                validator: (s) => priceInPaise(s ?? '') == null
                    ? 'Enter ₹0.01–₹100,000 with up to 2 decimal places.'
                    : null,
              ),
              _field(
                'stock',
                'Available stock',
                6,
                keyboard: TextInputType.number,
                validator: (s) => switch (int.tryParse(s ?? '')) {
                  final int n when n >= 0 && n <= 100000 => null,
                  _ => 'Enter a whole number from 0 to 100,000.',
                },
              ),
              _field('description', 'Description', 2000, lines: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Publish product'),
                subtitle: const Text(
                  'Turn off to hide or archive this product. Zero stock appears as sold out. Expired items stay out of customer searches.',
                ),
                value: _published,
                onChanged: _busy ? null : (v) => setState(() => _published = v),
              ),
              if (!widget.shop.published)
                const Notice(
                  'Your shop is hidden. Publish it in Edit shop before products can appear to customers.',
                ),
              if (_error != null) Notice(_error!, warning: true),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_busy ? 'Saving…' : 'Save product'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
