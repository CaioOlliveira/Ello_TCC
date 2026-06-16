class Validators {
  const Validators._();

  static String? requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obrigatorio.';
    }
    return null;
  }

  static String? email(String? value) {
    final required = requiredText(value);
    if (required != null) return required;

    final email = value!.trim();
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!emailRegex.hasMatch(email)) {
      return 'Informe um e-mail valido.';
    }

    return null;
  }

  static String? password(String? value) {
    final required = requiredText(value);
    if (required != null) return required;

    if (value!.length < 6) {
      return 'A senha deve ter pelo menos 6 caracteres.';
    }

    return null;
  }
}
