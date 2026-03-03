---
name: Mobile Push Notification Handling
platform: mobile
description: Push notification registration, handling, display, and deep link integration for mobile applications
model: opus
category: mobile/frontend
---

# Mobile Push Notification Handling

## Purpose

Implement comprehensive push notification systems that handle device registration, notification permissions, foreground/background notification display, rich notifications, action buttons, and deep link navigation. The push system should integrate seamlessly with the app's navigation and state management.

## Push Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   Push Notification Flow                         │
├─────────────────────────────────────────────────────────────────┤
│  Backend → APNs/FCM → Device → App                              │
├─────────────────────────────────────────────────────────────────┤
│  States:                                                         │
│  - Foreground: App handles display                              │
│  - Background: System displays, app handles tap                 │
│  - Terminated: System displays, app launched on tap             │
├─────────────────────────────────────────────────────────────────┤
│  Notification Types:                                             │
│  - Alert: Text notification                                     │
│  - Rich: Images, videos, custom UI                              │
│  - Silent: Data-only, background processing                     │
│  - Interactive: Action buttons, text reply                      │
└─────────────────────────────────────────────────────────────────┘
```

## iOS Push Notifications

### Setup and Registration

```swift
// PushNotificationManager.swift
import UserNotifications
import UIKit

@Observable
final class PushNotificationManager: NSObject {
    static let shared = PushNotificationManager()

    var deviceToken: String?
    var isPermissionGranted: Bool = false
    var pendingNotification: PushNotification?

    private let notificationCenter = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        notificationCenter.delegate = self
    }

    func requestPermission() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .badge, .sound, .provisional]
            isPermissionGranted = try await notificationCenter.requestAuthorization(options: options)

            if isPermissionGranted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }

            return isPermissionGranted
        } catch {
            print("Push permission error: \(error)")
            return false
        }
    }

    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }

    func handleDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = token
        print("Device token: \(token)")

        // Send token to backend
        Task {
            try? await registerTokenWithBackend(token)
        }
    }

    func handleRegistrationError(_ error: Error) {
        print("Push registration error: \(error)")
    }

    private func registerTokenWithBackend(_ token: String) async throws {
        // Send to your backend
        let endpoint = Endpoint(
            path: "/devices/register",
            method: .post,
            body: DeviceRegistration(
                token: token,
                platform: "ios",
                appVersion: Bundle.main.appVersion
            )
        )
        try await APIClient.shared.request(endpoint)
    }

    func setBadgeCount(_ count: Int) async {
        try? await notificationCenter.setBadgeCount(count)
    }

    func clearBadge() async {
        await setBadgeCount(0)
    }

    func removeAllDeliveredNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
    }

    func getDeliveredNotifications() async -> [UNNotification] {
        return await notificationCenter.deliveredNotifications()
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension PushNotificationManager: UNUserNotificationCenterDelegate {
    // Foreground notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let pushNotification = PushNotification(notification: notification)

        // Decide whether to show notification in foreground
        if shouldShowForegroundNotification(pushNotification) {
            return [.banner, .sound, .badge]
        }

        // Handle silently
        handleSilentNotification(pushNotification)
        return []
    }

    // Notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let pushNotification = PushNotification(notification: response.notification)
        let actionIdentifier = response.actionIdentifier

        switch actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            // User tapped notification
            handleNotificationTap(pushNotification)

        case UNNotificationDismissActionIdentifier:
            // User dismissed notification
            break

        default:
            // Custom action button
            handleNotificationAction(actionIdentifier, notification: pushNotification, response: response)
        }
    }

    private func shouldShowForegroundNotification(_ notification: PushNotification) -> Bool {
        // Don't show if user is viewing related content
        // Customize based on notification type
        return true
    }

    private func handleSilentNotification(_ notification: PushNotification) {
        // Process data without display
        NotificationCenter.default.post(
            name: .silentPushReceived,
            object: notification
        )
    }

    private func handleNotificationTap(_ notification: PushNotification) {
        // Navigate to relevant screen
        pendingNotification = notification

        NotificationCenter.default.post(
            name: .pushNotificationTapped,
            object: notification
        )
    }

    private func handleNotificationAction(
        _ action: String,
        notification: PushNotification,
        response: UNNotificationResponse
    ) {
        switch action {
        case "reply":
            if let textResponse = response as? UNTextInputNotificationResponse {
                handleReplyAction(notification, text: textResponse.userText)
            }
        case "mark_read":
            handleMarkReadAction(notification)
        case "archive":
            handleArchiveAction(notification)
        default:
            break
        }
    }

    private func handleReplyAction(_ notification: PushNotification, text: String) {
        // Send reply to backend
    }

    private func handleMarkReadAction(_ notification: PushNotification) {
        // Mark as read
    }

    private func handleArchiveAction(_ notification: PushNotification) {
        // Archive notification
    }
}

// Notification names
extension Notification.Name {
    static let pushNotificationTapped = Notification.Name("pushNotificationTapped")
    static let silentPushReceived = Notification.Name("silentPushReceived")
}
```

### Notification Model

```swift
// PushNotification.swift
struct PushNotification {
    let id: String
    let title: String
    let body: String
    let category: NotificationCategory
    let data: [String: Any]
    let deepLink: String?
    let imageURL: URL?

    enum NotificationCategory: String {
        case order = "ORDER"
        case promotion = "PROMOTION"
        case message = "MESSAGE"
        case reminder = "REMINDER"
        case general = "GENERAL"
    }

    init(notification: UNNotification) {
        let content = notification.request.content
        let userInfo = content.userInfo

        self.id = notification.request.identifier
        self.title = content.title
        self.body = content.body
        self.category = NotificationCategory(rawValue: content.categoryIdentifier) ?? .general
        self.data = userInfo as? [String: Any] ?? [:]
        self.deepLink = userInfo["deep_link"] as? String
        self.imageURL = (userInfo["image_url"] as? String).flatMap(URL.init)
    }
}
```

### Notification Categories and Actions

```swift
// NotificationCategories.swift
enum NotificationCategories {
    static func registerCategories() {
        let center = UNUserNotificationCenter.current()

        // Order notification actions
        let viewOrderAction = UNNotificationAction(
            identifier: "view_order",
            title: "View Order",
            options: .foreground
        )

        let orderCategory = UNNotificationCategory(
            identifier: "ORDER",
            actions: [viewOrderAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        // Message notification actions
        let replyAction = UNTextInputNotificationAction(
            identifier: "reply",
            title: "Reply",
            options: [],
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Type your reply..."
        )

        let markReadAction = UNNotificationAction(
            identifier: "mark_read",
            title: "Mark as Read",
            options: []
        )

        let messageCategory = UNNotificationCategory(
            identifier: "MESSAGE",
            actions: [replyAction, markReadAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        // Promotion notification actions
        let shopNowAction = UNNotificationAction(
            identifier: "shop_now",
            title: "Shop Now",
            options: .foreground
        )

        let promotionCategory = UNNotificationCategory(
            identifier: "PROMOTION",
            actions: [shopNowAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([
            orderCategory,
            messageCategory,
            promotionCategory
        ])
    }
}
```

### Rich Notifications (Notification Service Extension)

```swift
// NotificationService.swift (Notification Service Extension target)
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let content = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        // Download and attach image
        if let imageURLString = request.content.userInfo["image_url"] as? String,
           let imageURL = URL(string: imageURLString) {
            downloadImage(from: imageURL) { [weak self] attachment in
                if let attachment {
                    content.attachments = [attachment]
                }
                self?.contentHandler?(content)
            }
        } else {
            contentHandler(content)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler,
           let content = bestAttemptContent {
            contentHandler(content)
        }
    }

    private func downloadImage(
        from url: URL,
        completion: @escaping (UNNotificationAttachment?) -> Void
    ) {
        let task = URLSession.shared.downloadTask(with: url) { localURL, _, error in
            guard let localURL, error == nil else {
                completion(nil)
                return
            }

            let fileManager = FileManager.default
            let tempDirectory = fileManager.temporaryDirectory
            let destinationURL = tempDirectory.appendingPathComponent(url.lastPathComponent)

            do {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.moveItem(at: localURL, to: destinationURL)

                let attachment = try UNNotificationAttachment(
                    identifier: UUID().uuidString,
                    url: destinationURL,
                    options: nil
                )
                completion(attachment)
            } catch {
                completion(nil)
            }
        }
        task.resume()
    }
}
```

## Android Push Notifications

### FCM Setup

```kotlin
// FirebaseMessagingService.kt
@AndroidEntryPoint
class AppFirebaseMessagingService : FirebaseMessagingService() {

    @Inject
    lateinit var notificationManager: NotificationManager

    @Inject
    lateinit var pushTokenRepository: PushTokenRepository

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        CoroutineScope(Dispatchers.IO).launch {
            pushTokenRepository.registerToken(token)
        }
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)

        val pushNotification = PushNotification.fromRemoteMessage(remoteMessage)

        if (isAppInForeground()) {
            // Handle in-app
            handleForegroundNotification(pushNotification)
        } else {
            // Show system notification
            notificationManager.showNotification(pushNotification)
        }
    }

    private fun isAppInForeground(): Boolean {
        val appProcessInfo = ActivityManager.RunningAppProcessInfo()
        ActivityManager.getMyMemoryState(appProcessInfo)
        return appProcessInfo.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
    }

    private fun handleForegroundNotification(notification: PushNotification) {
        // Post to event bus or broadcast
        EventBus.getDefault().post(ForegroundNotificationEvent(notification))
    }
}

// PushNotification.kt
data class PushNotification(
    val id: String,
    val title: String,
    val body: String,
    val category: NotificationCategory,
    val data: Map<String, String>,
    val deepLink: String?,
    val imageUrl: String?
) {
    enum class NotificationCategory {
        ORDER, PROMOTION, MESSAGE, REMINDER, GENERAL
    }

    companion object {
        fun fromRemoteMessage(message: RemoteMessage): PushNotification {
            val data = message.data
            val notification = message.notification

            return PushNotification(
                id = message.messageId ?: UUID.randomUUID().toString(),
                title = notification?.title ?: data["title"] ?: "",
                body = notification?.body ?: data["body"] ?: "",
                category = NotificationCategory.valueOf(
                    data["category"]?.uppercase() ?: "GENERAL"
                ),
                data = data,
                deepLink = data["deep_link"],
                imageUrl = notification?.imageUrl?.toString() ?: data["image_url"]
            )
        }
    }
}
```

### Notification Manager

```kotlin
// NotificationManager.kt
@Singleton
class AppNotificationManager @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val notificationManager = context.getSystemService<NotificationManager>()!!

    companion object {
        const val CHANNEL_ORDERS = "orders"
        const val CHANNEL_PROMOTIONS = "promotions"
        const val CHANNEL_MESSAGES = "messages"
        const val CHANNEL_GENERAL = "general"
    }

    init {
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        val channels = listOf(
            NotificationChannel(
                CHANNEL_ORDERS,
                "Order Updates",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications about your orders"
                enableVibration(true)
                setShowBadge(true)
            },
            NotificationChannel(
                CHANNEL_PROMOTIONS,
                "Promotions & Offers",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Special offers and promotions"
            },
            NotificationChannel(
                CHANNEL_MESSAGES,
                "Messages",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Direct messages and chat"
                enableVibration(true)
            },
            NotificationChannel(
                CHANNEL_GENERAL,
                "General",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "General notifications"
            }
        )

        notificationManager.createNotificationChannels(channels)
    }

    fun showNotification(pushNotification: PushNotification) {
        val channelId = when (pushNotification.category) {
            PushNotification.NotificationCategory.ORDER -> CHANNEL_ORDERS
            PushNotification.NotificationCategory.PROMOTION -> CHANNEL_PROMOTIONS
            PushNotification.NotificationCategory.MESSAGE -> CHANNEL_MESSAGES
            else -> CHANNEL_GENERAL
        }

        val pendingIntent = createPendingIntent(pushNotification)

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(pushNotification.title)
            .setContentText(pushNotification.body)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .addActions(pushNotification)

        // Load image if present
        pushNotification.imageUrl?.let { imageUrl ->
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    val bitmap = loadImage(imageUrl)
                    builder.setLargeIcon(bitmap)
                    builder.setStyle(
                        NotificationCompat.BigPictureStyle()
                            .bigPicture(bitmap)
                            .bigLargeIcon(null as Bitmap?)
                    )
                    showNotificationInternal(pushNotification.id, builder.build())
                } catch (e: Exception) {
                    showNotificationInternal(pushNotification.id, builder.build())
                }
            }
        } ?: run {
            builder.setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText(pushNotification.body)
            )
            showNotificationInternal(pushNotification.id, builder.build())
        }
    }

    private fun showNotificationInternal(id: String, notification: Notification) {
        notificationManager.notify(id.hashCode(), notification)
    }

    private fun createPendingIntent(notification: PushNotification): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            notification.deepLink?.let { putExtra("deep_link", it) }
            putExtra("notification_id", notification.id)
        }

        return PendingIntent.getActivity(
            context,
            notification.id.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun NotificationCompat.Builder.addActions(
        notification: PushNotification
    ): NotificationCompat.Builder {
        when (notification.category) {
            PushNotification.NotificationCategory.ORDER -> {
                addAction(
                    R.drawable.ic_view,
                    "View Order",
                    createActionIntent("view_order", notification)
                )
            }
            PushNotification.NotificationCategory.MESSAGE -> {
                addAction(createReplyAction(notification))
                addAction(
                    R.drawable.ic_check,
                    "Mark Read",
                    createActionIntent("mark_read", notification)
                )
            }
            PushNotification.NotificationCategory.PROMOTION -> {
                addAction(
                    R.drawable.ic_shopping,
                    "Shop Now",
                    createActionIntent("shop_now", notification)
                )
            }
            else -> {}
        }
        return this
    }

    private fun createReplyAction(notification: PushNotification): NotificationCompat.Action {
        val remoteInput = RemoteInput.Builder("reply_text")
            .setLabel("Type your reply...")
            .build()

        val replyIntent = createActionIntent("reply", notification)

        return NotificationCompat.Action.Builder(
            R.drawable.ic_reply,
            "Reply",
            replyIntent
        )
            .addRemoteInput(remoteInput)
            .setAllowGeneratedReplies(true)
            .build()
    }

    private fun createActionIntent(
        action: String,
        notification: PushNotification
    ): PendingIntent {
        val intent = Intent(context, NotificationActionReceiver::class.java).apply {
            this.action = action
            putExtra("notification_id", notification.id)
            putExtra("deep_link", notification.deepLink)
        }

        return PendingIntent.getBroadcast(
            context,
            "${notification.id}_$action".hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private suspend fun loadImage(url: String): Bitmap {
        val loader = ImageLoader(context)
        val request = ImageRequest.Builder(context)
            .data(url)
            .allowHardware(false)
            .build()
        return (loader.execute(request).drawable as BitmapDrawable).bitmap
    }

    fun clearAllNotifications() {
        notificationManager.cancelAll()
    }

    fun clearNotification(id: String) {
        notificationManager.cancel(id.hashCode())
    }
}
```

### Action Receiver

```kotlin
// NotificationActionReceiver.kt
@AndroidEntryPoint
class NotificationActionReceiver : BroadcastReceiver() {

    @Inject
    lateinit var notificationHandler: NotificationActionHandler

    override fun onReceive(context: Context, intent: Intent) {
        val notificationId = intent.getStringExtra("notification_id") ?: return
        val deepLink = intent.getStringExtra("deep_link")

        when (intent.action) {
            "reply" -> {
                val replyText = RemoteInput.getResultsFromIntent(intent)
                    ?.getCharSequence("reply_text")
                    ?.toString()

                if (replyText != null) {
                    CoroutineScope(Dispatchers.IO).launch {
                        notificationHandler.handleReply(notificationId, replyText)
                    }
                }
            }
            "mark_read" -> {
                CoroutineScope(Dispatchers.IO).launch {
                    notificationHandler.handleMarkRead(notificationId)
                }
            }
            "view_order", "shop_now" -> {
                // Launch app with deep link
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra("deep_link", deepLink)
                }
                context.startActivity(launchIntent)
            }
        }

        // Dismiss notification
        val notificationManager = context.getSystemService<NotificationManager>()
        notificationManager?.cancel(notificationId.hashCode())
    }
}
```

## React Native Push Notifications

### Setup with Notifee

```typescript
// services/pushNotificationService.ts
import messaging from '@react-native-firebase/messaging';
import notifee, {
  AndroidImportance,
  AndroidStyle,
  EventType,
} from '@notifee/react-native';
import { Linking } from 'react-native';

class PushNotificationService {
  private initialized = false;

  async initialize() {
    if (this.initialized) return;

    await this.createChannels();
    await this.requestPermission();
    this.setupMessageHandlers();

    this.initialized = true;
  }

  private async createChannels() {
    await notifee.createChannel({
      id: 'orders',
      name: 'Order Updates',
      importance: AndroidImportance.HIGH,
      vibration: true,
      badge: true,
    });

    await notifee.createChannel({
      id: 'promotions',
      name: 'Promotions & Offers',
      importance: AndroidImportance.DEFAULT,
    });

    await notifee.createChannel({
      id: 'messages',
      name: 'Messages',
      importance: AndroidImportance.HIGH,
      vibration: true,
    });

    await notifee.createChannel({
      id: 'general',
      name: 'General',
      importance: AndroidImportance.DEFAULT,
    });
  }

  async requestPermission(): Promise<boolean> {
    const authStatus = await messaging().requestPermission();
    const enabled =
      authStatus === messaging.AuthorizationStatus.AUTHORIZED ||
      authStatus === messaging.AuthorizationStatus.PROVISIONAL;

    if (enabled) {
      await this.getToken();
    }

    return enabled;
  }

  async getToken(): Promise<string | null> {
    try {
      const token = await messaging().getToken();
      await this.registerTokenWithBackend(token);
      return token;
    } catch (error) {
      console.error('Failed to get FCM token:', error);
      return null;
    }
  }

  private async registerTokenWithBackend(token: string) {
    try {
      await apiClient.post('/devices/register', {
        token,
        platform: Platform.OS,
        appVersion: DeviceInfo.getVersion(),
      });
    } catch (error) {
      console.error('Failed to register token:', error);
    }
  }

  private setupMessageHandlers() {
    // Foreground messages
    messaging().onMessage(async (remoteMessage) => {
      await this.displayNotification(remoteMessage);
    });

    // Background/quit message handler
    messaging().setBackgroundMessageHandler(async (remoteMessage) => {
      await this.displayNotification(remoteMessage);
    });

    // Token refresh
    messaging().onTokenRefresh(async (token) => {
      await this.registerTokenWithBackend(token);
    });

    // Notification interaction
    notifee.onForegroundEvent(({ type, detail }) => {
      this.handleNotificationEvent(type, detail);
    });

    notifee.onBackgroundEvent(async ({ type, detail }) => {
      this.handleNotificationEvent(type, detail);
    });
  }

  private async displayNotification(remoteMessage: FirebaseMessagingTypes.RemoteMessage) {
    const { notification, data } = remoteMessage;

    const channelId = this.getChannelId(data?.category as string);

    const notificationConfig: any = {
      title: notification?.title || data?.title,
      body: notification?.body || data?.body,
      data,
      android: {
        channelId,
        pressAction: { id: 'default' },
        actions: this.getAndroidActions(data?.category as string),
      },
      ios: {
        categoryId: data?.category,
      },
    };

    // Add image if present
    if (notification?.android?.imageUrl || data?.image_url) {
      const imageUrl = notification?.android?.imageUrl || data?.image_url;
      notificationConfig.android.style = {
        type: AndroidStyle.BIGPICTURE,
        picture: imageUrl,
      };
      notificationConfig.android.largeIcon = imageUrl;
    }

    await notifee.displayNotification(notificationConfig);
  }

  private getChannelId(category?: string): string {
    switch (category?.toLowerCase()) {
      case 'order':
        return 'orders';
      case 'promotion':
        return 'promotions';
      case 'message':
        return 'messages';
      default:
        return 'general';
    }
  }

  private getAndroidActions(category?: string) {
    switch (category?.toLowerCase()) {
      case 'order':
        return [
          { title: 'View Order', pressAction: { id: 'view_order' } },
        ];
      case 'message':
        return [
          {
            title: 'Reply',
            pressAction: { id: 'reply' },
            input: { placeholder: 'Type your reply...' },
          },
          { title: 'Mark Read', pressAction: { id: 'mark_read' } },
        ];
      case 'promotion':
        return [
          { title: 'Shop Now', pressAction: { id: 'shop_now' } },
        ];
      default:
        return [];
    }
  }

  private handleNotificationEvent(type: EventType, detail: any) {
    const { notification, pressAction, input } = detail;

    switch (type) {
      case EventType.PRESS:
        this.handleNotificationPress(notification);
        break;
      case EventType.ACTION_PRESS:
        this.handleActionPress(pressAction?.id, notification, input);
        break;
      case EventType.DISMISSED:
        // Handle dismissal
        break;
    }
  }

  private handleNotificationPress(notification: any) {
    const deepLink = notification?.data?.deep_link;
    if (deepLink) {
      Linking.openURL(deepLink);
    }
  }

  private async handleActionPress(
    actionId: string,
    notification: any,
    input?: string
  ) {
    switch (actionId) {
      case 'reply':
        if (input) {
          await this.sendReply(notification?.data?.conversation_id, input);
        }
        break;
      case 'mark_read':
        await this.markAsRead(notification?.data?.message_id);
        break;
      case 'view_order':
      case 'shop_now':
        const deepLink = notification?.data?.deep_link;
        if (deepLink) {
          Linking.openURL(deepLink);
        }
        break;
    }

    // Dismiss notification
    if (notification?.id) {
      await notifee.cancelNotification(notification.id);
    }
  }

  private async sendReply(conversationId: string, message: string) {
    try {
      await apiClient.post(`/conversations/${conversationId}/reply`, { message });
    } catch (error) {
      console.error('Failed to send reply:', error);
    }
  }

  private async markAsRead(messageId: string) {
    try {
      await apiClient.post(`/messages/${messageId}/read`);
    } catch (error) {
      console.error('Failed to mark as read:', error);
    }
  }

  async clearAllNotifications() {
    await notifee.cancelAllNotifications();
  }

  async getBadgeCount(): Promise<number> {
    return notifee.getBadgeCount();
  }

  async setBadgeCount(count: number) {
    await notifee.setBadgeCount(count);
  }

  async clearBadge() {
    await notifee.setBadgeCount(0);
  }
}

export const pushNotificationService = new PushNotificationService();
```

## Flutter Push Notifications

### Firebase Messaging Setup

```dart
// push_notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushNotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const _orderChannel = AndroidNotificationChannel(
    'orders',
    'Order Updates',
    description: 'Notifications about your orders',
    importance: Importance.high,
  );

  static const _promotionChannel = AndroidNotificationChannel(
    'promotions',
    'Promotions & Offers',
    description: 'Special offers and promotions',
    importance: Importance.defaultImportance,
  );

  static const _messageChannel = AndroidNotificationChannel(
    'messages',
    'Messages',
    description: 'Direct messages and chat',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    // Request permission
    await _requestPermission();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Create notification channels
    await _createNotificationChannels();

    // Get token
    await _getToken();

    // Setup message handlers
    _setupMessageHandlers();
  }

  Future<void> _requestPermission() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
    );
  }

  Future<void> _createNotificationChannels() async {
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_orderChannel);
      await androidPlugin.createNotificationChannel(_promotionChannel);
      await androidPlugin.createNotificationChannel(_messageChannel);
    }
  }

  Future<String?> _getToken() async {
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      await _registerTokenWithBackend(token);
    }
    return token;
  }

  Future<void> _registerTokenWithBackend(String token) async {
    // Send to backend
  }

  void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background message tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Token refresh
    _firebaseMessaging.onTokenRefresh.listen(_registerTokenWithBackend);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      await _showLocalNotification(message);
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    final deepLink = message.data['deep_link'] as String?;
    if (deepLink != null) {
      // Navigate using deep link handler
      DeepLinkHandler.instance.handle(Uri.parse(deepLink));
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;
    final channelId = _getChannelId(data['category'] as String?);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId,
      importance: Importance.high,
      priority: Priority.high,
      actions: _getNotificationActions(data['category'] as String?),
    );

    final iosDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification?.title ?? data['title'],
      notification?.body ?? data['body'],
      details,
      payload: jsonEncode(data),
    );
  }

  String _getChannelId(String? category) {
    switch (category?.toLowerCase()) {
      case 'order':
        return 'orders';
      case 'promotion':
        return 'promotions';
      case 'message':
        return 'messages';
      default:
        return 'general';
    }
  }

  List<AndroidNotificationAction>? _getNotificationActions(String? category) {
    switch (category?.toLowerCase()) {
      case 'order':
        return [
          const AndroidNotificationAction('view_order', 'View Order'),
        ];
      case 'message':
        return [
          const AndroidNotificationAction(
            'reply',
            'Reply',
            inputs: [AndroidNotificationActionInput(label: 'Type your reply...')],
          ),
          const AndroidNotificationAction('mark_read', 'Mark Read'),
        ];
      case 'promotion':
        return [
          const AndroidNotificationAction('shop_now', 'Shop Now'),
        ];
      default:
        return null;
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final deepLink = data['deep_link'] as String?;

      switch (response.actionId) {
        case 'reply':
          final input = response.input;
          if (input != null) {
            _handleReply(data['conversation_id'] as String?, input);
          }
          break;
        case 'mark_read':
          _handleMarkRead(data['message_id'] as String?);
          break;
        default:
          if (deepLink != null) {
            DeepLinkHandler.instance.handle(Uri.parse(deepLink));
          }
      }
    }
  }

  static void _onBackgroundNotificationResponse(NotificationResponse response) {
    // Handle background notification response
  }

  Future<void> _handleReply(String? conversationId, String message) async {
    if (conversationId != null) {
      // Send reply to backend
    }
  }

  Future<void> _handleMarkRead(String? messageId) async {
    if (messageId != null) {
      // Mark as read
    }
  }

  Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
  }
}
```

## Output Expectations

When implementing push notifications, the subagent should:

1. Configure platform-specific notification permissions
2. Register device tokens with backend
3. Create notification channels (Android)
4. Handle foreground, background, and terminated states
5. Implement rich notifications with images
6. Add interactive action buttons
7. Support inline reply for messages
8. Integrate with deep linking
9. Manage notification badges
10. Handle token refresh
