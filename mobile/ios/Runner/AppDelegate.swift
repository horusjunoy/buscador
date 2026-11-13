import Flutter
import UIKit
import Security
import CryptoKit
import UserNotifications

final class ProtectedVault {
  private let service="br.com.buscador.vault.v1"
  private func key() throws -> SymmetricKey {
    let query:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecReturnData as String:true]
    var found:CFTypeRef?
    let status=SecItemCopyMatching(query as CFDictionary,&found)
    if status==errSecSuccess,let data=found as? Data{return SymmetricKey(data:data)}
    guard status==errSecItemNotFound else{throw NSError(domain:service,code:Int(status))}
    let key=SymmetricKey(size:.bits256)
    let data=key.withUnsafeBytes{Data($0)}
    let add:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecValueData as String:data,kSecAttrAccessible as String:kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
    let added=SecItemAdd(add as CFDictionary,nil)
    guard added==errSecSuccess else{throw NSError(domain:service,code:Int(added))}
    return key
  }
  private func file() throws -> URL {
    let directory=try FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,appropriateFor:nil,create:true).appendingPathComponent("Buscador",isDirectory:true)
    try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
    var protectedDirectory=directory
    var values=URLResourceValues();values.isExcludedFromBackup=true;try protectedDirectory.setResourceValues(values)
    return directory.appendingPathComponent("protected-cache.bin")
  }
  func read() throws -> String? {
    let url=try file();guard FileManager.default.fileExists(atPath:url.path) else{return nil}
    let sealed=try AES.GCM.SealedBox(combined:Data(contentsOf:url))
    return String(data:try AES.GCM.open(sealed,using:key()),encoding:.utf8)
  }
  func write(_ value:String) throws {
    let encrypted=try AES.GCM.seal(Data(value.utf8),using:key())
    guard let combined=encrypted.combined else{throw NSError(domain:service,code:1)}
    try combined.write(to:file(),options:[.atomic,.completeFileProtection])
  }
  func clear() throws {
    let url=try file();if FileManager.default.fileExists(atPath:url.path){try FileManager.default.removeItem(at:url)}
    SecItemDelete([kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service] as CFDictionary)
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let vault=ProtectedVault()
  private var reminderChannel:FlutterMethodChannel?
  private var initialDose:String?
  override func application(_ application:UIApplication,didFinishLaunchingWithOptions launchOptions:[UIApplication.LaunchOptionsKey:Any]?) -> Bool {
    UNUserNotificationCenter.current().delegate=self
    return super.application(application,didFinishLaunchingWithOptions:launchOptions)
  }
  func didInitializeImplicitFlutterEngine(_ engineBridge:FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with:engineBridge.pluginRegistry)
    guard let registrar=engineBridge.pluginRegistry.registrar(forPlugin:"BuscadorNative") else{return}
    let storage=FlutterMethodChannel(name:"br.com.buscador/vault",binaryMessenger:registrar.messenger())
    storage.setMethodCallHandler{[weak self] call,result in
      guard let self=self else{return}
      do {
        switch call.method {
        case "read":result(try self.vault.read())
        case "write":guard let value=call.arguments as? String else{throw NSError(domain:"input",code:1)};try self.vault.write(value);result(nil)
        case "clear":try self.vault.clear();result(nil)
        case "export":
          guard let value=call.arguments as? String else{throw NSError(domain:"input",code:1)}
          let url=FileManager.default.temporaryDirectory.appendingPathComponent("buscador-meus-registros.json")
          try Data(value.utf8).write(to:url,options:[.atomic,.completeFileProtection])
          let activity=UIActivityViewController(activityItems:[url],applicationActivities:nil)
          let window=UIApplication.shared.connectedScenes.compactMap{$0 as? UIWindowScene}.flatMap{$0.windows}.first{$0.isKeyWindow}
          guard var controller=window?.rootViewController else{throw NSError(domain:"export",code:1)}
          while let presented=controller.presentedViewController{controller=presented}
          activity.popoverPresentationController?.sourceView=controller.view
          activity.completionWithItemsHandler={_,_,_,_ in try? FileManager.default.removeItem(at:url)}
          controller.present(activity,animated:true);result(nil)
        default:result(FlutterMethodNotImplemented)
        }
      }catch{result(FlutterError(code:"PROTECTED_STORAGE",message:"Não foi possível acessar o armazenamento protegido.",details:nil))}
    }
    let reminders=FlutterMethodChannel(name:"br.com.buscador/reminders",binaryMessenger:registrar.messenger());reminderChannel=reminders
    reminders.setMethodCallHandler{[weak self] call,result in
      let center=UNUserNotificationCenter.current()
      switch call.method {
      case "permission":center.requestAuthorization(options:[.alert,.sound,.badge]){granted,_ in DispatchQueue.main.async{result(granted ? "Notificações permitidas. A entrega depende das restrições do aparelho." : "Notificações não permitidas. Confira as configurações do iPhone.")}}
      case "clear":center.removeAllPendingNotificationRequests();center.removeAllDeliveredNotifications();result(nil)
      case "initialDose":result(self?.initialDose);self?.initialDose=nil
      case "schedule":
        guard let entries=call.arguments as? [[String:Any]] else{result(FlutterError(code:"INPUT",message:"Agenda inválida.",details:nil));return}
        center.removeAllPendingNotificationRequests()
        let iso=ISO8601DateFormatter();iso.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        let simple=ISO8601DateFormatter()
        for entry in entries.prefix(60){
          guard let id=entry["id"] as? String,let text=entry["at"] as? String,let at=iso.date(from:text) ?? simple.date(from:text),at>Date() else{continue}
          let content=UNMutableNotificationContent();content.title="Um horário para conferir";content.body="Abra o Buscador para consultar sua rotina e registrar o que aconteceu.";content.sound = .default;content.userInfo=["occurrence_id":id]
          var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(secondsFromGMT:0)!
          var parts=calendar.dateComponents([.year,.month,.day,.hour,.minute,.second],from:at);parts.timeZone=calendar.timeZone
          center.add(UNNotificationRequest(identifier:id,content:content,trigger:UNCalendarNotificationTrigger(dateMatching:parts,repeats:false)))
        }
        result(nil)
      default:result(FlutterMethodNotImplemented)
      }
    }
  }
  override func userNotificationCenter(_ center:UNUserNotificationCenter,didReceive response:UNNotificationResponse,withCompletionHandler completionHandler:@escaping () -> Void) {
    if let id=response.notification.request.content.userInfo["occurrence_id"] as? String{initialDose=id;reminderChannel?.invokeMethod("openDose",arguments:id)}
    completionHandler()
  }
  override func userNotificationCenter(_ center:UNUserNotificationCenter,willPresent notification:UNNotification,withCompletionHandler completionHandler:@escaping (UNNotificationPresentationOptions) -> Void) {completionHandler([.banner,.sound])}
}
