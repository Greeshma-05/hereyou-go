class FirebaseAccount {
  const FirebaseAccount({
    required this.uid,
    required this.email,
    this.name,
    this.setupMessage,
  });

  final String uid;
  final String email;
  final String? name;
  final String? setupMessage;
}

class AccountProfile {
  const AccountProfile({required this.displayName, required this.email});

  final String displayName;
  final String email;
}
