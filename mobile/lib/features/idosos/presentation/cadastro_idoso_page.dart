import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../monitoramento/presentation/monitoramento_catalog.dart';

class CadastroIdosoPage extends ConsumerStatefulWidget {
  const CadastroIdosoPage({super.key, this.edicao = false, this.from});

  final bool edicao;
  final String? from;

  @override
  ConsumerState<CadastroIdosoPage> createState() => _CadastroIdosoPageState();
}

class _CadastroIdosoPageState extends ConsumerState<CadastroIdosoPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _dataNascimentoController = TextEditingController();
  final _idadeController = TextEditingController();
  final _tipoSanguineoController = TextEditingController();
  final _limitacoesController = TextEditingController();
  final _alergiasController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _contatoNomeController = TextEditingController();
  final _contatoParentescoController = TextEditingController();
  final _observacoesController = TextEditingController();
  final _picker = ImagePicker();

  final List<String> _condicoes = [];
  String? _sexo;
  Uint8List? _fotoBytes;
  String? _fotoUrl;
  bool _loading = false;
  int _currentStep = 0;
  String? _errorMessage;
  final Set<String> _monitoramentosSelecionados = {...defaultMonitoramentoIds};

  static const _stepTitles = [
    'Dados básicos',
    'Saúde',
    'Contato e observações',
    'Monitoramento',
  ];

  bool get _isEditing => widget.edicao;
  int get _totalSteps => _isEditing ? 3 : 4;
  String get _backRoute =>
      widget.from == 'idoso-perfil' ? '/idoso/perfil' : '/dashboard';

  @override
  void initState() {
    super.initState();
    if (!_isEditing) return;

    final idoso = ref.read(selectedIdosoProvider);
    if (idoso == null) return;

    _nomeController.text = idoso.nome;
    if (idoso.idade > 0) _idadeController.text = idoso.idade.toString();
    if (idoso.dataNascimento != null && idoso.dataNascimento!.length >= 10) {
      final parsed = DateTime.tryParse(idoso.dataNascimento!.substring(0, 10));
      if (parsed != null) {
        _dataNascimentoController.text = _formatBrazilianDate(parsed);
      }
    }
    _sexo = idoso.sexo;
    _tipoSanguineoController.text = idoso.tipoSanguineo ?? '';
    _limitacoesController.text = idoso.limitacoes ?? '';
    _alergiasController.text = idoso.alergiasRestricoes ?? '';
    _observacoesController.text = idoso.observacoesGerais ?? '';
    _telefoneController.text = idoso.contatoEmergenciaTelefone ?? '';
    _contatoNomeController.text = idoso.contatoEmergenciaNome ?? '';
    _contatoParentescoController.text = idoso.contatoEmergenciaParentesco ?? '';
    _fotoUrl = idoso.urlFoto;
    _condicoes
      ..clear()
      ..addAll(idoso.condicoes);
    _monitoramentosSelecionados
      ..clear()
      ..addAll(
        idoso.monitoramentos.isEmpty
            ? defaultMonitoramentoIds
            : idoso.monitoramentos,
      );
  }

  ImageProvider? get _profileImageProvider {
    if (_fotoBytes != null) return MemoryImage(_fotoBytes!);
    final url = _fotoUrl;
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      final commaIndex = url.indexOf(',');
      if (commaIndex == -1) return null;
      try {
        final bytes = base64Decode(url.substring(commaIndex + 1));
        return MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    }
    if (url.startsWith('http')) return NetworkImage(url);
    return null;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _dataNascimentoController.dispose();
    _idadeController.dispose();
    _tipoSanguineoController.dispose();
    _limitacoesController.dispose();
    _alergiasController.dispose();
    _telefoneController.dispose();
    _contatoNomeController.dispose();
    _contatoParentescoController.dispose();
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

  void _goNext() {
    FocusScope.of(context).unfocus();

    if (_currentStep == 0 && !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_currentStep == 2) {
      if (_isEditing) {
        _submit();
        return;
      }
      setState(() {
        _currentStep = 3;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _currentStep += 1;
      _errorMessage = null;
    });
  }

  void _handleBack() {
    FocusScope.of(context).unfocus();

    if (_currentStep > 0) {
      setState(() {
        _currentStep -= 1;
        _errorMessage = null;
      });
      return;
    }

    context.go(_isEditing ? _backRoute : '/idosos');
  }

  void _toggleMonitoramento(String id) {
    setState(() {
      if (_monitoramentosSelecionados.contains(id)) {
        _monitoramentosSelecionados.remove(id);
      } else {
        _monitoramentosSelecionados.add(id);
      }
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (_monitoramentosSelecionados.isEmpty) {
      setState(() {
        _errorMessage = 'Selecione pelo menos um monitoramento.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final usuarioId = ref.read(authSessionProvider)?.id;
      final fotoUrl = _fotoBytes == null
          ? _fotoUrl
          : 'data:image/jpeg;base64,${base64Encode(_fotoBytes!)}';
      final dataNascimento = _toIsoDate(_dataNascimentoController.text.trim());
      final selectedIdoso = ref.read(selectedIdosoProvider);
      final response = _isEditing && selectedIdoso != null
          ? await apiClient.atualizarIdoso(
              id: selectedIdoso.id,
              data: {
                'nomeCompleto': _nomeController.text.trim(),
                if (usuarioId != null && usuarioId.isNotEmpty)
                  'criadoPorId': usuarioId,
                if (dataNascimento != null) 'dataNascimento': dataNascimento,
                if (fotoUrl != null && fotoUrl.isNotEmpty) 'urlFoto': fotoUrl,
                if (_sexo != null && _sexo!.isNotEmpty) 'sexo': _sexo,
                if (_tipoSanguineoController.text.trim().isNotEmpty)
                  'tipoSanguineo': _tipoSanguineoController.text.trim(),
                'condicoesSaude': _condicoes,
                'monitoramentos': _monitoramentosSelecionados.toList(),
                if (_limitacoesController.text.trim().isNotEmpty)
                  'limitacoes': _limitacoesController.text.trim(),
                if (_alergiasController.text.trim().isNotEmpty)
                  'alergiasRestricoes': _alergiasController.text.trim(),
                if (_observacoesController.text.trim().isNotEmpty)
                  'observacoesGerais': _observacoesController.text.trim(),
                if (_contatoNomeController.text.trim().isNotEmpty)
                  'contatoEmergenciaNome': _contatoNomeController.text.trim(),
                if (_telefoneController.text.trim().isNotEmpty)
                  'contatoEmergenciaTelefone': _telefoneController.text.trim(),
                if (_contatoParentescoController.text.trim().isNotEmpty)
                  'contatoEmergenciaParentesco':
                      _contatoParentescoController.text.trim(),
              },
            )
          : await apiClient.criarIdoso(
              nomeCompleto: _nomeController.text.trim(),
              criadoPorId: usuarioId,
              dataNascimento: dataNascimento,
              urlFoto: fotoUrl,
              sexo: _sexo,
              tipoSanguineo: _tipoSanguineoController.text.trim(),
              condicoesSaude: _condicoes,
              monitoramentos: _monitoramentosSelecionados.toList(),
              limitacoes: _limitacoesController.text.trim(),
              alergiasRestricoes: _alergiasController.text.trim(),
              observacoesGerais: _observacoesController.text.trim(),
              contatoEmergenciaNome: _contatoNomeController.text.trim(),
              contatoEmergenciaTelefone: _telefoneController.text.trim(),
              contatoEmergenciaParentesco:
                  _contatoParentescoController.text.trim(),
            );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Ficha atualizada com sucesso.'
                : 'Ficha criada com sucesso.',
          ),
        ),
      );
      ref.invalidate(idososDoUsuarioProvider);
      final dados = response['dados'];
      final idosoId = dados is Map<String, dynamic>
          ? dados['id']?.toString() ?? selectedIdoso?.id ?? ''
          : selectedIdoso?.id ?? '';
      ref.read(selectedIdosoProvider.notifier).state = IdosoResumo(
        id: idosoId,
        nome: _nomeController.text.trim(),
        idade: int.tryParse(_idadeController.text.trim()) ?? 0,
        urlFoto: fotoUrl,
        dataNascimento: dataNascimento,
        sexo: _sexo,
        tipoSanguineo: _tipoSanguineoController.text.trim().isEmpty
            ? null
            : _tipoSanguineoController.text.trim(),
        limitacoes: _limitacoesController.text.trim().isEmpty
            ? null
            : _limitacoesController.text.trim(),
        alergiasRestricoes: _alergiasController.text.trim().isEmpty
            ? null
            : _alergiasController.text.trim(),
        observacoesGerais: _observacoesController.text.trim().isEmpty
            ? null
            : _observacoesController.text.trim(),
        contatoEmergenciaNome: _contatoNomeController.text.trim().isEmpty
            ? null
            : _contatoNomeController.text.trim(),
        contatoEmergenciaTelefone: _telefoneController.text.trim().isEmpty
            ? null
            : _telefoneController.text.trim(),
        contatoEmergenciaParentesco:
            _contatoParentescoController.text.trim().isEmpty
                ? null
                : _contatoParentescoController.text.trim(),
        condicoes: _condicoes,
        monitoramentos: _monitoramentosSelecionados.toList(),
      );
      context.go(_isEditing ? _backRoute : '/dashboard');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _isEditing
            ? 'Nao foi possivel atualizar a ficha. Confira sua conexao e tente novamente.'
            : 'Nao foi possivel criar a ficha. Confira sua conexao e tente novamente.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: adaptive(context, const Color(0xFFFBFBFB), AppDarkColors.bg),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDarkMode(context) ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: Column(
            children: [
              _CadastroHeader(
                onBack: _handleBack,
                stepIndex: _currentStep,
                totalSteps: _totalSteps,
                stepTitle: _stepTitles[_currentStep],
                editing: _isEditing,
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: _buildStep(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 0:
        return _dataStep(
          key: const ValueKey('step-basico'),
          formKey: _formKey,
          subtitle: _isEditing
              ? 'Ajuste as informacoes cadastradas'
              : 'Comece registrando os principais dados',
          onPrimary: _goNext,
          primaryLabel: 'Continuar',
          content: _basicoFields(),
        );
      case 1:
        return _dataStep(
          key: const ValueKey('step-saude'),
          subtitle: 'Registre condicoes, limitacoes e alergias',
          onPrimary: _goNext,
          primaryLabel: 'Continuar',
          showBack: true,
          content: _saudeFields(),
        );
      case 2:
        return _dataStep(
          key: const ValueKey('step-contato'),
          subtitle: 'Quem acionar em caso de emergencia',
          onPrimary: _goNext,
          primaryLabel: _isEditing ? 'Salvar' : 'Continuar',
          showBack: true,
          content: _contatoFields(),
        );
      default:
        return _MonitoramentosStep(
          key: const ValueKey('monitoramentos-step'),
          selectedIds: _monitoramentosSelecionados,
          loading: _loading,
          errorMessage: _errorMessage,
          onToggle: _toggleMonitoramento,
          onSubmit: _submit,
        );
    }
  }

  Widget _dataStep({
    required Key key,
    required Widget content,
    required String subtitle,
    required VoidCallback onPrimary,
    required String primaryLabel,
    bool showBack = false,
    GlobalKey<FormState>? formKey,
  }) {
    final card = Container(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
      decoration: BoxDecoration(
        color: adaptive(context, Colors.white, AppDarkColors.surface),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: adaptive(context, const Color(0xFF8BD2DC), AppDarkColors.border),
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
      child: content,
    );

    return SingleChildScrollView(
      key: key,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        14,
        0,
        14,
        34 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 1),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: adaptive(context, const Color(0xFF8A8A8A), AppDarkColors.textSecondary),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 12),
          formKey != null ? Form(key: formKey, child: card) : card,
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
          Row(
            children: [
              if (showBack) ...[
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: _loading ? null : _handleBack,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF3CB1C3),
                        side: BorderSide(
                          color: adaptive(context, const Color(0xFF8BD2DC), AppDarkColors.border),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Voltar'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: showBack ? 2 : 1,
                child: SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: _loading ? null : onPrimary,
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
                        : Text(primaryLabel),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _basicoFields() {
    return Column(
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
                  image: _profileImageProvider == null
                      ? null
                      : DecorationImage(
                          image: _profileImageProvider!,
                          fit: BoxFit.cover,
                        ),
                ),
                child: _profileImageProvider == null
                    ? const Icon(
                        Icons.add_rounded,
                        color: Color(0xFF2697AA),
                        size: 38,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Foto do Idoso',
                  style: TextStyle(
                    color: Color(0xFF249CB0),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'toque para adicionar',
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF9B9B9B), AppDarkColors.textMuted),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('Data de nascimento'),
                  _InputBox(
                    controller: _dataNascimentoController,
                    hintText: 'dd/mm/aaaa',
                    readOnly: true,
                    suffixIcon: Icons.calendar_month_outlined,
                    onTap: _selecionarData,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _DateInputFormatter(),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
        const _FieldLabel('Tipo sanguineo'),
        _BloodTypeField(controller: _tipoSanguineoController),
      ],
    );
  }

  Widget _saudeFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  setState(() => _condicoes.remove(condicao));
                },
              ),
            _AddConditionButton(onPressed: _adicionarCondicao),
          ],
        ),
        const SizedBox(height: 10),
        const _FieldLabel('Limitações'),
        _InputBox(
          controller: _limitacoesController,
          hintText: 'Ex:Penicilina',
        ),
        const SizedBox(height: 10),
        const _FieldLabel('Alergias'),
        _InputBox(
          controller: _alergiasController,
          hintText: 'Ex: lactose, poeira',
        ),
      ],
    );
  }

  Widget _contatoFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Contato de emergência'),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('Telefone'),
                  _InputBox(
                    controller: _telefoneController,
                    hintText: '(00) 00000-0000',
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _PhoneInputFormatter(),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
        const _FieldLabel('Parentesco ou observacao'),
        _InputBox(
          controller: _contatoParentescoController,
          hintText: 'Ex: filha, vizinho',
        ),
        if (_isEditing) ...[
          const SizedBox(height: 10),
          InkWell(
            onTap: () => context.go('/idoso/acessos'),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.link_rounded,
                    color: Color(0xFF2BA8BA),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Acessos',
                      style: TextStyle(
                        color: adaptive(context, const Color(0xFF073248), AppDarkColors.textPrimary),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: adaptive(context, const Color(0xFF6E7C83), AppDarkColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        const _FieldLabel('Observacoes'),
        _InputBox(
          controller: _observacoesController,
          hintText: 'Observações sobre a rotina de cuidado',
          minLines: 2,
          maxLines: 3,
        ),
      ],
    );
  }
}

class _MonitoramentosStep extends StatelessWidget {
  const _MonitoramentosStep({
    required this.selectedIds,
    required this.loading,
    required this.onToggle,
    required this.onSubmit,
    this.errorMessage,
    super.key,
  });

  final Set<String> selectedIds;
  final bool loading;
  final String? errorMessage;
  final ValueChanged<String> onToggle;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'O que voce deseja monitorar',
            style: TextStyle(
              color: adaptive(context, const Color(0xFF073248), AppDarkColors.textPrimary),
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              itemCount: monitoramentoOptions.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 11,
                crossAxisSpacing: 14,
                childAspectRatio: 1.8,
              ),
              itemBuilder: (context, index) {
                final option = monitoramentoOptions[index];
                return _MonitoramentoCard(
                  option: option,
                  selected: selectedIds.contains(option.id),
                  onTap: loading ? null : () => onToggle(option.id),
                );
              },
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFC0392B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: FilledButton(
              onPressed: loading ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3CB1C3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Acessar ficha'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonitoramentoCard extends StatelessWidget {
  const _MonitoramentoCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final MonitoramentoOption option;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        selected ? const Color(0xFF38AFC0) : const Color(0xFF3BA7B8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: selected
                ? adaptive(context, const Color(0xFFE0F0F3), AppDarkColors.tintedInfo)
                : adaptive(context, Colors.white, AppDarkColors.surface),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1C000000),
                blurRadius: 4,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 10, 10, 10),
                child: Row(
                  children: [
                    _MonitoramentoIcon(icon: option.icon, selected: selected),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        option.selectionLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: adaptive(context, const Color(0xFF394B52), AppDarkColors.textPrimary),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Positioned(
                  right: 5,
                  top: 5,
                  child: _SelectedBadge(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonitoramentoIcon extends StatelessWidget {
  const _MonitoramentoIcon({required this.icon, required this.selected});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 39,
      height: 39,
      decoration: BoxDecoration(
        color: selected
            ? adaptive(context, Colors.white, AppDarkColors.surface)
            : adaptive(context, const Color(0xFFE9F5F7), AppDarkColors.surfaceAlt),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(
        icon,
        color: const Color(0xFF2BA8BA),
        size: 25,
      ),
    );
  }
}

class _SelectedBadge extends StatelessWidget {
  const _SelectedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 23,
      height: 23,
      decoration: const BoxDecoration(
        color: Color(0xFF58B7BE),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.check_rounded,
        color: Colors.white,
        size: 18,
      ),
    );
  }
}

class _CadastroHeader extends StatelessWidget {
  const _CadastroHeader({
    required this.onBack,
    required this.stepIndex,
    required this.totalSteps,
    required this.stepTitle,
    required this.editing,
  });

  final VoidCallback onBack;
  final int stepIndex;
  final int totalSteps;
  final String stepTitle;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final current = stepIndex + 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(7, 4, 28, 8),
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
              Text(
                editing ? 'Editar idoso' : 'Cadastro do idoso',
                style: const TextStyle(
                  color: Color(0xFF249CB0),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: current / totalSteps),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  minHeight: 8,
                  value: value,
                  backgroundColor: adaptive(context, const Color(0xFFE7EEF0), AppDarkColors.border),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF3BA7B8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    stepTitle,
                    style: TextStyle(
                      color: adaptive(context, const Color(0xFF17324D), AppDarkColors.textPrimary),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
                Text(
                  '$current/$totalSteps',
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF8A8A8A), AppDarkColors.textMuted),
                    fontSize: 12,
                    height: 1,
                  ),
                ),
              ],
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
        style: TextStyle(
          color: adaptive(context, Colors.black, AppDarkColors.textPrimary),
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
        style: TextStyle(fontSize: 14, color: adaptive(context, const Color(0xFF17324D), AppDarkColors.textPrimary)),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: adaptive(context, const Color(0xFF9D9D9D), AppDarkColors.textMuted), fontSize: 14),
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
            borderSide: BorderSide(color: adaptive(context, const Color(0xFFD0D0D0), AppDarkColors.border)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: BorderSide(color: adaptive(context, const Color(0xFFD0D0D0), AppDarkColors.border)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: BorderSide(color: adaptive(context, const Color(0xFF8BD2DC), AppDarkColors.borderStrong)),
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
        style: TextStyle(fontSize: 14, color: adaptive(context, const Color(0xFF17324D), AppDarkColors.textPrimary)),
        decoration: InputDecoration(
          hintText: 'Selecione',
          hintStyle: TextStyle(color: adaptive(context, const Color(0xFF9D9D9D), AppDarkColors.textMuted), fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: BorderSide(color: adaptive(context, const Color(0xFFD0D0D0), AppDarkColors.border)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: BorderSide(color: adaptive(context, const Color(0xFFD0D0D0), AppDarkColors.border)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: BorderSide(color: adaptive(context, const Color(0xFF8BD2DC), AppDarkColors.borderStrong)),
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

class _BloodTypeField extends StatefulWidget {
  const _BloodTypeField({required this.controller});

  static const _options = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  final TextEditingController controller;

  @override
  State<_BloodTypeField> createState() => _BloodTypeFieldState();
}

class _BloodTypeFieldState extends State<_BloodTypeField> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (value) {
        final query = value.text.trim().toUpperCase();
        if (query.isEmpty) return _BloodTypeField._options;
        return _BloodTypeField._options.where((option) {
          return option.startsWith(query);
        });
      },
      onSelected: (value) => widget.controller.text = value,
      fieldViewBuilder: (
        context,
        fieldController,
        focusNode,
        onFieldSubmitted,
      ) {
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 46),
          child: TextFormField(
            controller: fieldController,
            focusNode: focusNode,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[ABOabo+-]')),
              TextInputFormatter.withFunction((oldValue, newValue) {
                return newValue.copyWith(text: newValue.text.toUpperCase());
              }),
            ],
            validator: (value) {
              final text = value?.trim();
              if (text == null || text.isEmpty) return null;
              if (!_BloodTypeField._options.contains(text)) {
                return 'Selecione um tipo sanguineo valido.';
              }
              return null;
            },
            style: TextStyle(fontSize: 14, color: adaptive(context, const Color(0xFF17324D), AppDarkColors.textPrimary)),
            decoration: InputDecoration(
              hintText: 'Ex: O+',
              hintStyle: TextStyle(
                color: adaptive(context, const Color(0xFF9D9D9D), AppDarkColors.textMuted),
                fontSize: 14,
              ),
              suffixIcon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF2697AA),
                size: 19,
              ),
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
                borderSide: BorderSide(color: adaptive(context, const Color(0xFFD0D0D0), AppDarkColors.border)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: BorderSide(color: adaptive(context, const Color(0xFFD0D0D0), AppDarkColors.border)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: BorderSide(color: adaptive(context, const Color(0xFF8BD2DC), AppDarkColors.borderStrong)),
              ),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180, maxWidth: 160),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(option),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
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
        color: adaptive(context, const Color(0xFFE0F4F6), AppDarkColors.surfaceAlt),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: adaptive(context, const Color(0xFF9FD9E1), AppDarkColors.border),
        ),
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
