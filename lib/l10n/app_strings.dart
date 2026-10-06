import 'package:flutter/widgets.dart';

class AppStrings {
  const AppStrings(this.locale);
  final Locale locale;
  bool get ru => locale.languageCode == 'ru';
  String get gameTitle => 'FLOWLINE';
  String get city => ru ? 'Ривергейт' : 'Rivergate';
  String get score => ru ? 'ДОСТАВКИ' : 'DELIVERIES';
  String get day => ru ? 'День' : 'Day';
  String get settings => ru ? 'Настройки' : 'Settings';
  String get sound => ru ? 'Звук' : 'Sound';
  String get tutorial => ru ? 'Повторить обучение' : 'Replay tutorial';
  String get fit => ru ? 'Вписать карту' : 'Fit map';
  String get difficulty => ru ? 'Новая игра' : 'New game';
  String get normal => ru ? 'Обычный' : 'Normal';
  String get realism => ru ? 'Реализм' : 'Realism';
  String get infinite => ru ? 'Бесконечный' : 'Infinite';
  String get sandbox => ru ? 'Песочница' : 'Sandbox';
  String get gameOver => ru ? 'СЕТЬ ОСТАНОВИЛАСЬ' : 'THE NETWORK STOPPED';
  String get gameOverBody => ru ? 'Один из районов ждал слишком долго.' : 'One neighborhood waited too long.';
  String get restart => ru ? 'Начать заново' : 'Restart';
  String get continueAd => ru ? 'Очистить очередь и продолжить' : 'Clear queue & continue';
  String get reward => ru ? 'СЕТЬ РАСТЁТ' : 'THE NETWORK GROWS';
  String get choose => ru ? 'Выберите одно улучшение' : 'Choose one upgrade';
  String get line => ru ? 'Новая линия' : 'New line';
  String get walker => ru ? 'Пеший курьер' : 'Walker';
  String get bike => ru ? 'Велокурьер' : 'Cyclist';
  String get car => ru ? 'Автокурьер' : 'Driver';
  String get ferry => ru ? 'Паром' : 'Ferry';
  String get house => ru ? 'Дом: лимит +4' : 'Home: limit +4';
  String get hint => ru ? 'Соедините одинаковые фигуры: ресторан → заказчик' : 'Connect matching shapes: restaurant → customer';
  String get lineHint => ru ? 'Тап по двум точкам создаёт линию. Перетащите курьера на маршрут.' : 'Tap two stops to make a line. Drag a courier onto it.';
  String get attribution => '© OpenStreetMap contributors';
  static AppStrings of(BuildContext context) => Localizations.of<AppStrings>(context, AppStrings)!;
}

class AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const AppStringsDelegate();
  @override bool isSupported(Locale locale) => <String>['en', 'ru'].contains(locale.languageCode);
  @override Future<AppStrings> load(Locale locale) async => AppStrings(locale);
  @override bool shouldReload(covariant LocalizationsDelegate<AppStrings> old) => false;
}
