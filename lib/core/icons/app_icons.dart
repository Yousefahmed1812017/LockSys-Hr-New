// GENERATED from the LockSys HR design system icon set (24x24 grid, 1.75 stroke).
// Style: navy outline + soft blue duotone fill. Do not add icons from other libraries.
// To add an icon: draw it on the same grid, then add an entry here AND in
// assets/design-system.html (sprite + IC list) so both stay identical.

/// Raw vector data for one icon. Render it with [AppIcon].
class AppIconData {
  const AppIconData(
    this.name,
    this.line, {
    this.accent,
    this.directional = false,
  });

  final String name;

  /// SVG elements drawn as the outline (stroke only).
  final String line;

  /// Optional SVG path drawn behind the outline as the soft duotone fill.
  final String? accent;

  /// Arrow-like icons are drawn for RTL and mirrored automatically in LTR.
  final bool directional;
}

abstract final class AppIcons {
  static const forward = AppIconData(
    'forward',
    r'<path d="M19 12H5M11 6l-6 6 6 6"/>',
    directional: true,
  );
  static const back = AppIconData(
    'back',
    r'<path d="M5 12h14M13 6l6 6-6 6"/>',
    directional: true,
  );
  static const chevron = AppIconData(
    'chevron',
    r'<path d="M15 6l-6 6 6 6"/>',
    directional: true,
  );
  static const plus = AppIconData('plus', r'<path d="M12 5v14M5 12h14"/>');
  static const check = AppIconData(
    'check',
    r'<path d="M5 12.5l4.5 4.5L19 7.5"/>',
  );
  static const logout = AppIconData(
    'logout',
    r'<path d="M9 4H5a1 1 0 00-1 1v14a1 1 0 001 1h4M16 8l4 4-4 4M20 12H9"/>',
  );
  static const home = AppIconData(
    'home',
    r'<path d="M3 11l9-8 9 8M5 10v10h14V10M10 20v-5h4v5"/>',
    accent: r'M5 10l7-6 7 6v10H5z',
  );
  static const users = AppIconData(
    'users',
    r'<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c0-3.6 2.9-6 6.5-6s6.5 2.4 6.5 6M16 4.5a3.5 3.5 0 010 7M18 14c2.2.6 3.5 2.4 3.5 6"/>',
    accent: r'M9 4.5a3.5 3.5 0 100 7 3.5 3.5 0 000-7z',
  );
  static const user = AppIconData(
    'user',
    r'<circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 3.6-7 8-7s8 3 8 7"/>',
    accent: r'M12 4a4 4 0 100 8 4 4 0 000-8z',
  );
  static const calendar = AppIconData(
    'calendar',
    r'<rect x="3.5" y="5" width="17" height="15" rx="2"/><path d="M3.5 10h17M8 3v4M16 3v4"/>',
    accent: r'M4.5 6h15v4h-15z',
  );
  static const clock = AppIconData(
    'clock',
    r'<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
    accent: r'M12 3.5a8.5 8.5 0 100 17 8.5 8.5 0 000-17z',
  );
  static const money = AppIconData(
    'money',
    r'<rect x="3" y="6" width="18" height="12" rx="2"/><circle cx="12" cy="12" r="2.5"/><path d="M6.5 12h.01M17.5 12h.01"/>',
    accent: r'M12 9.5a2.5 2.5 0 100 5 2.5 2.5 0 000-5z',
  );
  static const file = AppIconData(
    'file',
    r'<path d="M14 3H7a1 1 0 00-1 1v16a1 1 0 001 1h10a1 1 0 001-1V7zM14 3v4h4M9 12h6M9 16h6"/>',
    accent: r'M14 3v4h4z',
  );
  static const idCard = AppIconData(
    'idCard',
    r'<rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="9" cy="11" r="2"/><path d="M6 16c.5-1.5 1.7-2 3-2s2.5.5 3 2M14.5 10h3.5M14.5 14h3.5"/>',
    accent: r'M9 9a2 2 0 100 4 2 2 0 000-4z',
  );
  static const settings = AppIconData(
    'settings',
    r'<circle cx="12" cy="12" r="3"/><path d="M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3M5.3 5.3l2.1 2.1M16.6 16.6l2.1 2.1M18.7 5.3l-2.1 2.1M7.4 16.6l-2.1 2.1"/>',
    accent: r'M12 9a3 3 0 100 6 3 3 0 000-6z',
  );
  static const bell = AppIconData(
    'bell',
    r'<path d="M6 17V11a6 6 0 1112 0v6l1.5 2h-15zM10 21h4"/>',
    accent: r'M6 17v-6a6 6 0 0112 0v6z',
  );
  static const search = AppIconData(
    'search',
    r'<circle cx="11" cy="11" r="6.5"/><path d="M20 20l-4.5-4.5"/>',
    accent: r'M11 4.5a6.5 6.5 0 100 13 6.5 6.5 0 000-13z',
  );
  static const filter = AppIconData(
    'filter',
    r'<path d="M4 8h2.5M11.5 8H20M4 16h8.5M17.5 16H20"/><circle cx="9" cy="8" r="2.5"/><circle cx="15" cy="16" r="2.5"/>',
    accent:
        r'M9 5.5a2.5 2.5 0 100 5 2.5 2.5 0 000-5zM15 13.5a2.5 2.5 0 100 5 2.5 2.5 0 000-5z',
  );
  static const info = AppIconData(
    'info',
    r'<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8v.01"/>',
    accent: r'M12 3a9 9 0 100 18 9 9 0 000-18z',
  );
  static const star = AppIconData(
    'star',
    r'<path d="M12 3.5l2.6 5.3 5.9.9-4.2 4.1 1 5.8L12 16.9l-5.3 2.7 1-5.8L3.5 9.7l5.9-.9z"/>',
    accent:
        r'M12 3.5l2.6 5.3 5.9.9-4.2 4.1 1 5.8L12 16.9l-5.3 2.7 1-5.8L3.5 9.7l5.9-.9z',
  );
  static const warning = AppIconData(
    'warning',
    r'<path d="M12 3l10 18H2zM12 10v5M12 18v.01"/>',
    accent: r'M12 3l10 18H2z',
  );
  static const location = AppIconData(
    'location',
    r'<path d="M12 21s7-6 7-11a7 7 0 10-14 0c0 5 7 11 7 11z"/><circle cx="12" cy="10" r="2.5"/>',
    accent: r'M12 21s7-6 7-11a7 7 0 10-14 0c0 5 7 11 7 11z',
  );
  static const fingerprint = AppIconData(
    'fingerprint',
    r'<path d="M12 3a7 7 0 00-7 7v2M12 7a3 3 0 00-3 3v5c0 2 1 4 3 5M12 10v5c0 2 1 3 2 4M16 10a4 4 0 00-8 0M19 12v-2M16 14v2c0 2-.5 3.5-1.5 5"/>',
  );
  static const lock = AppIconData(
    'lock',
    r'<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 018 0v3"/>',
    accent: r'M6 12h12v7H6z',
  );
  static const shield = AppIconData(
    'shield',
    r'<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6zM8.5 12l2.5 2.5 4.5-5"/>',
    accent: r'M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z',
  );
  static const globe = AppIconData(
    'globe',
    r'<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18"/>',
    accent: r'M12 3a9 9 0 100 18 9 9 0 000-18z',
  );
  static const help = AppIconData(
    'help',
    r'<circle cx="12" cy="12" r="9"/><path d="M9.5 9.5a2.5 2.5 0 015 .5c0 1.5-2.5 2-2.5 3.5M12 17v.01"/>',
    accent: r'M12 3a9 9 0 100 18 9 9 0 000-18z',
  );
  static const edit = AppIconData(
    'edit',
    r'<path d="M4 20h4L19 9l-4-4L4 16z"/>',
    accent: r'M4 20h4L19 9l-4-4L4 16z',
  );
  static const download = AppIconData(
    'download',
    r'<path d="M12 4v11M7 11l5 5 5-5M5 20h14"/>',
    accent: r'M5 17h14v3H5z',
  );
  static const inbox = AppIconData(
    'inbox',
    r'<path d="M3 13l3-8h12l3 8v6H3zM3 13h5l1 3h6l1-3h5"/>',
    accent: r'M3 13h5l1 3h6l1-3h5v6H3z',
  );
  static const wifi = AppIconData(
    'wifi',
    r'<path d="M2 9a15 15 0 0120 0M5 13a10 10 0 0114 0M8.5 16.5a5 5 0 017 0M12 20v.01"/>',
    accent: r'M12 18.5a1.5 1.5 0 100 3 1.5 1.5 0 000-3z',
  );

  static const eye = AppIconData(
    'eye',
    r'<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
    accent: r'M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z',
  );
  static const eyeOff = AppIconData(
    'eyeOff',
    r'<path d="M3 3l18 18M10.6 5.1A10.6 10.6 0 0112 5c6.4 0 10 7 10 7a17 17 0 01-3.2 4M6.6 6.6C3.6 8.5 2 12 2 12s3.6 7 10 7c1.7 0 3.2-.4 4.5-1M9.9 9.9a3 3 0 004.2 4.2"/>',
  );

  static const building = AppIconData(
    'building',
    r'<path d="M5 21V4a1 1 0 011-1h8a1 1 0 011 1v17M15 9h3a1 1 0 011 1v11M3 21h18M9 7h2M9 11h2M9 15h2"/>',
    accent: r'M5 4a1 1 0 011-1h8a1 1 0 011 1v17H5z',
  );

  static const phone = AppIconData(
    'phone',
    r'<rect x="7" y="2.5" width="10" height="19" rx="2"/><path d="M11 18.5h2"/>',
    accent: r'M7.5 4.5h9v12h-9z',
  );
  static const mail = AppIconData(
    'mail',
    r'<rect x="3" y="5.5" width="18" height="13" rx="2"/><path d="M3.5 7.5l8.5 6 8.5-6"/>',
    accent: r'M4 7.5l8 5.7 8-5.7V17.5H4z',
  );
  static const message = AppIconData(
    'message',
    r'<path d="M4 5h16a1 1 0 011 1v10a1 1 0 01-1 1H10l-4.5 3.5V17H4a1 1 0 01-1-1V6a1 1 0 011-1z"/><path d="M8 10h8M8 13h5"/>',
    accent:
        r'M4 5h16a1 1 0 011 1v10a1 1 0 01-1 1H10l-4.5 3.5V17H4a1 1 0 01-1-1V6a1 1 0 011-1z',
  );
  static const chat = AppIconData(
    'chat',
    r'<path d="M12 3a9 9 0 00-7.8 13.5L3 21l4.6-1.2A9 9 0 1012 3z"/><path d="M9 9c.3 2.6 2.4 4.8 5.6 5.6l1.3-1.5-2-1-.9.9a4.7 4.7 0 01-2.3-2.3l.9-.9-1-2z"/>',
    accent: r'M12 3a9 9 0 00-7.8 13.5L3 21l4.6-1.2A9 9 0 1012 3z',
  );

  static const camera = AppIconData(
    'camera',
    r'<path d="M4 8a2 2 0 012-2h2l1.5-2h5L16 6h2a2 2 0 012 2v9a2 2 0 01-2 2H6a2 2 0 01-2-2z"/><circle cx="12" cy="12.5" r="3.5"/>',
    accent: r'M4 8a2 2 0 012-2h12a2 2 0 012 2v9a2 2 0 01-2 2H6a2 2 0 01-2-2z',
  );
  static const qr = AppIconData(
    'qr',
    r'<path d="M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h2.5v2.5H14zM18.5 14H20M14 18.5v1.5M17.5 17.5H20v2.5h-2.5z"/>',
    accent: r'M5 5h4v4H5zM15 5h4v4h-4zM5 15h4v4H5z',
  );

  static const List<AppIconData> all = [
    star,
    camera,
    qr,
    phone,
    mail,
    message,
    chat,
    building,
    eye,
    eyeOff,
    forward,
    back,
    chevron,
    plus,
    check,
    logout,
    home,
    users,
    user,
    calendar,
    clock,
    money,
    file,
    idCard,
    settings,
    bell,
    search,
    filter,
    info,
    warning,
    location,
    fingerprint,
    lock,
    shield,
    globe,
    help,
    edit,
    download,
    inbox,
    wifi,
  ];
}
