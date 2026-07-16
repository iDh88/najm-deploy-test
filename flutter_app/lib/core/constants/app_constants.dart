/// Layover Hub shared constants.
///
/// F24: this file was referenced by category_tab_bar, filter_bar,
/// city_detail_screen and add_recommendation_screen but absent from the
/// repository. Category ids and emoji icons match the mapping already
/// hard-coded in recommendation_card.dart (_catEmoji) and the values stored
/// on `recommendations` documents — do not rename ids without a data
/// migration.
class LayoverCategory {
  final String id;
  final String label;

  /// Emoji glyph rendered inside a [Text] (see category_tab_bar.dart).
  final String icon;

  const LayoverCategory({
    required this.id,
    required this.label,
    required this.icon,
  });
}

class AppConstants {
  AppConstants._();

  /// Real content categories. The synthetic 'all' tab is prepended by
  /// screens that need it (see city_detail_screen.dart) and is never a
  /// stored category value.
  static const List<LayoverCategory> layoverCategories = [
    LayoverCategory(id: 'restaurants', label: 'Restaurants', icon: '🍽️'),
    LayoverCategory(id: 'coffee', label: 'Coffee', icon: '☕'),
    LayoverCategory(id: 'gyms', label: 'Gyms', icon: '💪'),
    LayoverCategory(id: 'prayer', label: 'Prayer', icon: '🕌'),
    LayoverCategory(id: 'transport', label: 'Transport', icon: '🚕'),
    LayoverCategory(id: 'shopping', label: 'Shopping', icon: '🛍️'),
    LayoverCategory(id: 'attractions', label: 'Attractions', icon: '📸'),
    LayoverCategory(id: 'essentials', label: 'Essentials', icon: '🏥'),
    LayoverCategory(id: 'crew_fav', label: 'Crew Favs', icon: '⭐'),
  ];

  /// Sort options rendered by filter_bar.dart. Order defines display order;
  /// the first entry is the default sort.
  static const List<String> sortOptions = [
    'Trending',
    'Top Rated',
    'Newest',
    'Most Saved',
  ];
}
