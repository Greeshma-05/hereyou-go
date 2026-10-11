import '../../core/constants/app_brand.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/navigation.dart';
import '../../providers/journey_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/journey_card.dart';
import '../journey/journey_screen.dart';
import '../journey/travel_history_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  void _help(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A little help along the way',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 20),
            ExpansionTile(
              title: Text('How does ${AppBrand.name} work?'),
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Set your journey, find essentials published by nearby shops, and confirm your delivery pin. Signed-in checkout sends cash-on-delivery orders to the shop. Assigned partners share location while online. Guest checkout remains a preview.',
                  ),
                ),
              ],
            ),
            ExpansionTile(
              title: Text('Why do I need a pickup point?'),
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Type your delivery place or address in Your journey, then mark its map pin. You can also choose a suggested bus or train stop. For station handovers, meet outside the station; platform and onboard delivery are not offered.',
                  ),
                ),
              ],
            ),
            ExpansionTile(
              title: Text('What if location is unavailable?'),
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Choose your delivery address and map pin to find nearby shops. Without a pin or device location, Explore uses the labelled Kochi preview area. You can grant location permission later from your device settings.',
                  ),
                ),
              ],
            ),
            ExpansionTile(
              title: Text('What gets saved?'),
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Signed-in profiles, orders, saved journeys, checklists and notification preferences sync to your account. Reading and appearance choices stay on this device. Guest orders and journeys last for this session.',
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Notice(
              'Support is informational in this prototype. There is no connected support team or emergency service.',
            ),
          ],
        ),
      ),
    ),
  );
  Future<void> _logout(BuildContext context) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Leave this session?'),
        content: Text(
          'Your cart will be cleared from this session. Signed-in order and travel history will remain in your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Log out'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    final session = context.read<SessionProvider>();
    try {
      await session.logout();
    } catch (_) {
      if (context.mounted) {
        showMessage(context, 'Could not sign out. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = context.watch<SessionProvider>().customer!;
    final journey = context.watch<JourneyProvider>().journey;
    final preferences = context.watch<PreferencesProvider>();
    return Scaffold(
      appBar: AppBar(title: Text('Your travel profile')),
      body: SafeArea(
        child: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 29,
                        backgroundColor: AppTheme.colors(context).tint,
                        child: Text(
                          customer.name.isEmpty
                              ? 'T'
                              : customer.name.characters.first.toUpperCase(),
                          style: TextStyle(
                            color: AppTheme.colors(context).accent,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              customer.contact.isEmpty
                                  ? 'Traveler'
                                  : customer.contact,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            SizedBox(height: 8),
                            StatusBadge(text: 'TRAVELER PROFILE'),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit profile',
                        onPressed: () => openPage(context, EditProfileScreen()),
                        icon: Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                ),
              ),
              SectionHeading('Your saved journey'),
              if (journey != null)
                JourneyCard(journey: journey)
              else
                Card(
                  child: ListTile(
                    leading: Icon(Icons.route_outlined),
                    title: Text('Plan your next stop'),
                    subtitle: Text('Add a bus or train journey'),
                    trailing: Icon(Icons.chevron_right),
                    onTap: () => openPage(context, JourneyScreen()),
                  ),
                ),
              SizedBox(height: 14),
              Card(
                child: ListTile(
                  leading: Icon(Icons.history_rounded),
                  title: Text('Travel history'),
                  subtitle: Text('Your upcoming and past saved journeys'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () => openPage(context, TravelHistoryScreen()),
                ),
              ),
              SectionHeading('Before you go'),
              Text(
                preferences.cloudBacked
                    ? 'Your essentials checklist · synced to your account'
                    : 'Your essentials checklist · saved on this device',
                style: TextStyle(
                  color: AppTheme.colors(context).muted,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    for (final item in [
                      'Drinking water',
                      'Snacks',
                      'Personal hygiene',
                      'Baby essentials',
                      'Tickets & ID',
                    ])
                      CheckboxListTile(
                        title: Text(item),
                        value: preferences.checked(item),
                        onChanged: (_) => preferences.toggle(item),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      ),
                  ],
                ),
              ),
              SectionHeading('Make it yours'),
              Card(
                child: SwitchListTile(
                  title: Text('Journey notifications'),
                  subtitle: Text(
                    preferences.cloudBacked
                        ? 'Preference synced to your account. Push notifications are not connected yet.'
                        : 'Preference saved on this device. Push notifications are not connected yet.',
                  ),
                  value: preferences.notifications,
                  onChanged: preferences.setNotifications,
                ),
              ),
              if (!preferences.storageAvailable || preferences.error != null)
                Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Notice(
                    preferences.error ??
                        'Local preferences could not load. Changes will last for this session.',
                    warning: true,
                  ),
                ),
              SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.help_outline),
                      title: Text('Help & support'),
                      trailing: Icon(Icons.chevron_right),
                      onTap: () => _help(context),
                    ),
                    Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('About ${AppBrand.name}'),
                      trailing: Icon(Icons.chevron_right),
                      onTap: () => showAboutDialog(
                        context: context,
                        applicationName: AppBrand.name,
                        applicationVersion: '0.1.0 · Customer prototype',
                        applicationIcon: AppLogo(),
                        children: [
                          Text('Your journey. Your essentials.'),
                          SizedBox(height: 12),
                          Text(
                            'Built for travelers, starting in Kochi. Published shops and inventory update live. Signed-in orders support cash on delivery, shop processing and assigned-partner location updates. Delivery maps can calculate an estimated road route. Map tiles are from OpenStreetMap; device location is available when you grant permission.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _logout(context),
                  icon: Icon(Icons.logout),
                  label: Text('Log out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _contact;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    final customer = context.read<SessionProvider>().customer!;
    _name = TextEditingController(text: customer.name);
    _contact = TextEditingController(text: customer.contact);
  }

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Edit profile')),
    body: SafeArea(
      child: PageBody(
        child: Form(
          key: _form,
          child: Column(
            children: [
              Notice(
                context.watch<SessionProvider>().customer!.isGuest
                    ? 'Your guest profile lasts for this session.'
                    : 'Your profile is saved to your account. Your sign-in email stays the same.',
              ),
              SizedBox(height: 24),
              TextFormField(
                controller: _name,
                decoration: InputDecoration(labelText: 'Name'),
                validator: requiredField,
                maxLength: 60,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _contact,
                readOnly: !context.read<SessionProvider>().customer!.isGuest,
                decoration: InputDecoration(
                  labelText: 'Contact / sign-in email',
                ),
                maxLength: 120,
                validator: (value) => value == null || value.trim().isEmpty
                    ? null
                    : contactError(value),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          if (!_form.currentState!.validate()) return;
                          setState(() => _saving = true);
                          try {
                            await context.read<SessionProvider>().updateProfile(
                              _name.text,
                              _contact.text,
                            );
                            if (context.mounted) Navigator.pop(context);
                          } catch (_) {
                            if (context.mounted) {
                              showMessage(
                                context,
                                'Could not save your profile. Check your connection and try again.',
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _saving = false);
                          }
                        },
                  child: Text(_saving ? 'Saving…' : 'Save profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
