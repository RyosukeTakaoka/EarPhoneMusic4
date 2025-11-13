import UIKit
import AVFoundation

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // バックグラウンドタスクを開始できるようにする
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
        print("✅ AppDelegate: 初期化完了")
        
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        print("📱 アプリがバックグラウンドに移行中...")
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("📱 アプリがバックグラウンドに入りました")
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        print("📱 アプリがフォアグラウンドに戻ります")
    }
}
