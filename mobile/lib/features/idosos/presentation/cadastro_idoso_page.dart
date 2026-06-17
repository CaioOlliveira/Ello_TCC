import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_exception.dart';

class CadastroIdosoPage extends ConsumerStatefulWidget {
  const CadastroIdosoPage({super.key});

  @override
  ConsumerState<CadastroIdosoPage> createState() => _CadastroIdosoPageState();
}

class _CadastroIdosoPageState extends ConsumerState<CadastroIdosoPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _dataNascimentoController = TextEditingController();
  final _idadeController = TextEditingController();
  final _limitacoesController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _contatoNomeController = TextEditingController();
  final _observacoesController = TextEditingController();
  final _picker = ImagePicker();

  final List<String> _condicoes = [];
  String? _sexo;
  Uint8List? _fotoBytes;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nomeController.dispose();
    _dataNascimentoController.dispose();
    _idadeController.dispose();
    _limitacoesController.dispose();
    _telefoneController.dispose();
    _contatoNomeController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  Future<void> _selecionarFoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 900,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _fotoBytes = bytes);
  }

  Future<void> _selecionarData() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      firstDate: DateTime(1900),
      lastDate: now,
      initialDate: DateTime(now.year - 63, now.month, now.day),
    );

    if (selected == null) return;
    _dataNascimentoController.text = _formatBrazilianDate(selected);
    _idadeController.text = _calculateAge(selected, now).toString();
  }

  Future<void> _adicionarCondicao() async {
    String condicao = '';
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Adicionar condição'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Ex: Alzheimer'),
            onChanged: (value) => condicao = value,
            textCapitalization: TextCapitalization.sentences,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(condicao),
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    setState(() => _condicoes.add(trimmed));
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.criarIdoso(
        nomeCompleto: _nomeController.text.trim(),
        dataNascimento: _toIsoDate(_dataNascimentoController.text.trim()),
        sexo: _sexo,
        condicoesSaude: _condicoes,
        alergiasRestricoes: _limitacoesController.text.trim(),
        observacoesGerais: _observacoesController.text.trim(),
        contatoEmergenciaNome: _contatoNomeController.text.trim(),
        contatoEmergenciaTelefone: _telefoneController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ficha criada com sucesso.')),
      );
      context.go('/dashboard');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Não foi possível criar a ficha. Confira sua conexão e tente novamente.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Column(
              children: [
                _CadastroHeader(onBack: () => context.go('/idosos')),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 34),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 1),
                          const Text(
                            'Registre os principais dados',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF17324D),
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Comece registrando os principais dados',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF8A8A8A),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(17),
                              border: Border.all(
                                color: const Color(0xFF8BD2DC),
                                width: 1.2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x22000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: _selecionarFoto,
                                      borderRadius: BorderRadius.circular(50),
                                      child: Container(
                                        width: 66,
                                        height: 66,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD3F0F3),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFF2799AD),
                                            style: BorderStyle.solid,
                                          ),
                                          image: _fotoBytes == null
                                              ? null
                                              : DecorationImage(
                                                  image:
                                                      MemoryImage(_fotoBytes!),
                                                  fit: BoxFit.cover,
                                                ),
                                        ),
                                        child: _fotoBytes == null
                                            ? const Icon(
                                                Icons.add_rounded,
                                                color: Color(0xFF2697AA),
                                                size: 38,
                                              )
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Foto do Idoso',
                                          style: TextStyle(
                                            color: Color(0xFF249CB0),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        SizedBox(height: 1),
                                        Text(
                                          'toque para adicionar',
                                          style: TextStyle(
                                            color: Color(0xFF9B9B9B),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                const _FieldLabel('Nome completo'),
                                _InputBox(
                                  controller: _nomeController,
                                  hintText: 'Ex: Mônica aparecida da silva',
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Informe o nome completo.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const _FieldLabel(
                                            'Data de nascimento',
                                          ),
                                          _InputBox(
                                            controller:
                                                _dataNascimentoController,
                                            hintText: 'dd/mm/aaaa',
                                            readOnly: true,
                                            suffixIcon:
                                                Icons.calendar_month_outlined,
                                            onTap: _selecionarData,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              _DateInputFormatter(),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const _FieldLabel('Idade'),
                                          _InputBox(
                                            controller: _idadeController,
                                            hintText: 'Ex:63',
                                            keyboardType: TextInputType.number,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const _FieldLabel('Sexo'),
                                _SelectBox(
                                  value: _sexo,
                                  onChanged: (value) {
                                    setState(() => _sexo = value);
                                  },
                                ),
                                const SizedBox(height: 10),
                                const _FieldLabel('Condições de saúde'),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    for (final condicao in _condicoes)
                                      _ConditionChip(
                                        label: condicao,
                                        onDeleted: () {
                                          setState(
                                            () => _condicoes.remove(condicao),
                                          );
                                        },
                                      ),
                                    _AddConditionButton(
                                      onPressed: _adicionarCondicao,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const _FieldLabel('Limitações'),
                                _InputBox(
                                  controller: _limitacoesController,
                                  hintText: 'Ex:Penicilina',
                                ),
                                const SizedBox(height: 10),
                                const _FieldLabel('Contato de emergência'),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const _FieldLabel('Telefone'),
                                          _InputBox(
                                            controller: _telefoneController,
                                            hintText: '(00) 00000-0000',
                                            keyboardType: TextInputType.phone,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              _PhoneInputFormatter(),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const _FieldLabel('Nome'),
                                          _InputBox(
                                            controller: _contatoNomeController,
                                            hintText: 'Nome',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const _FieldLabel('Observações'),
                                _InputBox(
                                  controller: _observacoesController,
                                  hintText:
                                      'Observações sobre a rotina de cuidado',
                                  minLines: 2,
                                  maxLines: 3,
                                ),
                              ],
                            ),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFC0392B),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 25),
                          SizedBox(
                            height: 44,
                            child: FilledButton(
                              onPressed: _loading ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF3CB1C3),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(17),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Continuar'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CadastroHeader extends StatelessWidget {
  const _CadastroHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(7, 4, 28, 0),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: onBack,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.chevron_left_rounded,
                    color: Color(0xFF238FA1),
                    size: 31,
                  ),
                ),
              ),
              const Text(
                'Cadastro do idoso',
                style: TextStyle(
                  color: Color(0xFF249CB0),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 25),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: const LinearProgressIndicator(
                value: 0.5,
                minHeight: 12,
                backgroundColor: Color(0xFFF8F8F8),
                valueColor: AlwaysStoppedAnimation(Color(0xFF249CB0)),
              ),
            ),
          ),
          const SizedBox(height: 1),
          const Padding(
            padding: EdgeInsets.only(left: 25),
            child: Text(
              '1/2',
              style: TextStyle(
                color: Color(0xFF8A8A8A),
                fontSize: 12,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 2),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

class _InputBox extends StatelessWidget {
  const _InputBox({
    required this.controller,
    required this.hintText,
    this.validator,
    this.keyboardType,
    this.readOnly = false,
    this.suffixIcon,
    this.onTap,
    this.inputFormatters,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hintText;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final bool readOnly;
  final IconData? suffixIcon;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: maxLines > 1 ? 70 : 46),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        inputFormatters: inputFormatters,
        minLines: minLines,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14, color: Color(0xFF17324D)),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF9D9D9D), fontSize: 14),
          suffixIcon: suffixIcon == null
              ? null
              : Icon(suffixIcon, color: const Color(0xFF2697AA), size: 17),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 26,
            minHeight: 26,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 13,
          ),
          errorStyle: const TextStyle(fontSize: 9, height: 0.8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFF8BD2DC)),
          ),
        ),
      ),
    );
  }
}

class _SelectBox extends StatelessWidget {
  const _SelectBox({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        onChanged: onChanged,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Color(0xFF2697AA),
          size: 19,
        ),
        style: const TextStyle(fontSize: 14, color: Color(0xFF17324D)),
        decoration: InputDecoration(
          hintText: 'Selecione',
          hintStyle: const TextStyle(color: Color(0xFF9D9D9D), fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFF8BD2DC)),
          ),
        ),
        items: const [
          DropdownMenuItem(value: 'Feminino', child: Text('Feminino')),
          DropdownMenuItem(value: 'Masculino', child: Text('Masculino')),
          DropdownMenuItem(value: 'Outro', child: Text('Outro')),
        ],
      ),
    );
  }
}

class _ConditionChip extends StatelessWidget {
  const _ConditionChip({required this.label, required this.onDeleted});

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 35,
      padding: const EdgeInsets.only(left: 10, right: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F4F6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF9FD9E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF249CB0), fontSize: 12),
          ),
          const SizedBox(width: 3),
          InkWell(
            onTap: onDeleted,
            borderRadius: BorderRadius.circular(10),
            child: const Icon(
              Icons.close_rounded,
              color: Color(0xFF249CB0),
              size: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddConditionButton extends StatelessWidget {
  const _AddConditionButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 35,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add_rounded, size: 13),
        label: const Text('Adicionar'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF249CB0),
          side: const BorderSide(
            color: Color(0xFF249CB0),
            style: BorderStyle.solid,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final truncated = digits.length > 8 ? digits.substring(0, 8) : digits;
    final buffer = StringBuffer();

    for (var i = 0; i < truncated.length; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(truncated[i]);
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final truncated = digits.length > 11 ? digits.substring(0, 11) : digits;
    final buffer = StringBuffer();

    for (var i = 0; i < truncated.length; i++) {
      if (i == 0) buffer.write('(');
      if (i == 2) buffer.write(') ');
      if (i == 7) buffer.write('-');
      buffer.write(truncated[i]);
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

String? _toIsoDate(String value) {
  if (value.isEmpty) return null;
  final pieces = value.split('/');
  if (pieces.length != 3) return null;
  final day = int.tryParse(pieces[0]);
  final month = int.tryParse(pieces[1]);
  final year = int.tryParse(pieces[2]);
  if (day == null || month == null || year == null) return null;
  return '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

String _formatBrazilianDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year.toString().padLeft(4, '0')}';
}

int _calculateAge(DateTime birthDate, DateTime now) {
  var age = now.year - birthDate.year;
  final hadBirthday = now.month > birthDate.month ||
      (now.month == birthDate.month && now.day >= birthDate.day);
  if (!hadBirthday) age--;
  return age;
}
