import AVFoundation
import SwiftUI

struct CameraView: View {
  @StateObject private var cameraManager = CameraManager()
  @Environment(\.presentationMode) var presentationMode

  var body: some View {
    ZStack {
      CameraPreview(session: cameraManager.session)
        .edgesIgnoringSafeArea(.all)

      VStack {
        HStack {
          Spacer()
          Button(action: {
            presentationMode.wrappedValue.dismiss()
          }) {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 30))
              .foregroundColor(.white)
          }
          .padding()
        }

        Spacer()

        if cameraManager.isRecording {
          Text("\(cameraManager.timeRemaining)s")
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding()
            .background(Color.black.opacity(0.5))
            .cornerRadius(10)
        }

        HStack {
          Spacer()
          Button(action: {
            if cameraManager.isRecording {
              cameraManager.stopRecording()
            } else {
              cameraManager.startRecording()
            }
          }) {
            ZStack {
              Circle()
                .fill(cameraManager.isRecording ? Color.white : Color.red)
                .frame(width: 70, height: 70)

              if cameraManager.isRecording {
                RoundedRectangle(cornerRadius: 5)
                  .fill(Color.red)
                  .frame(width: 30, height: 30)
              }
            }
          }
          .padding(.bottom, 30)
          Spacer()
        }
      }
    }
    .onAppear {
      cameraManager.checkPermissions()
    }
    .alert(isPresented: $cameraManager.showAlert) {
      Alert(
        title: Text("Permissions Denied"),
        message: Text("Please enable camera and microphone permissions in Settings."),
        dismissButton: .default(Text("OK")))
    }
    .sheet(isPresented: $cameraManager.showReview) {
      if let videoURL = cameraManager.videoURL {
        ReviewView(
          videoURL: videoURL, metadata: cameraManager.metadata, cameraManager: cameraManager)
      }
    }
  }
}

struct CameraPreview: UIViewRepresentable {
  let session: AVCaptureSession

  func makeUIView(context: Context) -> UIView {
    let view = UIView(frame: .zero)
    let previewLayer = AVCaptureVideoPreviewLayer(session: session)
    previewLayer.videoGravity = .resizeAspectFill
    view.layer.addSublayer(previewLayer)

    DispatchQueue.main.async {
      previewLayer.frame = view.bounds
    }

    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
      layer.frame = uiView.bounds
    }
  }
}
