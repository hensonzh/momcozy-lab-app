enum ProfileIdentity {
  mom('mom'),
  baby('baby');

  const ProfileIdentity(this.value);

  final String value;

  static ProfileIdentity fromValue(Object? value) {
    return value == 'baby' ? ProfileIdentity.baby : ProfileIdentity.mom;
  }
}
