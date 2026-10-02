import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/icons/app_icons.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import 'attendance_api.dart';

/// Step one of the check-in: a Google map with the site's work area (the blue
/// zone) and where the phone is (the pin). Inside the zone the button is enabled
/// and the check goes on (to the face check, or straight to the check-in);
/// outside it says how far away the employee is and offers "Update my location".
///
/// The position is read from the phone ([locate]); inside / outside is worked out
/// from the site's work areas, the same rule the server applies (the server
/// decides). With [liveMap] off (tests, the design preview) a drawn map stands in.
class LocationMapView extends StatefulWidget {
  const LocationMapView({
    super.key,
    required this.site,
    required this.locate,
    required this.actionLabel,
    required this.onCheck,
    this.busy = false,
    this.liveMap = true,
  });

  final AttendanceSite site;

  /// Reads the phone's position. May throw (the flow shows the problem).
  final Future<LocationFix> Function() locate;

  /// The button when the employee is inside the area ("Continue", "Check in"...).
  final String actionLabel;

  /// Called with the position the employee confirmed.
  final void Function(LocationFix fix) onCheck;

  /// The check is being sent.
  final bool busy;

  /// A real Google map (needs the platform view and the API key).
  final bool liveMap;

  @override
  State<LocationMapView> createState() => _LocationMapViewState();
}

class _LocationMapViewState extends State<LocationMapView> {
  GoogleMapController? _map;
  LocationFix? _fix;
  bool _locating = true;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _find();
  }

  @override
  void dispose() {
    _disposed = true;
    final map = _map;
    _map = null;
    map?.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    setState(() => _locating = true);
    try {
      final fix = await widget.locate();
      if (!mounted) return;
      setState(() {
        _fix = fix;
        _locating = false;
      });
      _fit();
    } catch (_) {
      // The flow shows what is wrong with the phone.
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Every point that must be visible: the work areas and the phone.
  List<LatLng> _points() {
    final pts = <LatLng>[];
    for (final a in widget.site.areas) {
      final lat = a.latitude, lng = a.longitude;
      if (lat != null && lng != null) {
        pts.add(LatLng(lat, lng));
        final r = a.radiusMeters;
        if (r != null && (a.zoneType == 'CIRCLE' || a.zoneType == 'BOTH')) {
          final dLat = r / 111320;
          final dLng = r / (111320 * math.cos(lat * math.pi / 180));
          pts
            ..add(LatLng(lat + dLat, lng + dLng))
            ..add(LatLng(lat - dLat, lng - dLng));
        }
      }
      final b = a.bounds;
      if (b != null) {
        pts
          ..add(LatLng(b.north, b.east))
          ..add(LatLng(b.south, b.west));
      }
    }
    final f = _fix;
    if (f != null) pts.add(LatLng(f.latitude, f.longitude));
    return pts;
  }

  Future<void> _fit() async {
    final map = _map;
    if (_disposed || map == null) return;
    final pts = _points();
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      await map.animateCamera(CameraUpdate.newLatLngZoom(pts.first, 17));
      return;
    }
    final south = pts.map((p) => p.latitude).reduce(math.min);
    final north = pts.map((p) => p.latitude).reduce(math.max);
    final west = pts.map((p) => p.longitude).reduce(math.min);
    final east = pts.map((p) => p.longitude).reduce(math.max);
    if (_disposed) return;
    try {
      await map.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(south, west),
            northeast: LatLng(north, east),
          ),
          48,
        ),
      );
    } catch (_) {
      // The map is not laid out yet: the next call will do.
    }
  }

  Widget _googleMap(bool outside) {
    final pts = _points();
    final center = pts.isEmpty ? const LatLng(30.0444, 31.2357) : pts.first;
    final fix = _fix;
    final fill = AppColors.blue.withValues(alpha: .16);
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: center, zoom: 16),
      onMapCreated: (c) {
        _map = c;
        // The map needs a moment to know its size before it can fit.
        Future<void>.delayed(const Duration(milliseconds: 400), _fit);
      },
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      myLocationButtonEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      circles: {
        for (final a in widget.site.areas)
          if (a.latitude != null &&
              a.longitude != null &&
              a.radiusMeters != null &&
              (a.zoneType == 'CIRCLE' || a.zoneType == 'BOTH'))
            Circle(
              circleId: CircleId('c${a.id}'),
              center: LatLng(a.latitude!, a.longitude!),
              radius: a.radiusMeters!,
              fillColor: fill,
              strokeColor: AppColors.blue,
              strokeWidth: 3,
            ),
      },
      polygons: {
        for (final a in widget.site.areas)
          if (a.bounds != null &&
              (a.zoneType == 'RECT' || a.zoneType == 'BOTH'))
            Polygon(
              polygonId: PolygonId('p${a.id}'),
              points: [
                LatLng(a.bounds!.north, a.bounds!.west),
                LatLng(a.bounds!.north, a.bounds!.east),
                LatLng(a.bounds!.south, a.bounds!.east),
                LatLng(a.bounds!.south, a.bounds!.west),
              ],
              fillColor: fill,
              strokeColor: AppColors.blue,
              strokeWidth: 3,
            ),
      },
      markers: {
        for (final a in widget.site.areas)
          if (a.latitude != null && a.longitude != null)
            Marker(
              markerId: MarkerId('a${a.id}'),
              position: LatLng(a.latitude!, a.longitude!),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
              infoWindow: InfoWindow(
                title: a.name(Localizations.localeOf(context).languageCode),
              ),
            ),
        if (fix != null)
          Marker(
            markerId: const MarkerId('me'),
            position: LatLng(fix.latitude, fix.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              outside ? BitmapDescriptor.hueRed : BitmapDescriptor.hueGreen,
            ),
          ),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fix = _fix;
    final area = fix == null
        ? null
        : widget.site.areaAt(fix.latitude, fix.longitude);
    final outside = fix != null && area == null;
    final lang = Localizations.localeOf(context).languageCode;
    final areaName = (area ?? widget.site.areas.firstOrNull)?.name(lang) ?? '';
    final meters = fix == null
        ? null
        : widget.site.nearestMeters(fix.latitude, fix.longitude);
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              12,
              AppSpacing.gutter,
              12,
            ),
            child: ClipRRect(
              borderRadius: AppRadius.mdAll,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.line),
                  borderRadius: AppRadius.mdAll,
                ),
                child: widget.liveMap
                    ? _googleMap(outside)
                    : CustomPaint(
                        painter: _DrawnMapPainter(
                          located: fix != null,
                          outside: outside,
                        ),
                        child: const SizedBox.expand(),
                      ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              16,
            ),
            child: _StatusCard(
              locating: _locating,
              outside: outside,
              areaName: areaName,
              meters: meters?.round(),
              actionLabel: widget.actionLabel,
              busy: widget.busy,
              onCheck: fix == null ? null : () => widget.onCheck(fix),
              onRefresh: _find,
            ),
          ),
        ),
      ],
    );
  }
}

/// Where the employee stands, and the one button.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.locating,
    required this.outside,
    required this.areaName,
    required this.meters,
    required this.actionLabel,
    required this.busy,
    required this.onCheck,
    required this.onRefresh,
  });

  final bool locating;
  final bool outside;
  final String areaName;
  final int? meters;
  final String actionLabel;
  final bool busy;
  final VoidCallback? onCheck;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final title = locating
        ? l.mapLocating
        : (outside ? l.mapOutside : l.mapInside(areaName));
    final tone = locating
        ? AppTone.info
        : (outside ? AppTone.danger : AppTone.success);
    return AppCard(
      showMark: false,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppIconTile(AppIcons.location, tone: tone),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.h3.copyWith(fontSize: 16)),
                    if (!locating && outside && meters != null)
                      Text(l.mapDistance(meters!), style: AppText.small),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (locating || outside || onCheck == null)
            AppButton(
              label: l.mapRefresh,
              variant: AppButtonVariant.ghost,
              loading: locating,
              onPressed: locating ? null : onRefresh,
            )
          else
            AppButton(
              label: actionLabel,
              size: AppButtonSize.lg,
              leadingIcon: AppIcons.location,
              loading: busy,
              onPressed: onCheck,
            ),
        ],
      ),
    );
  }
}

/// Stand-in for the map in tests and the design preview: blocks, streets, the
/// zone and a dot.
class _DrawnMapPainter extends CustomPainter {
  const _DrawnMapPainter({required this.located, required this.outside});
  final bool located;
  final bool outside;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEAF0F6),
    );
    final block = Paint()..color = const Color(0xFFDCE6F0);
    const cols = 5, rows = 7;
    final cw = size.width / cols, ch = size.height / rows;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(c * cw + 8, r * ch + 8, cw - 16, ch - 16),
            const Radius.circular(6),
          ),
          block,
        );
      }
    }
    final street = Paint()
      ..color = Colors.white
      ..strokeWidth = 5;
    for (var c = 0; c <= cols; c++) {
      canvas.drawLine(Offset(c * cw, 0), Offset(c * cw, size.height), street);
    }
    for (var r = 0; r <= rows; r++) {
      canvas.drawLine(Offset(0, r * ch), Offset(size.width, r * ch), street);
    }
    final center = Offset(size.width * .5, size.height * .5);
    final radius = size.shortestSide * .27;
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = AppColors.blue.withValues(alpha: .16),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = AppColors.blue,
    );
    if (!located) return;
    final dot = outside
        ? Offset(size.width * .8, size.height * .82)
        : Offset(size.width * .54, size.height * .56);
    final color = outside ? AppColors.danger : AppColors.success;
    canvas.drawCircle(dot, 9, Paint()..color = Colors.white);
    canvas.drawCircle(dot, 6.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_DrawnMapPainter old) =>
      old.located != located || old.outside != outside;
}
