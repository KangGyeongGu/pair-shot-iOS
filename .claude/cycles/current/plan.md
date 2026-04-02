# Phase 4 재설계: ARKit → AVCaptureSession + LiDAR + Vision

## 핵심 변경
ARSession 기반 6DOF → AVCaptureSession + 하드웨어 센서 + Vision 프레임워크
줌/렌즈 전환 자유, ARKit 카메라 독점 해소

## 6DOF 매핑
- Pitch/Roll: Core Motion (IMU)
- Yaw: Core Location (heading)
- Y(높이): CMAltimeter (기압계)
- Z(거리): AVCaptureDepthDataOutput (LiDAR)
- X(좌우): Vision + LiDAR (tx * depth / fx)

## Work Items
W1 → W3∥W4∥W6∥W8∥W11 → W5 → W7 → W9 → W10
