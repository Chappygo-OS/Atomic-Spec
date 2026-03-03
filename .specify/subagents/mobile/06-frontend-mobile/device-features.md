---
name: Mobile Device Features Access
platform: mobile
description: Camera, gallery, location, sensors, and other native device feature integration for mobile applications
model: opus
category: mobile/frontend
---

# Mobile Device Features Access

## Purpose

Implement secure, user-friendly access to native device capabilities including camera, photo library, location services, biometrics, contacts, and various sensors. The device layer should handle permission requests gracefully and provide fallbacks when features are unavailable.

## Permission Handling Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│                   Permission Flow                                │
├─────────────────────────────────────────────────────────────────┤
│  1. Check current permission status                             │
│  2. If not determined, explain why permission is needed         │
│  3. Request permission from system                              │
│  4. Handle granted/denied states                                │
│  5. Provide settings deep link if permanently denied            │
└─────────────────────────────────────────────────────────────────┘
```

## iOS Device Features

### Permission Manager

```swift
// PermissionManager.swift
import AVFoundation
import Photos
import CoreLocation
import LocalAuthentication
import Contacts

@Observable
final class PermissionManager {
    static let shared = PermissionManager()

    var cameraStatus: AVAuthorizationStatus = .notDetermined
    var photoLibraryStatus: PHAuthorizationStatus = .notDetermined
    var locationStatus: CLAuthorizationStatus = .notDetermined
    var contactsStatus: CNAuthorizationStatus = .notDetermined

    private let locationManager = CLLocationManager()

    func checkAllPermissions() {
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        photoLibraryStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        locationStatus = locationManager.authorizationStatus
        contactsStatus = CNContactStore.authorizationStatus(for: .contacts)
    }

    // MARK: - Camera

    func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Photo Library

    func requestPhotoLibraryPermission() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            return newStatus == .authorized || newStatus == .limited
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Location

    func requestLocationPermission(always: Bool = false) async -> Bool {
        return await withCheckedContinuation { continuation in
            let delegate = LocationPermissionDelegate { status in
                continuation.resume(returning: status == .authorizedAlways ||
                                              status == .authorizedWhenInUse)
            }

            if always {
                locationManager.requestAlwaysAuthorization()
            } else {
                locationManager.requestWhenInUseAuthorization()
            }
        }
    }

    // MARK: - Contacts

    func requestContactsPermission() async -> Bool {
        let store = CNContactStore()

        do {
            return try await store.requestAccess(for: .contacts)
        } catch {
            return false
        }
    }

    // MARK: - Biometrics

    func canUseBiometrics() -> (available: Bool, type: LABiometryType) {
        let context = LAContext()
        var error: NSError?
        let available = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return (available, context.biometryType)
    }

    func authenticateWithBiometrics(reason: String) async throws -> Bool {
        let context = LAContext()
        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )
    }

    // MARK: - Settings

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
```

### Camera Service

```swift
// CameraService.swift
import AVFoundation
import UIKit

@Observable
final class CameraService: NSObject {
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    private(set) var capturedImage: UIImage?
    private(set) var capturedVideoURL: URL?
    private(set) var isCapturing: Bool = false
    private(set) var isRecording: Bool = false
    private(set) var currentCamera: AVCaptureDevice.Position = .back
    private(set) var flashMode: AVCaptureDevice.FlashMode = .auto

    private var photoContinuation: CheckedContinuation<UIImage, Error>?
    private var videoContinuation: CheckedContinuation<URL, Error>?

    enum CameraError: Error {
        case notAuthorized
        case configurationFailed
        case captureError
    }

    func setupCamera(for view: UIView) async throws {
        guard await PermissionManager.shared.requestCameraPermission() else {
            throw CameraError.notAuthorized
        }

        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo

        guard let session = captureSession,
              let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCamera),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            throw CameraError.configurationFailed
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        // Photo output
        photoOutput = AVCapturePhotoOutput()
        if let photoOutput, session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        // Video output
        videoOutput = AVCaptureMovieFileOutput()
        if let videoOutput, session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        // Preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.frame = view.bounds

        await MainActor.run {
            if let previewLayer {
                view.layer.insertSublayer(previewLayer, at: 0)
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    func capturePhoto() async throws -> UIImage {
        guard let photoOutput else {
            throw CameraError.configurationFailed
        }

        isCapturing = true

        return try await withCheckedThrowingContinuation { continuation in
            self.photoContinuation = continuation

            let settings = AVCapturePhotoSettings()
            settings.flashMode = flashMode

            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func startRecording() throws {
        guard let videoOutput, !isRecording else { return }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        videoOutput.startRecording(to: tempURL, recordingDelegate: self)
        isRecording = true
    }

    func stopRecording() async throws -> URL {
        guard let videoOutput, isRecording else {
            throw CameraError.captureError
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.videoContinuation = continuation
            videoOutput.stopRecording()
        }
    }

    func switchCamera() {
        currentCamera = currentCamera == .back ? .front : .back

        guard let session = captureSession,
              let currentInput = session.inputs.first as? AVCaptureDeviceInput else {
            return
        }

        session.beginConfiguration()
        session.removeInput(currentInput)

        if let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCamera),
           let newInput = try? AVCaptureDeviceInput(device: newCamera),
           session.canAddInput(newInput) {
            session.addInput(newInput)
        }

        session.commitConfiguration()
    }

    func toggleFlash() {
        switch flashMode {
        case .off:
            flashMode = .on
        case .on:
            flashMode = .auto
        case .auto:
            flashMode = .off
        @unknown default:
            flashMode = .auto
        }
    }

    func cleanup() {
        captureSession?.stopRunning()
        previewLayer?.removeFromSuperlayer()
        captureSession = nil
        previewLayer = nil
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        isCapturing = false

        if let error {
            photoContinuation?.resume(throwing: error)
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            photoContinuation?.resume(throwing: CameraError.captureError)
            return
        }

        capturedImage = image
        photoContinuation?.resume(returning: image)
    }
}

extension CameraService: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        isRecording = false

        if let error {
            videoContinuation?.resume(throwing: error)
            return
        }

        capturedVideoURL = outputFileURL
        videoContinuation?.resume(returning: outputFileURL)
    }
}
```

### Location Service

```swift
// LocationService.swift
import CoreLocation

@Observable
final class LocationService: NSObject {
    static let shared = LocationService()

    private let locationManager = CLLocationManager()

    private(set) var currentLocation: CLLocation?
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var isUpdating: Bool = false

    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestPermission(always: Bool = false) async -> CLAuthorizationStatus {
        if authorizationStatus != .notDetermined {
            return authorizationStatus
        }

        return await withCheckedContinuation { continuation in
            self.authContinuation = continuation

            if always {
                locationManager.requestAlwaysAuthorization()
            } else {
                locationManager.requestWhenInUseAuthorization()
            }
        }
    }

    func getCurrentLocation() async throws -> CLLocation {
        guard authorizationStatus == .authorizedWhenInUse ||
              authorizationStatus == .authorizedAlways else {
            throw LocationError.notAuthorized
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    func startUpdatingLocation() {
        guard authorizationStatus == .authorizedWhenInUse ||
              authorizationStatus == .authorizedAlways else { return }

        isUpdating = true
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        isUpdating = false
        locationManager.stopUpdatingLocation()
    }

    func geocode(address: String) async throws -> CLPlacemark? {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.geocodeAddressString(address)
        return placemarks.first
    }

    func reverseGeocode(location: CLLocation) async throws -> CLPlacemark? {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        return placemarks.first
    }

    enum LocationError: Error {
        case notAuthorized
        case locationUnavailable
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        authContinuation?.resume(returning: authorizationStatus)
        authContinuation = nil
    }
}
```

## Android Device Features

### Permission Handler

```kotlin
// PermissionHandler.kt
@Composable
fun rememberPermissionState(
    permission: String
): PermissionState {
    return rememberPermissionState(permission = permission)
}

@Composable
fun rememberMultiplePermissionsState(
    permissions: List<String>
): MultiplePermissionsState {
    return rememberMultiplePermissionsState(permissions = permissions)
}

// CameraPermissionHandler.kt
@Composable
fun CameraPermissionHandler(
    onPermissionGranted: @Composable () -> Unit,
    onPermissionDenied: @Composable () -> Unit
) {
    val cameraPermissionState = rememberPermissionState(Manifest.permission.CAMERA)

    when {
        cameraPermissionState.status.isGranted -> {
            onPermissionGranted()
        }
        cameraPermissionState.status.shouldShowRationale -> {
            PermissionRationale(
                title = "Camera Permission Required",
                message = "This feature requires camera access to capture photos.",
                onRequestPermission = { cameraPermissionState.launchPermissionRequest() }
            )
        }
        else -> {
            onPermissionDenied()
        }
    }
}

@Composable
fun PermissionRationale(
    title: String,
    message: String,
    onRequestPermission: () -> Unit,
    onOpenSettings: () -> Unit = {}
) {
    val context = LocalContext.current

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = message,
            style = MaterialTheme.typography.bodyMedium,
            textAlign = TextAlign.Center
        )
        Spacer(modifier = Modifier.height(16.dp))
        Button(onClick = onRequestPermission) {
            Text("Grant Permission")
        }
        TextButton(onClick = {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.fromParts("package", context.packageName, null)
            }
            context.startActivity(intent)
        }) {
            Text("Open Settings")
        }
    }
}
```

### Camera Service

```kotlin
// CameraService.kt
@Singleton
class CameraService @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private var imageCapture: ImageCapture? = null
    private var videoCapture: VideoCapture<Recorder>? = null
    private var camera: Camera? = null
    private var recording: Recording? = null

    private val _isRecording = MutableStateFlow(false)
    val isRecording: StateFlow<Boolean> = _isRecording.asStateFlow()

    private val _flashMode = MutableStateFlow(ImageCapture.FLASH_MODE_AUTO)
    val flashMode: StateFlow<Int> = _flashMode.asStateFlow()

    private val _lensFacing = MutableStateFlow(CameraSelector.LENS_FACING_BACK)
    val lensFacing: StateFlow<Int> = _lensFacing.asStateFlow()

    suspend fun bindCamera(
        lifecycleOwner: LifecycleOwner,
        previewView: PreviewView
    ) {
        val cameraProvider = ProcessCameraProvider.getInstance(context).await()

        val preview = Preview.Builder().build().also {
            it.setSurfaceProvider(previewView.surfaceProvider)
        }

        imageCapture = ImageCapture.Builder()
            .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
            .setFlashMode(_flashMode.value)
            .build()

        val recorder = Recorder.Builder()
            .setQualitySelector(QualitySelector.from(Quality.HIGHEST))
            .build()
        videoCapture = VideoCapture.withOutput(recorder)

        val cameraSelector = CameraSelector.Builder()
            .requireLensFacing(_lensFacing.value)
            .build()

        try {
            cameraProvider.unbindAll()
            camera = cameraProvider.bindToLifecycle(
                lifecycleOwner,
                cameraSelector,
                preview,
                imageCapture,
                videoCapture
            )
        } catch (e: Exception) {
            Log.e("CameraService", "Camera binding failed", e)
        }
    }

    suspend fun takePhoto(): File? = withContext(Dispatchers.IO) {
        val imageCapture = imageCapture ?: return@withContext null

        val photoFile = File(
            context.cacheDir,
            "photo_${System.currentTimeMillis()}.jpg"
        )

        val outputOptions = ImageCapture.OutputFileOptions.Builder(photoFile).build()

        return@withContext suspendCancellableCoroutine { continuation ->
            imageCapture.takePicture(
                outputOptions,
                ContextCompat.getMainExecutor(context),
                object : ImageCapture.OnImageSavedCallback {
                    override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                        continuation.resume(photoFile) {}
                    }

                    override fun onError(exception: ImageCaptureException) {
                        continuation.resume(null) {}
                    }
                }
            )
        }
    }

    @SuppressLint("MissingPermission")
    fun startRecording(onVideoRecorded: (Uri) -> Unit) {
        val videoCapture = videoCapture ?: return

        val videoFile = File(
            context.cacheDir,
            "video_${System.currentTimeMillis()}.mp4"
        )

        val outputOptions = FileOutputOptions.Builder(videoFile).build()

        recording = videoCapture.output
            .prepareRecording(context, outputOptions)
            .withAudioEnabled()
            .start(ContextCompat.getMainExecutor(context)) { event ->
                when (event) {
                    is VideoRecordEvent.Start -> {
                        _isRecording.value = true
                    }
                    is VideoRecordEvent.Finalize -> {
                        _isRecording.value = false
                        if (!event.hasError()) {
                            onVideoRecorded(event.outputResults.outputUri)
                        }
                    }
                }
            }
    }

    fun stopRecording() {
        recording?.stop()
        recording = null
    }

    fun toggleCamera() {
        _lensFacing.value = if (_lensFacing.value == CameraSelector.LENS_FACING_BACK) {
            CameraSelector.LENS_FACING_FRONT
        } else {
            CameraSelector.LENS_FACING_BACK
        }
    }

    fun toggleFlash() {
        _flashMode.value = when (_flashMode.value) {
            ImageCapture.FLASH_MODE_OFF -> ImageCapture.FLASH_MODE_ON
            ImageCapture.FLASH_MODE_ON -> ImageCapture.FLASH_MODE_AUTO
            else -> ImageCapture.FLASH_MODE_OFF
        }
        imageCapture?.flashMode = _flashMode.value
    }

    fun setZoom(zoomRatio: Float) {
        camera?.cameraControl?.setZoomRatio(zoomRatio)
    }

    fun enableTorch(enabled: Boolean) {
        camera?.cameraControl?.enableTorch(enabled)
    }
}
```

### Location Service

```kotlin
// LocationService.kt
@Singleton
class LocationService @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val fusedLocationClient = LocationServices.getFusedLocationProviderClient(context)
    private val geocoder = Geocoder(context, Locale.getDefault())

    private val _currentLocation = MutableStateFlow<Location?>(null)
    val currentLocation: StateFlow<Location?> = _currentLocation.asStateFlow()

    private val _isUpdating = MutableStateFlow(false)
    val isUpdating: StateFlow<Boolean> = _isUpdating.asStateFlow()

    private var locationCallback: LocationCallback? = null

    @SuppressLint("MissingPermission")
    suspend fun getCurrentLocation(): Location? = withContext(Dispatchers.IO) {
        suspendCancellableCoroutine { continuation ->
            fusedLocationClient.getCurrentLocation(
                Priority.PRIORITY_HIGH_ACCURACY,
                CancellationTokenSource().token
            ).addOnSuccessListener { location ->
                _currentLocation.value = location
                continuation.resume(location) {}
            }.addOnFailureListener { exception ->
                continuation.resume(null) {}
            }
        }
    }

    @SuppressLint("MissingPermission")
    fun startLocationUpdates(
        intervalMs: Long = 10000,
        fastestIntervalMs: Long = 5000
    ) {
        val locationRequest = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            intervalMs
        )
            .setMinUpdateIntervalMillis(fastestIntervalMs)
            .build()

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                result.lastLocation?.let { location ->
                    _currentLocation.value = location
                }
            }
        }

        _isUpdating.value = true
        fusedLocationClient.requestLocationUpdates(
            locationRequest,
            locationCallback!!,
            Looper.getMainLooper()
        )
    }

    fun stopLocationUpdates() {
        locationCallback?.let {
            fusedLocationClient.removeLocationUpdates(it)
        }
        locationCallback = null
        _isUpdating.value = false
    }

    suspend fun geocodeAddress(address: String): Address? = withContext(Dispatchers.IO) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                suspendCancellableCoroutine { continuation ->
                    geocoder.getFromLocationName(address, 1) { addresses ->
                        continuation.resume(addresses.firstOrNull()) {}
                    }
                }
            } else {
                @Suppress("DEPRECATION")
                geocoder.getFromLocationName(address, 1)?.firstOrNull()
            }
        } catch (e: Exception) {
            null
        }
    }

    suspend fun reverseGeocode(latitude: Double, longitude: Double): Address? =
        withContext(Dispatchers.IO) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    suspendCancellableCoroutine { continuation ->
                        geocoder.getFromLocation(latitude, longitude, 1) { addresses ->
                            continuation.resume(addresses.firstOrNull()) {}
                        }
                    }
                } else {
                    @Suppress("DEPRECATION")
                    geocoder.getFromLocation(latitude, longitude, 1)?.firstOrNull()
                }
            } catch (e: Exception) {
                null
            }
        }
}
```

## React Native Device Features

### Camera Hook

```typescript
// hooks/useCamera.ts
import { useState, useCallback, useRef } from 'react';
import {
  Camera,
  useCameraDevice,
  useCameraPermission,
  PhotoFile,
  VideoFile,
  CameraPosition,
} from 'react-native-vision-camera';

export const useCamera = () => {
  const { hasPermission, requestPermission } = useCameraPermission();
  const [position, setPosition] = useState<CameraPosition>('back');
  const [flash, setFlash] = useState<'off' | 'on' | 'auto'>('auto');
  const [isRecording, setIsRecording] = useState(false);
  const cameraRef = useRef<Camera>(null);

  const device = useCameraDevice(position);

  const checkPermission = useCallback(async (): Promise<boolean> => {
    if (hasPermission) return true;
    return await requestPermission();
  }, [hasPermission, requestPermission]);

  const takePhoto = useCallback(async (): Promise<PhotoFile | null> => {
    if (!cameraRef.current) return null;

    try {
      const photo = await cameraRef.current.takePhoto({
        flash,
        qualityPrioritization: 'quality',
      });
      return photo;
    } catch (error) {
      console.error('Photo capture error:', error);
      return null;
    }
  }, [flash]);

  const startRecording = useCallback(
    (onFinish: (video: VideoFile) => void) => {
      if (!cameraRef.current || isRecording) return;

      setIsRecording(true);
      cameraRef.current.startRecording({
        flash: flash === 'on' ? 'on' : 'off',
        onRecordingFinished: (video) => {
          setIsRecording(false);
          onFinish(video);
        },
        onRecordingError: (error) => {
          setIsRecording(false);
          console.error('Recording error:', error);
        },
      });
    },
    [flash, isRecording]
  );

  const stopRecording = useCallback(async () => {
    if (!cameraRef.current || !isRecording) return;
    await cameraRef.current.stopRecording();
  }, [isRecording]);

  const toggleCamera = useCallback(() => {
    setPosition((prev) => (prev === 'back' ? 'front' : 'back'));
  }, []);

  const toggleFlash = useCallback(() => {
    setFlash((prev) => {
      switch (prev) {
        case 'off':
          return 'on';
        case 'on':
          return 'auto';
        default:
          return 'off';
      }
    });
  }, []);

  return {
    cameraRef,
    device,
    hasPermission,
    checkPermission,
    position,
    flash,
    isRecording,
    takePhoto,
    startRecording,
    stopRecording,
    toggleCamera,
    toggleFlash,
  };
};
```

### Location Hook

```typescript
// hooks/useLocation.ts
import { useState, useEffect, useCallback } from 'react';
import Geolocation, {
  GeolocationResponse,
} from '@react-native-community/geolocation';
import { PermissionsAndroid, Platform } from 'react-native';

interface Location {
  latitude: number;
  longitude: number;
  accuracy: number | null;
  altitude: number | null;
  heading: number | null;
  speed: number | null;
  timestamp: number;
}

export const useLocation = () => {
  const [location, setLocation] = useState<Location | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [watchId, setWatchId] = useState<number | null>(null);

  const requestPermission = useCallback(async (): Promise<boolean> => {
    if (Platform.OS === 'ios') {
      Geolocation.requestAuthorization();
      return true;
    }

    try {
      const granted = await PermissionsAndroid.request(
        PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION,
        {
          title: 'Location Permission',
          message: 'This app needs access to your location.',
          buttonPositive: 'OK',
        }
      );
      return granted === PermissionsAndroid.RESULTS.GRANTED;
    } catch (err) {
      return false;
    }
  }, []);

  const getCurrentLocation = useCallback(async (): Promise<Location | null> => {
    const hasPermission = await requestPermission();
    if (!hasPermission) {
      setError('Location permission denied');
      return null;
    }

    setIsLoading(true);
    setError(null);

    return new Promise((resolve) => {
      Geolocation.getCurrentPosition(
        (position: GeolocationResponse) => {
          const loc: Location = {
            latitude: position.coords.latitude,
            longitude: position.coords.longitude,
            accuracy: position.coords.accuracy,
            altitude: position.coords.altitude,
            heading: position.coords.heading,
            speed: position.coords.speed,
            timestamp: position.timestamp,
          };
          setLocation(loc);
          setIsLoading(false);
          resolve(loc);
        },
        (err) => {
          setError(err.message);
          setIsLoading(false);
          resolve(null);
        },
        {
          enableHighAccuracy: true,
          timeout: 15000,
          maximumAge: 10000,
        }
      );
    });
  }, [requestPermission]);

  const startWatching = useCallback(async () => {
    const hasPermission = await requestPermission();
    if (!hasPermission) {
      setError('Location permission denied');
      return;
    }

    const id = Geolocation.watchPosition(
      (position: GeolocationResponse) => {
        setLocation({
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
          accuracy: position.coords.accuracy,
          altitude: position.coords.altitude,
          heading: position.coords.heading,
          speed: position.coords.speed,
          timestamp: position.timestamp,
        });
      },
      (err) => {
        setError(err.message);
      },
      {
        enableHighAccuracy: true,
        distanceFilter: 10,
        interval: 5000,
        fastestInterval: 2000,
      }
    );

    setWatchId(id);
  }, [requestPermission]);

  const stopWatching = useCallback(() => {
    if (watchId !== null) {
      Geolocation.clearWatch(watchId);
      setWatchId(null);
    }
  }, [watchId]);

  useEffect(() => {
    return () => {
      if (watchId !== null) {
        Geolocation.clearWatch(watchId);
      }
    };
  }, [watchId]);

  return {
    location,
    error,
    isLoading,
    isWatching: watchId !== null,
    getCurrentLocation,
    startWatching,
    stopWatching,
    requestPermission,
  };
};
```

## Biometric Authentication

```typescript
// hooks/useBiometrics.ts
import { useState, useCallback } from 'react';
import ReactNativeBiometrics, { BiometryTypes } from 'react-native-biometrics';

const rnBiometrics = new ReactNativeBiometrics();

export const useBiometrics = () => {
  const [biometryType, setBiometryType] = useState<BiometryTypes | null>(null);
  const [isAvailable, setIsAvailable] = useState(false);

  const checkAvailability = useCallback(async () => {
    const { available, biometryType } = await rnBiometrics.isSensorAvailable();
    setIsAvailable(available);
    setBiometryType(biometryType || null);
    return { available, biometryType };
  }, []);

  const authenticate = useCallback(
    async (promptMessage: string): Promise<boolean> => {
      try {
        const { success } = await rnBiometrics.simplePrompt({
          promptMessage,
          cancelButtonText: 'Cancel',
        });
        return success;
      } catch (error) {
        console.error('Biometric auth error:', error);
        return false;
      }
    },
    []
  );

  const createKeys = useCallback(async (): Promise<string | null> => {
    try {
      const { publicKey } = await rnBiometrics.createKeys();
      return publicKey;
    } catch (error) {
      console.error('Create keys error:', error);
      return null;
    }
  }, []);

  const signPayload = useCallback(
    async (payload: string, promptMessage: string): Promise<string | null> => {
      try {
        const { signature } = await rnBiometrics.createSignature({
          promptMessage,
          payload,
          cancelButtonText: 'Cancel',
        });
        return signature;
      } catch (error) {
        console.error('Sign payload error:', error);
        return null;
      }
    },
    []
  );

  return {
    biometryType,
    isAvailable,
    checkAvailability,
    authenticate,
    createKeys,
    signPayload,
  };
};
```

## Output Expectations

When implementing device features, the subagent should:

1. Request permissions with clear rationale
2. Handle permission denied states gracefully
3. Provide settings deep links for denied permissions
4. Implement camera capture with preview
5. Support photo and video capture
6. Handle location with proper accuracy settings
7. Implement biometric authentication
8. Support device sensors where needed
9. Handle feature unavailability
10. Clean up resources properly
