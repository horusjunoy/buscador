package br.com.buscador.buscador

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.security.KeyStore
import java.time.Instant
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class ProtectedStore(private val context: Context) {
    private val preferences = context.getSharedPreferences("buscador_protected", Context.MODE_PRIVATE)
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey("buscador_v1", null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(KeyGenParameterSpec.Builder("buscador_v1", KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        return generator.generateKey()
    }
    fun read(name: String): String? {
        val encoded = preferences.getString(name, null) ?: return null
        val data = Base64.decode(encoded, Base64.NO_WRAP)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, data.copyOfRange(0,12)))
        return String(cipher.doFinal(data.copyOfRange(12,data.size)), Charsets.UTF_8)
    }
    fun write(name: String, value: String) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val data = cipher.iv + cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        check(preferences.edit().putString(name, Base64.encodeToString(data, Base64.NO_WRAP)).commit())
    }
    fun clear() {
        check(preferences.edit().clear().commit())
        KeyStore.getInstance("AndroidKeyStore").apply { load(null); deleteEntry("buscador_v1") }
    }
}

object ReminderScheduler {
    const val CHANNEL = "buscador_discrete_reminders"
    private fun pending(context: Context, code: Int, id: String): PendingIntent = PendingIntent.getBroadcast(context, code,
        Intent(context, ReminderReceiver::class.java).putExtra("occurrence_id", id).putExtra("notification_code",code), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    fun clear(context: Context) {
        val stored = ProtectedStore(context)
        val list = JSONArray(stored.read("reminders") ?: "[]")
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (i in 0 until list.length()) alarm.cancel(pending(context,1000+i,list.getJSONObject(i).getString("id")))
        stored.write("reminders","[]")
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancelAll()
    }
    fun schedule(context: Context, list: JSONArray) {
        clear(context)
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(NotificationChannel(CHANNEL,"Lembretes discretos",NotificationManager.IMPORTANCE_DEFAULT))
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val accepted = JSONArray()
        for (i in 0 until minOf(list.length(),60)) {
            val item = list.getJSONObject(i)
            val at = Instant.parse(item.getString("at")).toEpochMilli()
            if (at <= System.currentTimeMillis()) continue
            val code=1000+accepted.length()
            alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,at,pending(context,code,item.getString("id")))
            accepted.put(item)
        }
        ProtectedStore(context).write("reminders",accepted.toString())
    }
}
class ReminderReceiver: BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val id=intent.getStringExtra("occurrence_id") ?: return
        val tap=PendingIntent.getActivity(context,intent.getIntExtra("notification_code",1000),Intent(context,MainActivity::class.java).putExtra("occurrence_id",id).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification=Notification.Builder(context,ReminderScheduler.CHANNEL)
            .setSmallIcon(android.R.drawable.ic_popup_reminder).setContentTitle("Um horário para conferir")
            .setContentText("Abra o Buscador para consultar sua rotina e registrar o que aconteceu.")
            .setVisibility(Notification.VISIBILITY_PRIVATE).setAutoCancel(true).setContentIntent(tap).build()
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(intent.getIntExtra("notification_code",1000),notification)
    }
}
class BootReceiver: BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in listOf(Intent.ACTION_BOOT_COMPLETED,Intent.ACTION_MY_PACKAGE_REPLACED)) return
        runCatching { val list=JSONArray(ProtectedStore(context).read("reminders") ?: "[]");ReminderScheduler.schedule(context,list) }
    }
}
class MainActivity: FlutterActivity() {
    private var reminderChannel: MethodChannel?=null
    private var exportResult: MethodChannel.Result?=null
    private var exportData: ByteArray?=null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val vault=ProtectedStore(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"br.com.buscador/vault").setMethodCallHandler { call,result ->
            try {
                when(call.method) {
                    "read" -> result.success(vault.read("snapshot"))
                    "write" -> { vault.write("snapshot",call.arguments as String);result.success(null) }
                    "clear" -> { vault.clear();result.success(null) }
                    "export" -> {
                        if(exportResult!=null){result.error("BUSY","Conclua a exportação anterior.",null)} else {
                            exportResult=result;exportData=(call.arguments as String).toByteArray(Charsets.UTF_8)
                            startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("application/json").putExtra(Intent.EXTRA_TITLE,"buscador-meus-registros.json"),2026)
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) { result.error("PROTECTED_STORAGE","Não foi possível acessar o armazenamento protegido.",null) }
        }
        reminderChannel=MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"br.com.buscador/reminders").also { channel ->
            channel.setMethodCallHandler { call,result ->
                try {
                    when(call.method) {
                        "permission" -> {
                            if(Build.VERSION.SDK_INT>=33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED) requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS),120)
                            val enabled=(getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).areNotificationsEnabled()
                            result.success(if(enabled) "Notificações permitidas. Horários são aproximados e sujeitos às restrições do aparelho." else "Permissão de notificações ainda não concedida. Confira a solicitação ou as configurações do aparelho.")
                        }
                        "schedule" -> { ReminderScheduler.schedule(this,JSONArray(call.arguments as List<*>));result.success(null) }
                        "clear" -> { ReminderScheduler.clear(this);result.success(null) }
                        "initialDose" -> { result.success(intent.getStringExtra("occurrence_id"));intent.removeExtra("occurrence_id") }
                        else -> result.notImplemented()
                    }
                } catch (_: Exception) { result.error("REMINDER_ERROR","Não foi possível configurar os avisos neste aparelho.",null) }
            }
        }
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.getStringExtra("occurrence_id")?.let { reminderChannel?.invokeMethod("openDose",it) }
    }
    @Deprecated("Uses system document picker for a local export")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode,resultCode,data)
        if(requestCode!=2026)return
        try {
            val uri=data?.data
            if(resultCode==Activity.RESULT_OK && uri!=null){contentResolver.openOutputStream(uri).use { stream -> checkNotNull(stream).write(checkNotNull(exportData)) };exportResult?.success(null)}
            else exportResult?.error("CANCELLED","Exportação cancelada.",null)
        }catch(_:Exception){exportResult?.error("EXPORT_FAILED","Não foi possível salvar o arquivo.",null)}
        finally { exportData=null;exportResult=null }
    }
}
