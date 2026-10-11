class Customer {
  const Customer({required this.name, this.contact = '', this.uid});
  final String name;
  final String contact;
  final String? uid;
  bool get isGuest => uid == null;
}
