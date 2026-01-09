import 'package:flutter/material.dart';

/// Custom Triangle Performance Chart Painter
class TrianglePerformanceChartPainter extends CustomPainter {
  final double conditioningScore; // 위쪽 꼭지점
  final double enduranceScore;    // 좌측 하단
  final double strengthScore;     // 우측 하단
  final Color primaryColor;
  final Color gridColor;

  TrianglePerformanceChartPainter({
    required this.conditioningScore,
    required this.enduranceScore,
    required this.strengthScore,
    required this.primaryColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.85; // 85% of half width for padding

    // 정삼각형 꼭지점 계산 (위쪽이 컨디셔닝)
    final topVertex = Offset(center.dx, center.dy - radius); // 위쪽
    final bottomLeftVertex = Offset(
      center.dx - radius * 0.866, // cos(30°) ≈ 0.866
      center.dy + radius * 0.5,   // sin(30°) = 0.5
    );
    final bottomRightVertex = Offset(
      center.dx + radius * 0.866,
      center.dy + radius * 0.5,
    );

    // 5개 레벨의 동심 삼각형 그리기 (0, 25, 50, 75, 100)
    // 가장 작은 삼각형(0점) = scale 0.2
    // 가장 큰 삼각형(100점) = scale 1.0
    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 5; i++) {
      final scale = i / 5.0; // 0.2, 0.4, 0.6, 0.8, 1.0 (0점, 25점, 50점, 75점, 100점)
      _drawTriangle(
        canvas,
        center,
        topVertex,
        bottomLeftVertex,
        bottomRightVertex,
        scale,
        gridPaint,
      );
    }

    // 실제 점수 삼각형 그리기
    // 점수 → 스케일 변환: 0점 = 0.2, 100점 = 1.0
    const double minScale = 0.2;  // 가장 작은 삼각형 (0점)
    const double maxScale = 1.0;  // 가장 큰 삼각형 (100점)
    
    final dataScale1 = minScale + (conditioningScore / 100) * (maxScale - minScale); // 위쪽
    final dataScale2 = minScale + (enduranceScore / 100) * (maxScale - minScale);    // 좌측 하단
    final dataScale3 = minScale + (strengthScore / 100) * (maxScale - minScale);     // 우측 하단

    final dataPoint1 = _getScaledPoint(center, topVertex, dataScale1);
    final dataPoint2 = _getScaledPoint(center, bottomLeftVertex, dataScale2);
    final dataPoint3 = _getScaledPoint(center, bottomRightVertex, dataScale3);

    // 데이터 영역 채우기
    final fillPaint = Paint()
      ..color = primaryColor.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final dataPath = Path()
      ..moveTo(dataPoint1.dx, dataPoint1.dy)
      ..lineTo(dataPoint2.dx, dataPoint2.dy)
      ..lineTo(dataPoint3.dx, dataPoint3.dy)
      ..close();

    canvas.drawPath(dataPath, fillPaint);

    // 데이터 테두리 그리기
    final borderPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawPath(dataPath, borderPaint);

    // 데이터 포인트 그리기
    final pointPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(dataPoint1, 4, pointPaint);
    canvas.drawCircle(dataPoint2, 4, pointPaint);
    canvas.drawCircle(dataPoint3, 4, pointPaint);

    // 레이블 그리기
    final textStyle = TextStyle(
      color: gridColor.withOpacity(0.8),
      fontSize: 11,
      fontWeight: FontWeight.w500,
    );

    // 컨디셔닝 (위쪽) - 중앙 정렬
    _drawLabel(canvas, '컨디셔닝', Offset(center.dx, topVertex.dy - 18), textStyle);
    
    // 지구력 (좌측 하단) - 왼쪽 정렬, 캔버스 내부에 위치하도록 조정
    final enduranceLabelX = bottomLeftVertex.dx + 5;  // 꼭지점에서 약간 오른쪽
    _drawLabel(canvas, '지구력', Offset(enduranceLabelX, bottomLeftVertex.dy + 18), textStyle);
    
    // 근력 (우측 하단) - 오른쪽 정렬, 캔버스 내부에 위치하도록 조정
    final strengthLabelX = bottomRightVertex.dx - 5;  // 꼭지점에서 약간 왼쪽
    _drawLabel(canvas, '근력', Offset(strengthLabelX, bottomRightVertex.dy + 18), textStyle);
  }

  void _drawTriangle(
    Canvas canvas,
    Offset center,
    Offset top,
    Offset bottomLeft,
    Offset bottomRight,
    double scale,
    Paint paint,
  ) {
    final scaledTop = _getScaledPoint(center, top, scale);
    final scaledBottomLeft = _getScaledPoint(center, bottomLeft, scale);
    final scaledBottomRight = _getScaledPoint(center, bottomRight, scale);

    final path = Path()
      ..moveTo(scaledTop.dx, scaledTop.dy)
      ..lineTo(scaledBottomLeft.dx, scaledBottomLeft.dy)
      ..lineTo(scaledBottomRight.dx, scaledBottomRight.dy)
      ..close();

    canvas.drawPath(path, paint);
  }

  Offset _getScaledPoint(Offset center, Offset vertex, double scale) {
    return Offset(
      center.dx + (vertex.dx - center.dx) * scale,
      center.dy + (vertex.dy - center.dy) * scale,
    );
  }

  void _drawLabel(Canvas canvas, String text, Offset position, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(position.dx - textPainter.width / 2, position.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(TrianglePerformanceChartPainter oldDelegate) {
    return oldDelegate.conditioningScore != conditioningScore ||
        oldDelegate.enduranceScore != enduranceScore ||
        oldDelegate.strengthScore != strengthScore;
  }
}
