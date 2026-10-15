enum ElderGender { female, male, unspecified }

class ElderText {
  const ElderText(this.gender);

  factory ElderText.fromSexo(String? sexo) {
    final normalized = _normalize(sexo);
    if (normalized == null) return const ElderText(ElderGender.unspecified);
    if (_femaleValues.contains(normalized)) {
      return const ElderText(ElderGender.female);
    }
    if (_maleValues.contains(normalized)) {
      return const ElderText(ElderGender.male);
    }
    return const ElderText(ElderGender.unspecified);
  }

  final ElderGender gender;

  bool get isFemale => gender == ElderGender.female;
  bool get isMale => gender == ElderGender.male;

  String get singular {
    return 'paciente';
  }

  String get singularCapitalized {
    return 'Paciente';
  }

  String get withArticle {
    if (isFemale) return 'a paciente';
    return 'o paciente';
  }

  String get selectedWithArticle {
    if (isFemale) return 'a paciente selecionada';
    return 'o paciente selecionado';
  }

  String get of {
    if (isFemale) return 'da paciente';
    return 'do paciente';
  }

  String get to {
    if (isFemale) return 'à paciente';
    return 'ao paciente';
  }

  String get one {
    if (isFemale) return 'uma paciente';
    return 'um paciente';
  }

  String howFeeling() => 'Como $withArticle está se sentindo?';
}

String? normalizeSexo(String? sexo) {
  final normalized = _normalize(sexo);
  if (normalized == null) return null;
  if (_femaleValues.contains(normalized)) return 'Feminino';
  if (_maleValues.contains(normalized)) return 'Masculino';
  if (_otherValues.contains(normalized)) return 'Outro';
  return null;
}

const _femaleValues = {
  'f',
  'fem',
  'feminino',
  'mulher',
  'idosa',
  'female',
};

const _maleValues = {
  'm',
  'masc',
  'masculino',
  'homem',
  'idoso',
  'male',
};

const _otherValues = {
  'outro',
  'outra',
  'outros',
  'outras',
  'nao_binario',
  'não_binário',
  'nao binario',
  'não binário',
  'nonbinary',
  'non-binary',
};

String? _normalize(String? value) {
  final text = value?.trim().toLowerCase();
  if (text == null || text.isEmpty) return null;
  return text
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('é', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c');
}
