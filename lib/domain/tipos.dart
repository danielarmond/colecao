/// Situação de um item em relação à coleção.
///
/// Os nomes do enum são gravados no banco como texto, então não renomeie
/// os valores sem criar uma migração.
enum StatusItem {
  naColecao('Na Coleção'),
  aguardando('Aguardando'),
  naFila('Na Fila'),
  ignorado('Ignorado');

  const StatusItem(this.rotulo);

  final String rotulo;

  /// Código usado no CSV (na_colecao, aguardando, na_fila, ignorado).
  String get codigo => switch (this) {
        StatusItem.naColecao => 'na_colecao',
        StatusItem.aguardando => 'aguardando',
        StatusItem.naFila => 'na_fila',
        StatusItem.ignorado => 'ignorado',
      };

  /// Conta no numerador do progresso (é seu ou já foi comprado).
  bool get ehMeu => this == naColecao || this == aguardando;

  /// Conta no denominador do progresso (faz parte da meta).
  bool get contaNaMeta => this != ignorado;
}

/// Estado físico do exemplar.
enum Condicao {
  lacrado('Lacrado'),
  completo('Completo'),
  semManual('Sem manual'),
  soMidia('Só a mídia');

  const Condicao(this.rotulo);

  final String rotulo;
}

/// De onde veio o cadastro de um jogo.
enum OrigemJogo { manual, rawg }
