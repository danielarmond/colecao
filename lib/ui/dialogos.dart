import 'package:flutter/material.dart';

/// Pede um nome (nova coleção, renomear). Devolve null se cancelar ou vazio.
Future<String?> pedirNome(
  BuildContext context, {
  required String titulo,
  String inicial = '',
  String dica = '',
  String confirmar = 'Salvar',
}) async {
  final nome = await showDialog<String>(
    context: context,
    builder: (_) => _NomeDialog(
      titulo: titulo,
      inicial: inicial,
      dica: dica,
      confirmar: confirmar,
    ),
  );
  final t = nome?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

/// O diálogo cuida do próprio TextEditingController, que só é liberado
/// quando o diálogo sai da tela (depois da animação de fechamento).
class _NomeDialog extends StatefulWidget {
  const _NomeDialog({
    required this.titulo,
    required this.inicial,
    required this.dica,
    required this.confirmar,
  });

  final String titulo;
  final String inicial;
  final String dica;
  final String confirmar;

  @override
  State<_NomeDialog> createState() => _NomeDialogState();
}

class _NomeDialogState extends State<_NomeDialog> {
  late final _controle = TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: TextField(
        controller: _controle,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(hintText: widget.dica),
        onSubmitted: (t) => Navigator.pop(context, t),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controle.text),
          child: Text(widget.confirmar),
        ),
      ],
    );
  }
}

/// Confirmação simples. Devolve true se confirmar.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  String botao = 'Confirmar',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: SingleChildScrollView(child: Text(mensagem)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(botao),
        ),
      ],
    ),
  );
  return r == true;
}
