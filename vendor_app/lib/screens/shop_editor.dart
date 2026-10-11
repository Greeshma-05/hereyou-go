import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:route_rescue/core/utils/navigation.dart';
import 'package:route_rescue/data/merchant_repository.dart';
import 'package:route_rescue/models/category.dart';
import 'package:route_rescue/models/vendor_model.dart';
import 'package:route_rescue/screens/journey/delivery_location_screen.dart';
import 'package:route_rescue/widgets/common.dart';
import '../state/merchant_state.dart';

class ShopEditor extends StatefulWidget {
  const ShopEditor({super.key, this.shop});
  final Vendor? shop;
  @override
  State<ShopEditor> createState() => _ShopEditorState();
}

class _ShopEditorState extends State<ShopEditor> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _owner = TextEditingController();
  final _phone = TextEditingController();
  final _license = TextEditingController();
  final _address = TextEditingController();
  final _description = TextEditingController();
  final _prep = TextEditingController(text: '15');
  Category _category = Category.food;
  LatLng? _pin;
  bool _open = true, _published = true, _busy = false, _accountLoaded = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final shop = widget.shop;
    if (shop != null) {
      _name.text = shop.name;
      _address.text = shop.area;
      _description.text = shop.description;
      _prep.text = '${shop.preparationMinutes}';
      _pin = shop.position;
      _category = shop.category;
      _open = shop.available;
      _published = shop.published;
      _loadAccount();
    } else {
      _accountLoaded = true;
    }
  }

  Future<void> _loadAccount() async {
    try {
      final state = context.read<MerchantState>();
      final account = await state.repository.account(state.uid);
      if (!mounted) return;
      if (account == null) {
        setState(
          () => _error =
              'Shop contact details could not load. Retry before saving.',
        );
        return;
      }
      _owner.text = account.ownerName;
      _phone.text = account.phone;
      _license.text = account.licenseNumber;
      setState(() {
        _accountLoaded = true;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = merchantError(e));
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _owner,
      _phone,
      _license,
      _address,
      _description,
      _prep,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _choosePin() async {
    if (_address.text.trim().isEmpty) {
      setState(() => _error = 'Enter the shop address first.');
      return;
    }
    FocusScope.of(context).unfocus();
    final pin = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => DeliveryLocationScreen(
          place: _address.text.trim(),
          initialPosition: _pin,
          title: 'Shop location',
        ),
      ),
    );
    if (mounted && pin != null) {
      setState(() {
        _pin = pin;
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    if (_busy || !_accountLoaded || !_form.currentState!.validate()) return;
    if (_pin == null) {
      setState(() => _error = 'Confirm the shop entrance on the map first.');
      return;
    }
    final state = context.read<MerchantState>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await state.repository.saveShop(
        Vendor(
          id: state.uid,
          name: _name.text.trim(),
          category: _category,
          position: _pin!,
          area: _address.text.trim(),
          preparationMinutes: int.parse(_prep.text),
          rating: 0,
          available: _open,
          description: _description.text.trim(),
          isSample: false,
          published: _published,
        ),
        MerchantAccount(
          ownerName: _owner.text.trim(),
          email: state.repository.email!,
          phone: _phone.text.trim(),
          licenseNumber: _category == Category.medicine
              ? _license.text.trim()
              : '',
        ),
        creating: widget.shop == null,
      );
      if (!mounted) return;
      if (widget.shop != null) Navigator.pop(context);
      showMessage(context, 'Shop details saved.');
    } catch (e) {
      if (mounted) setState(() => _error = merchantError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    TextEditingController c,
    String label,
    int max, {
    int lines = 1,
    TextInputType? keyboard,
    String? Function(String?)? validator,
    ValueChanged<String>? changed,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: c,
      enabled: !_busy,
      maxLength: max,
      maxLines: lines,
      keyboardType: keyboard,
      onChanged: changed,
      decoration: InputDecoration(labelText: label, counterText: ''),
      validator:
          validator ??
          (s) => s == null || s.trim().isEmpty ? 'Enter $label.' : null,
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.shop == null ? 'Register your shop' : 'Edit shop'),
      actions: [
        if (widget.shop == null)
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: _busy
                ? null
                : () => context.read<MerchantState>().repository.signOut(),
          ),
      ],
    ),
    body: SafeArea(
      child: PageBody(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Put your shop\non the map.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'Travelers discover your published shop and products by distance from their location.',
              ),
              const SectionHeading('Public shop details'),
              _field(_name, 'Shop name', 160),
              DropdownButtonFormField<Category>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Shop type'),
                items: [
                  for (final c in Category.values)
                    DropdownMenuItem(
                      value: c,
                      child: Text(
                        c == Category.medicine ? 'Medical shop' : c.label,
                      ),
                    ),
                ],
                onChanged: _busy || widget.shop != null
                    ? null
                    : (c) => setState(() => _category = c!),
              ),
              if (widget.shop != null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Shop type stays the same for your existing catalog.',
                  ),
                ),
              const SizedBox(height: 16),
              _field(
                _address,
                'Shop address',
                300,
                lines: 2,
                changed: (_) => setState(() => _pin = null),
              ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _choosePin,
                  icon: const Icon(Icons.location_on_outlined),
                  label: Text(
                    _pin == null ? 'Pin shop location' : 'Change shop pin',
                  ),
                ),
              ),
              if (_pin != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Confirmed: ${_pin!.latitude.toStringAsFixed(6)}, ${_pin!.longitude.toStringAsFixed(6)}',
                  ),
                ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Customer distances use this map pin. Confirm it marks your shop’s actual entrance.',
                ),
              ),
              const SizedBox(height: 16),
              _field(_description, 'About your shop', 1000, lines: 3),
              _field(
                _prep,
                'Preparation time (minutes)',
                3,
                keyboard: TextInputType.number,
                validator: (s) => switch (int.tryParse(s ?? '')) {
                  final int n when n >= 0 && n <= 240 => null,
                  _ => 'Enter 0–240 minutes.',
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Shop is open'),
                subtitle: const Text(
                  'Closed shops stay visible, with ordering disabled.',
                ),
                value: _open,
                onChanged: _busy ? null : (v) => setState(() => _open = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Publish shop'),
                subtitle: const Text(
                  'Show your shop name, address, map pin and published products to customers.',
                ),
                value: _published,
                onChanged: _busy ? null : (v) => setState(() => _published = v),
              ),
              const SectionHeading('Private business details'),
              const Notice(
                'Your contact details and license number are only visible to your account. Entering a license number does not mark the shop as verified.',
              ),
              const SizedBox(height: 16),
              _field(_owner, 'Owner name', 80),
              _field(
                _phone,
                'Business phone',
                24,
                keyboard: TextInputType.phone,
                validator: (s) =>
                    RegExp(r'^[+0-9 ()-]{7,24}$').hasMatch(s?.trim() ?? '')
                    ? null
                    : 'Enter a valid phone number.',
              ),
              if (_category == Category.medicine)
                _field(_license, 'Pharmacy license number', 120),
              if (_error != null) Notice(_error!, warning: true),
              if (!_accountLoaded)
                TextButton(
                  onPressed: _loadAccount,
                  child: const Text('Retry contact details'),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy || !_accountLoaded ? null : _save,
                  icon: const Icon(Icons.check),
                  label: Text(_busy ? 'Saving…' : 'Save shop'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
