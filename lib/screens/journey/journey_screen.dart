import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/navigation.dart';
import '../../data/mock_journeys.dart';
import '../../models/journey_model.dart';
import '../../providers/journey_provider.dart';
import '../../providers/location_provider.dart';
import '../../widgets/common.dart';
import 'delivery_location_screen.dart';

class JourneyScreen extends StatefulWidget {
  const JourneyScreen({super.key, this.mode, this.focusDelivery = false});
  final JourneyMode? mode;
  final bool focusDelivery;
  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  final _form = GlobalKey<FormState>();
  final _operator = TextEditingController();
  final _boarding = TextEditingController();
  final _destination = TextEditingController();
  final _deliveryPlace = TextEditingController();
  final _instructions = TextEditingController();
  late JourneyMode _mode;
  late DateTime _departure;
  PickupStop? _pickup;
  bool _pinConfirmed = false;
  String? _pinError;
  List<PickupStop> get _stops =>
      _mode == JourneyMode.bus ? busStops : trainStops;
  @override
  void initState() {
    super.initState();
    final saved = context.read<JourneyProvider>().journey;
    _mode = widget.mode ?? saved?.mode ?? JourneyMode.bus;
    _departure = DateTime.now().add(const Duration(hours: 2));
    if (saved != null && saved.mode == _mode) {
      _operator.text = saved.operatorName;
      _boarding.text = saved.boarding;
      _destination.text = saved.destination;
      _departure = saved.departure;
      _pickup = saved.pickup;
      _deliveryPlace.text = saved.pickup.name;
      _instructions.text = saved.pickup.instructions;
      _pinConfirmed = true;
    }
  }

  @override
  void dispose() {
    _operator.dispose();
    _boarding.dispose();
    _destination.dispose();
    _deliveryPlace.dispose();
    _instructions.dispose();
    super.dispose();
  }

  void _sample() => setState(() {
    _operator.text = _mode == JourneyMode.bus
        ? 'KSRTC · Bus 101'
        : 'Express · 16301';
    _boarding.text = 'Ernakulam';
    _destination.text = 'Thrissur';
    _departure = DateTime.now().add(const Duration(hours: 2));
    _selectStop(_stops.first);
  });

  void _selectStop(PickupStop stop) {
    _pickup = stop;
    _deliveryPlace.text = stop.name;
    _instructions.text = stop.instructions;
    _pinConfirmed = true;
    _pinError = null;
  }

  Future<void> _choosePin() async {
    FocusScope.of(context).unfocus();
    final place = _deliveryPlace.text.trim();
    if (place.isEmpty) {
      showMessage(context, 'Type your delivery place first.');
      return;
    }
    final position = await openPage<LatLng>(
      context,
      DeliveryLocationScreen(
        initialPosition: _pinConfirmed ? _pickup?.position : null,
        initialCenter: _pickup?.position,
        place: place,
      ),
    );
    if (!mounted || position == null) return;
    setState(() {
      _pickup = PickupStop.custom(
        mode: _mode,
        name: place,
        position: position,
        instructions: 'Meet at the marked delivery place.',
      );
      _pinConfirmed = true;
      _pinError = null;
    });
  }

  Future<void> _date() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = await showDatePicker(
      context: context,
      initialDate: _departure.isBefore(today) ? today : _departure,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (date != null && mounted) {
      setState(
        () => _departure = DateTime(
          date.year,
          date.month,
          date.day,
          _departure.hour,
          _departure.minute,
        ),
      );
    }
  }

  Future<void> _time() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_departure),
    );
    if (time != null && mounted) {
      setState(
        () => _departure = DateTime(
          _departure.year,
          _departure.month,
          _departure.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  bool _saving = false;
  Future<void> _save() async {
    if (_saving) return;
    final validPin = _pickup != null && _pinConfirmed;
    setState(
      () => _pinError = validPin
          ? null
          : 'Pin your delivery place on the map, or choose a nearby stop.',
    );
    if (!_form.currentState!.validate() || !validPin) return;
    if (_departure.isBefore(DateTime.now())) {
      showMessage(context, 'Choose a future departure date and time.');
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<JourneyProvider>().save(
        Journey(
          mode: _mode,
          operatorName: _operator.text.trim(),
          boarding: _boarding.text.trim(),
          destination: _destination.text.trim(),
          departure: _departure,
          pickup: PickupStop(
            _pickup!.id,
            _deliveryPlace.text.trim(),
            _pickup!.position,
            _instructions.text.trim().isEmpty
                ? 'Meet at the marked delivery place.'
                : _instructions.text.trim(),
          ),
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Could not save this journey. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your journey')),
    body: SafeArea(
      child: PageBody(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Where are you headed?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              const Text(
                'Type where you want your essentials and mark the exact place on the map.',
              ),
              const SizedBox(height: 22),
              SegmentedButton<JourneyMode>(
                segments: const [
                  ButtonSegment(
                    value: JourneyMode.bus,
                    icon: Icon(Icons.directions_bus_outlined),
                    label: Text('Bus'),
                  ),
                  ButtonSegment(
                    value: JourneyMode.train,
                    icon: Icon(Icons.train_outlined),
                    label: Text('Train'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (modes) => setState(() {
                  _mode = modes.first;
                  if (_pickup?.isCustom == true) {
                    _pickup = PickupStop.custom(
                      mode: _mode,
                      name: _pickup!.name,
                      position: _pickup!.position,
                      instructions: _pickup!.instructions,
                    );
                  } else {
                    _pickup = null;
                    _deliveryPlace.clear();
                    _instructions.clear();
                    _pinConfirmed = false;
                  }
                  _pinError = null;
                  _operator.clear();
                }),
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const ValueKey('delivery-place-field'),
                controller: _deliveryPlace,
                autofocus: widget.focusDelivery,
                validator: requiredField,
                maxLength: 160,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.words,
                keyboardType: TextInputType.streetAddress,
                onChanged: (_) => setState(() {
                  _pinConfirmed = false;
                  _pinError = null;
                }),
                decoration: const InputDecoration(
                  labelText: 'Delivery place / address',
                  hintText: 'Building, street, area and city',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('delivery-instructions-field'),
                controller: _instructions,
                maxLength: 1000,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Landmark or instructions (optional)',
                  hintText: 'e.g. Meet beside the main gate',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _choosePin,
                icon: Icon(
                  _pinConfirmed
                      ? Icons.edit_location_alt_outlined
                      : Icons.add_location_alt_outlined,
                ),
                label: Text(
                  _pinConfirmed ? 'Change map pin' : 'Pin delivery location',
                ),
              ),
              if (_pinConfirmed)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Notice(
                    'Map pin confirmed for this delivery place.',
                    icon: Icons.check_circle_outline,
                  ),
                ),
              if (_pinError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Notice(_pinError!, warning: true),
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey('${_mode.name}-${_pickup?.id}-$_pinConfirmed'),
                initialValue:
                    _pinConfirmed &&
                        _stops.any((stop) => stop.id == _pickup?.id)
                    ? _pickup!.id
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Or choose a nearby stop',
                  helperText: 'Fills the address and its map pin.',
                ),
                items: _stops
                    .map(
                      (stop) => DropdownMenuItem(
                        value: stop.id,
                        child: Text(stop.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  if (id != null) {
                    setState(
                      () => _selectStop(
                        _stops.firstWhere((stop) => stop.id == id),
                      ),
                    );
                  }
                },
              ),
              if (_mode == JourneyMode.train)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'For station handovers, choose a point outside the station. Platform and onboard delivery are not available.',
                  ),
                ),
              const SectionHeading('Journey details'),
              const Notice(
                'This is a pickup preview. Shop stock, schedules and delivery coverage are not connected to live services.',
              ),
              TextButton.icon(
                onPressed: _sample,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Fill sample journey'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _operator,
                validator: requiredField,
                maxLength: 120,
                decoration: InputDecoration(
                  labelText: _mode == JourneyMode.bus
                      ? 'Bus number or operator'
                      : 'Train number or name',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _boarding,
                validator: requiredField,
                maxLength: 120,
                decoration: InputDecoration(
                  labelText: _mode == JourneyMode.bus
                      ? 'Boarding location'
                      : 'Boarding station',
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  final location = context.read<LocationProvider>();
                  await location.locate();
                  if (!context.mounted) return;
                  if (location.position != null) {
                    _boarding.text =
                        'GPS: ${location.position!.latitude.toStringAsFixed(4)}, ${location.position!.longitude.toStringAsFixed(4)}';
                  } else {
                    showMessage(context, location.result.message);
                  }
                },
                icon: const Icon(Icons.my_location, size: 18),
                label: const Text('Use current coordinates for boarding'),
              ),
              TextFormField(
                controller: _destination,
                maxLength: 120,
                validator: (value) =>
                    requiredField(value) ??
                    (value!.trim().toLowerCase() ==
                            _boarding.text.trim().toLowerCase()
                        ? 'Destination must differ from boarding.'
                        : null),
                decoration: InputDecoration(
                  labelText: _mode == JourneyMode.bus
                      ? 'Destination'
                      : 'Destination station',
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: _date,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(dateLabel(_departure)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _time,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(timeLabel(_departure)),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.check),
                  label: Text(_saving ? 'Saving journey…' : 'Save journey'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
