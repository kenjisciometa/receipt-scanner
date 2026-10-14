/// Email address validation shared across screens that accept an address.
///
/// Accepts the characters RFC 5322 allows in an unquoted local part
/// (including `+` for sub-addressing, e.g. `hello+yui@example.com`) and
/// places no upper bound on the TLD length.
final _emailRegExp = RegExp(
  r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+$",
);

bool isValidEmail(String email) => _emailRegExp.hasMatch(email.trim());
