import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../../../providers/workout_detail_provider.dart';

class WorkoutRouteMap extends StatefulWidget {
  final Color themeColor;
  const WorkoutRouteMap({super.key, required this.themeColor});

  @override
  State<WorkoutRouteMap> createState() => _WorkoutRouteMapState();
}

class _WorkoutRouteMapState extends State<WorkoutRouteMap> {
  static const MethodChannel _healthKitChannel = MethodChannel('com.jared.pacelifter/healthkit');
  List<LatLng> _points = [];
  bool _isFetchingExternal = false;

  @override
  void initState() {
    super.initState();
    _loadRouteData();
  }

  Future<void> _loadRouteData() async {
    final provider = Provider.of<WorkoutDetailProvider>(context, listen: false);
    if (provider.session?.routePoints != null && provider.session!.routePoints!.isNotEmpty) {
      if (mounted) {
        setState(() => _points = provider.session!.routePoints!.map((p) => LatLng(p.latitude, p.longitude)).toList());
      }
      return;
    }
    await _fetchExternalRoute(provider.dataWrapper.uuid);
  }

  Future<void> _fetchExternalRoute(String uuid) async {
    if (!mounted) return;
    setState(() => _isFetchingExternal = true);
    try {
      final List<dynamic>? result = await _healthKitChannel.invokeMethod('getWorkoutRoute', {'uuid': uuid});
      if (result != null && result.isNotEmpty && mounted) {
        setState(() {
          _points = result.map((item) => LatLng(item['latitude'] as double, item['longitude'] as double)).toList();
          _isFetchingExternal = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Failed to fetch external route: $e');
    } finally { if (mounted) setState(() => _isFetchingExternal = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_isFetchingExternal) return const SizedBox(height: 250, child: Center(child: CircularProgressIndicator()));
    if (_points.isEmpty) return const SizedBox.shrink();
    return Card(
      clipBehavior: Clip.antiAlias, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(height: 250, child: GoogleMap(
        initialCameraPosition: CameraPosition(target: _points.first, zoom: 15),
        polylines: {Polyline(polylineId: const PolylineId('route'), points: _points, color: widget.themeColor, width: 4)},
        onMapCreated: (c) => _fitBounds(c),
      )),
    );
  }

  void _fitBounds(GoogleMapController c) {
    if (_points.length < 2) return;
    double minLat = _points.map((p) => p.latitude).reduce(min);
    double maxLat = _points.map((p) => p.latitude).reduce(max);
    double minLng = _points.map((p) => p.longitude).reduce(min);
    double maxLng = _points.map((p) => p.longitude).reduce(max);
    c.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)), 40));
  }
}
