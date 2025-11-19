import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      GeneratedPluginRegistrant.register(with: self)
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    let soundModeChannel = FlutterMethodChannel(name: "com.skmonio.taaltrek/sound_mode",
                                                binaryMessenger: controller.binaryMessenger)
    
    soundModeChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "isDeviceNotSilent" {
        let isNotSilent = self.checkIfDeviceNotSilent()
        result(isNotSilent)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func checkIfDeviceNotSilent() -> Bool {
    // On iOS, we can't directly check the hardware ringer switch
    // However, we can configure the audio session to respect it
    // and check the output volume as an indicator
    let audioSession = AVAudioSession.sharedInstance()
    
    do {
      // Configure audio session to respect the ringer switch
      try audioSession.setCategory(.playback, mode: .default, options: [])
      try audioSession.setActive(true)
      
      // Check the output volume
      // If volume is 0, the device is likely in silent mode or volume is muted
      let outputVolume = audioSession.outputVolume
      
      // On iOS, when the ringer switch is on silent, the system will automatically
      // prevent sounds from playing if the audio session is configured properly.
      // However, we can use volume as a heuristic:
      // - Volume 0.0 typically means muted or silent
      // - Volume > 0.0 means sound should play
      // Note: This is not 100% accurate but works for most cases
      if outputVolume == 0.0 {
        return false  // Device appears to be silent
      }
      
      // Volume > 0, assume device is not in silent mode
      return true
    } catch {
      // If we can't determine, default to playing sound
      print("Error checking iOS silent mode: \(error)")
      return true
    }
  }
}
