import SwiftUI

struct ContentView: View {
  @State private var isShowingCamera = false

  var body: some View {
    NavigationView {
      VStack {
        // Logos
        Image("Travelers-Logo")
          .resizable()
          .scaledToFit()
          .frame(height: 40)
          .padding(.top)

        Image("TRV_Claim_logo")
          .resizable()
          .scaledToFit()
          .frame(height: 50)
          .padding(.bottom)

        Text("Travelers Insurance")
          .font(.largeTitle)
          .fontWeight(.bold)
          .foregroundColor(.red)

        Text("Claim Recorder")
          .font(.title2)
          .foregroundColor(.gray)

        Spacer()

        Image(systemName: "video.fill")
          .font(.system(size: 100))
          .foregroundColor(.red)

        Text(
          "Record a video of the damage for your insurance claim. The video will be 30 seconds or less."
        )
        .font(.body)
        .multilineTextAlignment(.center)
        .padding()

        Spacer()

        Button(action: {
          isShowingCamera.toggle()
        }) {
          Text("Start Recording")
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.red)
            .cornerRadius(10)
        }
        .padding()
      }
      .navigationBarHidden(true)
      .sheet(isPresented: $isShowingCamera) {
        CameraView()
      }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
