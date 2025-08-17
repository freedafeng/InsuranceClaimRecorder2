import AVFoundation
import CoreLocation
import UIKit

class CameraManager: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate,
  CLLocationManagerDelegate
{
  @Published var session = AVCaptureSession()
  @Published var isRecording = false
  @Published var showAlert = false
  @Published var showReview = false
  @Published var timeRemaining = 30
  @Published var isUploading = false

  var videoURL: URL?
  var metadata: [String: Any]?

  private var videoOutput = AVCaptureMovieFileOutput()
  private var timer: Timer?
  private let locationManager = CLLocationManager()

  override init() {
    super.init()
    locationManager.delegate = self
  }

  func checkPermissions() {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      setupSession()
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { granted in
        if granted {
          self.setupSession()
        }
      }
    default:
      showAlert = true
    }
  }

  private func setupSession() {
    session.beginConfiguration()

    guard
      let videoDevice = AVCaptureDevice.default(
        .builtInWideAngleCamera, for: .video, position: .back),
      let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
      let audioDevice = AVCaptureDevice.default(for: .audio),
      let audioInput = try? AVCaptureDeviceInput(device: audioDevice)
    else {
      session.commitConfiguration()
      return
    }

    if session.canAddInput(videoInput) {
      session.addInput(videoInput)
    }

    if session.canAddInput(audioInput) {
      session.addInput(audioInput)
    }

    if session.canAddOutput(videoOutput) {
      session.addOutput(videoOutput)
    }

    session.commitConfiguration()

    DispatchQueue.global(qos: .background).async {
      self.session.startRunning()
    }
    locationManager.requestWhenInUseAuthorization()
  }

  func startRecording() {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    let fileURL = paths[0].appendingPathComponent("claim_video.mov")
    try? FileManager.default.removeItem(at: fileURL)

    isRecording = true
    timeRemaining = 30

    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
      if self.timeRemaining > 0 {
        self.timeRemaining -= 1
      } else {
        self.stopRecording()
      }
    }

    videoOutput.startRecording(to: fileURL, recordingDelegate: self)
  }

  func stopRecording() {
    if isRecording {
      videoOutput.stopRecording()
      isRecording = false
      timer?.invalidate()
      timer = nil
    }
  }

  func fileOutput(
    _ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
    from connections: [AVCaptureConnection], error: Error?
  ) {
    if error == nil {
      videoURL = outputFileURL
      collectMetadata()
      showReview = true
    }
  }

  private func collectMetadata() {
    var collectedMetadata: [String: Any] = [:]

    if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
      collectedMetadata["focalLength"] = device.lensPosition
      collectedMetadata["zoomFactor"] = device.videoZoomFactor
      collectedMetadata["deviceModel"] = UIDevice.current.model
      collectedMetadata["osVersion"] = UIDevice.current.systemVersion
    }

    if let location = locationManager.location {
      collectedMetadata["latitude"] = location.coordinate.latitude
      collectedMetadata["longitude"] = location.coordinate.longitude
      collectedMetadata["altitude"] = location.altitude
      collectedMetadata["locationAccuracy"] = location.horizontalAccuracy
    }

    metadata = collectedMetadata
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    // Location data is collected when recording finishes
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print("Failed to get location: \(error.localizedDescription)")
  }

  func uploadVideo(from url: URL, metadata: [String: Any]?) {
    isUploading = true

    guard let uploadURL = URL(string: Config.backendURL) else {
      print("Invalid backend URL")
      isUploading = false
      return
    }

    var request = URLRequest(url: uploadURL)
    request.httpMethod = "POST"

    let boundary = UUID().uuidString
    request.setValue(
      "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    var data = Data()

    // Add video data
    if let videoData = try? Data(contentsOf: url) {
      data.append("--\(boundary)\r\n".data(using: .utf8)!)
      data.append(
        "Content-Disposition: form-data; name=\"file\"; filename=\"claim_video.mov\"\r\n".data(
          using: .utf8)!)
      data.append("Content-Type: video/quicktime\r\n\r\n".data(using: .utf8)!)
      data.append(videoData)
      data.append("\r\n".data(using: .utf8)!)
    }

    // Add metadata
    if let metadata = metadata,
      let metadataJson = try? JSONSerialization.data(
        withJSONObject: metadata, options: .prettyPrinted)
    {
      data.append("--\(boundary)\r\n".data(using: .utf8)!)
      data.append("Content-Disposition: form-data; name=\"metadata\"\r\n".data(using: .utf8)!)
      data.append("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)
      data.append(metadataJson)
      data.append("\r\n".data(using: .utf8)!)
    }

    data.append("--\(boundary)--\r\n".data(using: .utf8)!)

    let task = URLSession.shared.uploadTask(with: request, from: data) {
      responseData, response, error in
      DispatchQueue.main.async {
        self.isUploading = false
        if let error = error {
          print("Upload failed with error: \(error.localizedDescription)")
          return
        }

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
          print("Upload successful")
          self.showReview = false
        } else {
          print("Upload failed with response: \(String(describing: response))")
        }
      }
    }
    task.resume()
  }
}
