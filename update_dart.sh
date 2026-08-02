#!/bin/bash

# Update native_camera_engine.dart
sed -i 's/runHevcMain10RampTest/runTenBitDiagnosticRecording/g' lib/src/camera/native_camera_engine.dart

# Update camera_ui_controller.dart
sed -i 's/runHevcMain10RampTest/runTenBitDiagnosticRecording/g' lib/src/model/camera_ui_controller.dart
sed -i 's/main10RampBusy/tenBitRecordingBusy/g' lib/src/model/camera_ui_controller.dart
sed -i 's/main10RampResult/tenBitRecordingResult/g' lib/src/model/camera_ui_controller.dart

# Update settings_screen.dart
sed -i 's/runHevcMain10RampTest/runTenBitDiagnosticRecording/g' lib/src/screens/settings_screen.dart
sed -i 's/main10RampBusy/tenBitRecordingBusy/g' lib/src/screens/settings_screen.dart
sed -i 's/main10RampResult/tenBitRecordingResult/g' lib/src/screens/settings_screen.dart
sed -i 's/HEVC Main10 Ramp Test/Real P010 Main10 Diagnostic/g' lib/src/screens/settings_screen.dart
