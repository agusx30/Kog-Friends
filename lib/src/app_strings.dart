enum AppLanguage {
  es('es', 'Español'),
  en('en', 'English'),
  pt('pt', 'Português');

  const AppLanguage(this.code, this.label);
  final String code;
  final String label;

  static AppLanguage fromCode(String? code) {
    for (final lang in AppLanguage.values) {
      if (lang.code == code) return lang;
    }
    return AppLanguage.es;
  }
}

class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  String get donateTooltip => switch (language) {
        AppLanguage.es => 'Donar',
        AppLanguage.en => 'Donate',
        AppLanguage.pt => 'Doar',
      };

  String get languageTooltip => switch (language) {
        AppLanguage.es => 'Cambiar idioma',
        AppLanguage.en => 'Change language',
        AppLanguage.pt => 'Mudar idioma',
      };

  String get refreshTooltip => switch (language) {
        AppLanguage.es => 'Actualizar ahora',
        AppLanguage.en => 'Refresh now',
        AppLanguage.pt => 'Atualizar agora',
      };

  String get howToAddButton => switch (language) {
        AppLanguage.es => 'Cómo agregar?',
        AppLanguage.en => 'How to add?',
        AppLanguage.pt => 'Como adicionar?',
      };

  String get addFriendsButton => switch (language) {
        AppLanguage.es => 'Agregar amigos',
        AppLanguage.en => 'Add friends',
        AppLanguage.pt => 'Adicionar amigos',
      };

  String get yourFriendsHeader => switch (language) {
        AppLanguage.es => 'TUS AMIGOS',
        AppLanguage.en => 'YOUR FRIENDS',
        AppLanguage.pt => 'SEUS AMIGOS',
      };

  String get activeFriendsHeader => switch (language) {
        AppLanguage.es => 'ACTIVOS',
        AppLanguage.en => 'ACTIVE',
        AppLanguage.pt => 'ATIVOS',
      };

  String get inactiveFriendsHeader => switch (language) {
        AppLanguage.es => 'INACTIVOS',
        AppLanguage.en => 'INACTIVE',
        AppLanguage.pt => 'INATIVOS',
      };

  String get noActiveFriends => switch (language) {
        AppLanguage.es => 'Ningún amigo en línea en este momento',
        AppLanguage.en => 'No friends online right now',
        AppLanguage.pt => 'Nenhum amigo online no momento',
      };

  String get noInactiveFriends => switch (language) {
        AppLanguage.es => 'Todos tus amigos están en línea',
        AppLanguage.en => 'All your friends are online',
        AppLanguage.pt => 'Todos os seus amigos estão online',
      };

  String onlineSummary(int totalCount) => switch (language) {
        AppLanguage.es => 'de $totalCount amigos en línea',
        AppLanguage.en => 'of $totalCount friends online',
        AppLanguage.pt => 'de $totalCount amigos online',
      };

  String widgetSummary(int onlineCount, int totalCount) => switch (language) {
        AppLanguage.es => '$onlineCount de $totalCount amigos en línea',
        AppLanguage.en => '$onlineCount of $totalCount friends online',
        AppLanguage.pt => '$onlineCount de $totalCount amigos online',
      };

  String get updatingStatus => switch (language) {
        AppLanguage.es => 'Actualizando…',
        AppLanguage.en => 'Updating…',
        AppLanguage.pt => 'Atualizando…',
      };

  String get noRecentData => switch (language) {
        AppLanguage.es => 'Sin datos recientes',
        AppLanguage.en => 'No recent data',
        AppLanguage.pt => 'Sem dados recentes',
      };

  String updatedAt(String formattedTime) => switch (language) {
        AppLanguage.es => 'Actualizado $formattedTime',
        AppLanguage.en => 'Updated $formattedTime',
        AppLanguage.pt => 'Atualizado $formattedTime',
      };

  String get offlineInDDNet => switch (language) {
        AppLanguage.es => 'Sin conexión en DDNet',
        AppLanguage.en => 'Offline on DDNet',
        AppLanguage.pt => 'Offline no DDNet',
      };

  String get removeTooltip => switch (language) {
        AppLanguage.es => 'Quitar de la lista',
        AppLanguage.en => 'Remove from list',
        AppLanguage.pt => 'Remover da lista',
      };

  String get emptyFriendsTitle => switch (language) {
        AppLanguage.es => 'Todavía no agregaste amigos',
        AppLanguage.en => 'You haven\'t added friends yet',
        AppLanguage.pt => 'Você ainda não adicionou amigos',
      };

  String get emptyFriendsSubtitle => switch (language) {
        AppLanguage.es =>
          'Escribí un nombre o pegá tus comandos add_friend para empezar.',
        AppLanguage.en =>
          'Type a name or paste your add_friend commands to get started.',
        AppLanguage.pt =>
          'Digite um nome ou cole seus comandos add_friend para começar.',
      };

  String get addDialogDescription => switch (language) {
        AppLanguage.es =>
          'Escribí un nombre por línea, o pegá comandos add_friend '
              'copiados de DDNet. Se importa el nombre y se ignora el clan. '
              'También se admite add_player.',
        AppLanguage.en =>
          'Type one name per line, or paste add_friend commands '
              'copied from DDNet. The name is imported and the clan is ignored. '
              'add_player is also supported.',
        AppLanguage.pt =>
          'Digite um nome por linha, ou cole comandos add_friend '
              'copiados do DDNet. O nome é importado e o clã é ignorado. '
              'Também aceita add_player.',
      };

  String get addDialogHint => switch (language) {
        AppLanguage.es =>
          'agus\nOtroJugador\nadd_friend "Nombre del jugador" "Clan"',
        AppLanguage.en =>
          'agus\nOtherPlayer\nadd_friend "Player name" "Clan"',
        AppLanguage.pt =>
          'agus\nOutroJogador\nadd_friend "Nome do jogador" "Clã"',
      };

  String get cancelButton => switch (language) {
        AppLanguage.es => 'Cancelar',
        AppLanguage.en => 'Cancel',
        AppLanguage.pt => 'Cancelar',
      };

  String get addButton => switch (language) {
        AppLanguage.es => 'Agregar',
        AppLanguage.en => 'Add',
        AppLanguage.pt => 'Adicionar',
      };

  String get howToIntro => switch (language) {
        AppLanguage.es => 'Hay dos formas de agregar amigos:',
        AppLanguage.en => 'There are two ways to add friends:',
        AppLanguage.pt => 'Existem duas formas de adicionar amigos:',
      };

  String get howToStep1 => switch (language) {
        AppLanguage.es =>
          '1. Agrégalos uno por uno escribiendo su nombre directo '
              '(ej. agus) o pegando un comando add_friend.',
        AppLanguage.en =>
          '1. Add them one by one by typing their name directly '
              '(e.g. agus) or pasting an add_friend command.',
        AppLanguage.pt =>
          '1. Adicione um por um digitando o nome diretamente '
              '(ex. agus) ou colando um comando add_friend.',
      };

  String get howToStep2 => switch (language) {
        AppLanguage.es =>
          '2. O andá a "%appdata%", entrá a AppData\\Roaming\\DDNet '
              'y abrí settings_ddnet.cfg. Al final del cfg están los '
              'add_friend: ahí los podés copiar todos de una.',
        AppLanguage.en =>
          '2. Or go to "%appdata%", open AppData\\Roaming\\DDNet '
              'and open settings_ddnet.cfg. At the end of the file you will find '
              'all your add_friend lines to copy at once.',
        AppLanguage.pt =>
          '2. Ou vá em "%appdata%", entre em AppData\\Roaming\\DDNet '
              'e abra settings_ddnet.cfg. No final do arquivo estão os '
              'add_friend: lá você pode copiar todos de uma vez.',
      };

  String get doneButton => switch (language) {
        AppLanguage.es => 'Listo',
        AppLanguage.en => 'Done',
        AppLanguage.pt => 'Pronto',
      };

  String get alreadyInListMessage => switch (language) {
        AppLanguage.es => 'Los amigos ya estaban en la lista.',
        AppLanguage.en => 'Those friends were already in the list.',
        AppLanguage.pt => 'Esses amigos já estavam na lista.',
      };

  String get emptyInputError => switch (language) {
        AppLanguage.es =>
          'Escribí al menos un nombre o pegá un comando add_friend.',
        AppLanguage.en =>
          'Type at least one name or paste an add_friend command.',
        AppLanguage.pt =>
          'Digite pelo menos um nome ou cole um comando add_friend.',
      };

  String loadError(Object error) => switch (language) {
        AppLanguage.es => 'No se pudo cargar la lista guardada: $error',
        AppLanguage.en => 'Could not load saved list: $error',
        AppLanguage.pt => 'Não foi possível carregar a lista salva: $error',
      };

  String refreshError(Object error) => switch (language) {
        AppLanguage.es => 'No se pudo actualizar el estado: $error',
        AppLanguage.en => 'Could not update status: $error',
        AppLanguage.pt => 'Não foi possível atualizar o status: $error',
      };

  String saveError(Object error) => switch (language) {
        AppLanguage.es => 'No se pudo guardar la lista: $error',
        AppLanguage.en => 'Could not save list: $error',
        AppLanguage.pt => 'Não foi possível salvar a lista: $error',
      };
}
