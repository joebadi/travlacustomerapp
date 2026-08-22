import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/journeys/data/journey_repository.dart';
import 'package:travla_customer_app/features/journeys/domain/journey_models.dart';

class JourneysScreen extends ConsumerStatefulWidget {
  const JourneysScreen({super.key});

  @override
  ConsumerState<JourneysScreen> createState() => _JourneysScreenState();
}

class _JourneysScreenState extends ConsumerState<JourneysScreen>
    with TickerProviderStateMixin {
  static const _nigeria = LatLng(9.0820, 8.6753);
  final _mapController = MapController();
  late final AnimationController _entryController;
  late final AnimationController _pulseController;
  late final Animation<double> _overlayFade;
  late final Animation<Offset> _actionsSlide;

  LatLng? _currentPosition;
  bool _locating = false;
  bool _showJourneys = false;
  bool _openedSavedJourneys = false;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();
    _overlayFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0, .72, curve: Curves.easeOutCubic),
    );
    _actionsSlide = Tween<Offset>(begin: const Offset(.55, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entryController,
            curve: const Interval(.16, 1, curve: Curves.easeOutBack),
          ),
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreLocationIfAllowed();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _restoreLocationIfAllowed() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        await _resolveLocation(announceErrors: false);
      }
    } catch (_) {
      // The map remains useful when a platform location service is unavailable.
    }
  }

  Future<void> _locateUser() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _message('Turn on location services to find yourself on the map.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _message(
          'Location access is blocked. Enable it for Travla in your device settings.',
        );
        return;
      }
      if (permission == LocationPermission.denied) {
        _message('Location access is needed to place you on the map.');
        return;
      }
      await _resolveLocation(announceErrors: true);
    } catch (_) {
      _message('Travla could not get your location. Please try again.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _resolveLocation({required bool announceErrors}) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() => _currentPosition = point);
      _mapController.move(point, 16.2);
    } catch (_) {
      if (announceErrors) {
        _message('Your current position could not be resolved. Try again.');
      }
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _openSavedJourneysWhenReady(List<Journey> journeys) {
    if (_openedSavedJourneys || journeys.isEmpty) return;
    _openedSavedJourneys = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _showJourneys = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final journeys = ref.watch(journeysProvider);
    final journeyList = journeys.asData?.value ?? const <Journey>[];
    _openSavedJourneysWhenReady(journeyList);

    return Scaffold(
      backgroundColor: AppColors.forest950,
      body: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _nigeria,
              initialZoom: 5.7,
              minZoom: 3.5,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (_, _) {
                if (_showJourneys) setState(() => _showJourneys = false);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'ng.com.travla.customer',
                maxNativeZoom: 19,
              ),
              if (journeyList.any((journey) => journey.trail.length > 1))
                PolylineLayer(
                  polylines: journeyList
                      .where((journey) => journey.trail.length > 1)
                      .take(8)
                      .map(
                        (journey) => Polyline(
                          points: journey.trail
                              .map((point) => LatLng(point.lat, point.lng))
                              .toList(growable: false),
                          strokeWidth: 4,
                          color: AppColors.forest600.withValues(alpha: .62),
                          borderStrokeWidth: 1.5,
                          borderColor: AppColors.white.withValues(alpha: .78),
                        ),
                      )
                      .toList(growable: false),
                ),
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition!,
                      width: 72,
                      height: 72,
                      child: _CurrentLocationMarker(
                        animation: _pulseController,
                      ),
                    ),
                  ],
                ),
              const RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                showFlutterMapAttribution: false,
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          const IgnorePointer(child: _MapAtmosphere()),
          Positioned(
            left: 14,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: FadeTransition(
                opacity: _overlayFade,
                child: const _MapIdentity(),
              ),
            ),
          ),
          Positioned(
            right: 14,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: FadeTransition(
                opacity: _overlayFade,
                child: _LocateButton(locating: _locating, onTap: _locateUser),
              ),
            ),
          ),
          Positioned(
            right: 14,
            bottom: 18,
            child: SlideTransition(
              position: _actionsSlide,
              child: FadeTransition(
                opacity: _overlayFade,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _MapActionButton(
                      label: 'My Journeys',
                      icon: Icons.route_rounded,
                      active: _showJourneys,
                      onTap: () =>
                          setState(() => _showJourneys = !_showJourneys),
                    ),
                    const SizedBox(height: 10),
                    _MapActionButton(
                      label: 'Start a Journey',
                      icon: Icons.navigation_rounded,
                      emphasize: true,
                      onTap: () => context.push('/journeys/record'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 150,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 430),
              reverseDuration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(0, .18),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: _showJourneys
                  ? _SavedJourneysOverlay(
                      key: const ValueKey('saved-journeys'),
                      journeys: journeys,
                      maxHeight: math.min(
                        350,
                        MediaQuery.sizeOf(context).height * .43,
                      ),
                      onClose: () => setState(() => _showJourneys = false),
                      onRetry: () => ref.invalidate(journeysProvider),
                      onStart: () => context.push('/journeys/record'),
                      onOpen: (journey) =>
                          context.push('/journeys/${journey.id}'),
                    )
                  : const SizedBox.shrink(key: ValueKey('map-only')),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapAtmosphere extends StatelessWidget {
  const _MapAtmosphere();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, .18, .67, 1],
          colors: [
            AppColors.forest950.withValues(alpha: .34),
            Colors.transparent,
            Colors.transparent,
            AppColors.forest950.withValues(alpha: .28),
          ],
        ),
      ),
    );
  }
}

class _MapIdentity extends StatelessWidget {
  const _MapIdentity();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
      decoration: BoxDecoration(
        color: const Color(0xED050806),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.forest600, width: 1.15),
        boxShadow: const [
          BoxShadow(
            color: Color(0x42000000),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.forest600, AppColors.forest900],
              ),
            ),
            child: Image.asset(
              'assets/brand/travla-mark-white.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 9),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TRAVLA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  height: 1,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'LIVE MAP',
                style: TextStyle(
                  color: Color(0xFF6DE4B0),
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.25,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocateButton extends StatelessWidget {
  const _LocateButton({required this.locating, required this.onTap});
  final bool locating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Find my location',
      child: Material(
        color: const Color(0xF2050806),
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.forest600, width: 1.35),
        ),
        elevation: 8,
        shadowColor: Colors.black54,
        child: InkWell(
          onTap: locating ? null : onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 50,
            height: 50,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: locating
                    ? const SizedBox(
                        key: ValueKey('locating'),
                        width: 21,
                        height: 21,
                        child: CircularProgressIndicator(
                          color: Color(0xFF6DE4B0),
                          strokeWidth: 2.2,
                        ),
                      )
                    : const Icon(
                        Icons.my_location_rounded,
                        key: ValueKey('locate'),
                        color: Color(0xFF6DE4B0),
                        size: 23,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapActionButton extends StatefulWidget {
  const _MapActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.active = false,
    this.emphasize = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final bool emphasize;

  @override
  State<_MapActionButton> createState() => _MapActionButtonState();
}

class _MapActionButtonState extends State<_MapActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final border = widget.active
        ? const Color(0xFF6DE4B0)
        : AppColors.forest600;
    return AnimatedScale(
      scale: _pressed ? .965 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: const Color(0xF5050806),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: border, width: widget.active ? 1.8 : 1.2),
          boxShadow: [
            const BoxShadow(
              color: Color(0x50000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
            if (widget.active || widget.emphasize)
              BoxShadow(
                color: AppColors.forest600.withValues(alpha: .22),
                blurRadius: 16,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 17, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.emphasize
                          ? AppColors.orange
                          : widget.active
                          ? AppColors.forest600
                          : AppColors.forest900,
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final value = Curves.easeOut.transform(animation.value);
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: .35 + value * .65,
              child: Opacity(
                opacity: 1 - value,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.forest600.withValues(alpha: .3),
                    border: Border.all(
                      color: const Color(0xFF6DE4B0),
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.forest700,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(color: Color(0x52021B13), blurRadius: 10),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SavedJourneysOverlay extends StatelessWidget {
  const _SavedJourneysOverlay({
    required this.journeys,
    required this.maxHeight,
    required this.onClose,
    required this.onRetry,
    required this.onStart,
    required this.onOpen,
    super.key,
  });
  final AsyncValue<List<Journey>> journeys;
  final double maxHeight;
  final VoidCallback onClose;
  final VoidCallback onRetry;
  final VoidCallback onStart;
  final ValueChanged<Journey> onOpen;

  @override
  Widget build(BuildContext context) {
    final list = journeys.asData?.value ?? const <Journey>[];
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xF805100C), Color(0xF5072F23)],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.forest600, width: 1.15),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 32,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.forest600.withValues(alpha: .3),
                        border: Border.all(
                          color: AppColors.forest600.withValues(alpha: .8),
                        ),
                      ),
                      child: const Icon(
                        Icons.route_rounded,
                        color: Color(0xFF6DE4B0),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'My journeys',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            list.isEmpty
                                ? 'Saved routes appear here'
                                : '${list.length} saved ${list.length == 1 ? 'journey' : 'journeys'}',
                            style: const TextStyle(
                              color: Color(0xFF9BB7AD),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      tooltip: 'Close',
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                Flexible(
                  child: journeys.when(
                    loading: () => const _OverlayLoading(),
                    error: (error, _) => _OverlayError(
                      message: error is ApiFailure
                          ? error.message
                          : 'Your journeys could not be loaded.',
                      onRetry: onRetry,
                    ),
                    data: (items) => items.isEmpty
                        ? _OverlayEmpty(onStart: onStart)
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            physics: const BouncingScrollPhysics(),
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) =>
                                _JourneyOverlayTile(
                                  journey: items[index],
                                  onTap: () => onOpen(items[index]),
                                ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JourneyOverlayTile extends StatelessWidget {
  const _JourneyOverlayTile({required this.journey, required this.onTap});
  final Journey journey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .075),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: Colors.white.withValues(alpha: .1)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.near_me_rounded,
                  color: AppColors.orange,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      journey.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 9,
                      runSpacing: 4,
                      children: [
                        _miniStat(
                          Icons.straighten_rounded,
                          '${journey.distanceKm.toStringAsFixed(1)} km',
                        ),
                        _miniStat(Icons.timer_outlined, journey.durationLabel),
                        if (_formatDate(
                          journey.recordedAt ?? journey.createdAt,
                        ).isNotEmpty)
                          _miniStat(
                            Icons.calendar_today_outlined,
                            _formatDate(
                              journey.recordedAt ?? journey.createdAt,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF6DE4B0),
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: const Color(0xFF8EAAA0)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFFC6D7D0),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _OverlayLoading extends StatelessWidget {
  const _OverlayLoading();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 92,
      child: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF6DE4B0),
          strokeWidth: 2.2,
        ),
      ),
    );
  }
}

class _OverlayError extends StatelessWidget {
  const _OverlayError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFC6D7D0), fontSize: 12),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _OverlayEmpty extends StatelessWidget {
  const _OverlayEmpty({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 4),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Start a journey and Travla will keep its route and useful details here.',
              style: TextStyle(
                color: Color(0xFFC6D7D0),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(onPressed: onStart, child: const Text('Start now')),
        ],
      ),
    );
  }
}

String _formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final value = DateTime.tryParse(iso);
  if (value == null) return '';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${value.day} ${months[value.month - 1]}';
}
