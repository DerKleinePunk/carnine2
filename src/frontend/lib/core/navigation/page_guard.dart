/// What a page with unsaved work tells the dashboard (#207): while
/// [isActive], a tap in the side menu asks [confirmLeave] first, and the
/// trade fair mode does not return to the map. The car itself (the reverse
/// gear) does not ask.
class PageGuard {
  const PageGuard({required this.isActive, required this.confirmLeave});

  final bool Function() isActive;

  /// `true` lets the switch through; the page has given up its work then.
  final Future<bool> Function() confirmLeave;
}
