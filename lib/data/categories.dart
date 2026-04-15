// Game categories and prompts for تخاطر game
const List<Map<String, String>> gameCategories = [
  {
    'category': 'أشياء حمراء اللون',
    'hint': 'فكّر في أول شيء أحمر يخطر ببالك',
    'emoji': '🔴',
  },
  {
    'category': 'حيوانات البحر',
    'hint': 'ما الكائن الأول الذي يخطر ببالك من أعماق البحر؟',
    'emoji': '🌊',
  },
  {
    'category': 'أكلات شعبية',
    'hint': 'أول أكلة شعبية تخطر ببالك',
    'emoji': '🍽️',
  },
  {
    'category': 'أشياء في المطبخ',
    'hint': 'ما أول شيء تراه في المطبخ؟',
    'emoji': '🍳',
  },
  {
    'category': 'حيوانات الغابة',
    'hint': 'أول حيوان في الغابة يخطر ببالك',
    'emoji': '🌳',
  },
  {
    'category': 'دول عربية',
    'hint': 'أول دولة عربية تخطر ببالك',
    'emoji': '🌍',
  },
  {
    'category': 'رياضات شعبية',
    'hint': 'أول رياضة تخطر ببالك',
    'emoji': '⚽',
  },
  {
    'category': 'فواكه استوائية',
    'hint': 'أول فاكهة استوائية تخطر ببالك',
    'emoji': '🍉',
  },
  {
    'category': 'مشاعر وأحاسيس',
    'hint': 'أول مشاعر تخطر ببالك الآن',
    'emoji': '💭',
  },
  {
    'category': 'أدوات منزلية',
    'hint': 'أول أداة منزلية تخطر ببالك',
    'emoji': '🔧',
  },
  {
    'category': 'ألوان الطيف',
    'hint': 'أول لون من ألوان قوس قزح يخطر ببالك',
    'emoji': '🌈',
  },
  {
    'category': 'طيور',
    'hint': 'أول طائر يخطر ببالك',
    'emoji': '🐦',
  },
  {
    'category': 'مدن عالمية',
    'hint': 'أول مدينة عالمية تخطر ببالك',
    'emoji': '🌆',
  },
  {
    'category': 'تقنية وتكنولوجيا',
    'hint': 'أول جهاز تقني يخطر ببالك',
    'emoji': '📱',
  },
  {
    'category': 'أشياء في الطبيعة',
    'hint': 'أول شيء تراه في الطبيعة يخطر ببالك',
    'emoji': '🌿',
  },
  {
    'category': 'أشياء في السماء',
    'hint': 'أول شيء في السماء يخطر ببالك',
    'emoji': '☁️',
  },
  {
    'category': 'حلويات وسكريات',
    'hint': 'أول حلوى تخطر ببالك',
    'emoji': '🍫',
  },
  {
    'category': 'وسائل المواصلات',
    'hint': 'أول وسيلة مواصلات تخطر ببالك',
    'emoji': '🚗',
  },
  {
    'category': 'أشياء بيضاء',
    'hint': 'أول شيء أبيض يخطر ببالك',
    'emoji': '⬜',
  },
  {
    'category': 'موسيقى وغناء',
    'hint': 'أول موسيقي أو مغني يخطر ببالك',
    'emoji': '🎵',
  },
];

List<Map<String, String>> getShuffledCategories(int count) {
  final list = List<Map<String, String>>.from(gameCategories);
  list.shuffle();
  return list.take(count).toList();
}
