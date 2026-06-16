class Validators {
  const Validators._();

  static String? requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obrigatorio.';
    }
    return null;
  }
}
