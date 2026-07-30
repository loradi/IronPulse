import Foundation
import UserNotifications

/// Sin delegado, iOS no muestra el banner de una notificacion local si la
/// app esta en foreground cuando el trigger dispara (solo la entrega en
/// silencio). Esto hacia que el aviso de fin de descanso pareciera
/// funcionar "a veces si, a veces no" segun si el usuario estaba mirando
/// la app en ese instante exacto.
final class RestNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = RestNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

enum RestNotificationScheduler {
    private static let identifier = "rest-finished"

    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    static func scheduleRestFinished(in seconds: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard seconds > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = String(
            localized: "rest_notification.title",
            defaultValue: "Descanso terminado",
            bundle: AppLanguage.current.bundle,
            locale: AppLanguage.current.locale
        )
        content.body = String(
            localized: "rest_notification.body",
            defaultValue: "A por el siguiente set.",
            bundle: AppLanguage.current.bundle,
            locale: AppLanguage.current.locale
        )
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    static func cancelPending() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
