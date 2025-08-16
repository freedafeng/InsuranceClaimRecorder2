import SwiftUI
import AVKit

struct ReviewView: View {
    let videoURL: URL
    let metadata: [String: Any]?
    @ObservedObject var cameraManager: CameraManager
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            if cameraManager.isUploading {
                ProgressView("Uploading...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(2)
            } else {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .frame(height: 400)
            }

            if let metadata = metadata {
                List {
                    ForEach(metadata.sorted(by: { $0.key < $1.key }), id: \.key) {
                        key, value in
                        HStack {
                            Text(key).fontWeight(.bold)
                            Spacer()
                            Text("\(String(describing: value))")
                        }
                    }
                }
            }
            
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Retake")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .cornerRadius(10)
                }
                .padding()
                .disabled(cameraManager.isUploading)
                
                Button(action: {
                    cameraManager.uploadVideo(from: videoURL, metadata: metadata)
                }) {
                    Text("Upload")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .cornerRadius(10)
                }
                .padding()
                .disabled(cameraManager.isUploading)
            }
        }
        .navigationBarTitle("Review Video", displayMode: .inline)
        .onChange(of: cameraManager.showReview) {
            if !cameraManager.showReview {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}