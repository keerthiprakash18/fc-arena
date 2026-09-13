/// Coerce a JSON value to `double` safely.
///
/// DRF serializes `DecimalField` as a **quoted string** (e.g. `"0.00"`) to preserve
/// precision, so a naive `(json['fee'] ?? 0).toDouble()` crashes with
/// `NoSuchMethodError: method 'toDouble' was called on null` / on a String.
///
/// Accepts any of `null`, `num` (`int` / `double`), or a numeric `String`.
/// Returns [fallback] for `null` and for strings that don't parse as a number.
double safeDouble(dynamic value, {double fallback = 0.0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}