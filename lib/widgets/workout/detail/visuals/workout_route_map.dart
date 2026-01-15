import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../../../providers/workout_detail_provider.dart';
import '../../../../services/native_activation_service.dart';

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
    _initMap();
  }

  Future<void> _initMap() async {
    // 💡 네이티브 구글 맵 엔진 선제 활성화
    await NativeActivationService().activateGoogleMaps();
    await _loadRouteData();
  }

  Future<void> _loadRouteData() async {
    if (!mounted) return;
    final provider = Provider.of<WorkoutDetailProvider>(context, listen: false);
    
    // 1. 내부 세션에 경로 데이터가 있는지 먼저 확인
    if (provider.session?.routePoints != null && provider.session!.routePoints!.isNotEmpty) {
      if (mounted) {
        setState(() => _points = provider.session!.routePoints!.map((p) => LatLng(p.latitude, p.longitude)).toList());
      }
      return;
    }
    
    // 2. 없으면 외부(HealthKit) 연동 시도
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
    } finally { 
      if (mounted) setState(() => _isFetchingExternal = false); 
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isFetchingExternal) {
      return const SizedBox(height: 250, child: Center(child: CircularProgressIndicator()));
    }
    
    if (_points.isEmpty) return const SizedBox.shrink();
    
    return Card(
      clipBehavior: Clip.antiAlias, 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        height: 250, 
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: _points.first, zoom: 15),
          polylines: {
            Polyline(
              polylineId: const PolylineId('route'), 
              points: _points, 
              color: widget.themeColor, 
              width: 4
            )
          },
          onMapCreated: (c) => _fitBounds(c),
          myLocationEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        )
      ),
    );
  }

  void _fitBounds(GoogleMapController c) {
    if (_points.length < 2) return;
    
    // 💡 네이티브 맵 엔진이 완전히 준비될 시간을 줌 (안정성 확보)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      double minLat = _points.map((p) => p.latitude).reduce(min);
      double maxLat = _points.map((p) => p.latitude).reduce(max);
      double minLng = _points.map((p) => p.longitude).reduce(min);
      double maxLng = _points.map((p) => p.longitude).reduce(max);
      
      c.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng), 
            northeast: LatLng(maxLat, maxLng)
          ), 
          40
        )
      );
    });
  }
}