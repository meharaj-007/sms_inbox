// Copyright (c) 2026 Meheraj. Use of this source code is governed by the
// MIT license that can be found in the LICENSE file.

package io.github.meharaj007.sms_inbox

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.provider.Telephony
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry
import kotlin.coroutines.resume
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * Read-only access to the Android SMS inbox.
 *
 * Nothing is stored, cached or sent anywhere: each query reads the inbox
 * content provider and returns the rows to Dart.
 */
class SmsInboxPlugin :
    FlutterPlugin,
    ActivityAware,
    SmsInboxHostApi,
    PluginRegistry.RequestPermissionsResultListener {

    private var context: Context? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingPermission: CancellableContinuation<Boolean>? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        SmsInboxHostApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        SmsInboxHostApi.setUp(binding.binaryMessenger, null)
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = detachActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() = detachActivity()

    private fun detachActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
    }

    override fun hasPermission(): Boolean {
        val context = context ?: return false
        return ContextCompat.checkSelfPermission(context, Manifest.permission.READ_SMS) ==
            PackageManager.PERMISSION_GRANTED
    }

    override suspend fun requestPermission(): Boolean {
        if (hasPermission()) return true
        val activity: Activity = activityBinding?.activity
            ?: throw FlutterError("no_activity", "requestPermission needs a foreground activity")
        if (pendingPermission != null) {
            throw FlutterError("in_progress", "A permission request is already showing")
        }
        return suspendCancellableCoroutine { continuation ->
            pendingPermission = continuation
            continuation.invokeOnCancellation { pendingPermission = null }
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.READ_SMS),
                PERMISSION_REQUEST_CODE,
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermission?.resume(granted)
        pendingPermission = null
        return true
    }

    /** Runs on a background task queue (see pigeons/messages.dart). */
    override fun query(query: InboxQueryData): List<SmsMessageData> {
        val context = context ?: throw FlutterError("detached", "Plugin is not attached")
        if (!hasPermission()) {
            throw FlutterError("permission_denied", "READ_SMS has not been granted")
        }
        val limit = query.limit.coerceIn(1L, MAX_LIMIT).toInt()

        val selection = StringBuilder("${Telephony.Sms._ID} > ?")
        val args = mutableListOf(query.afterId.toString())
        query.sinceMillis?.let {
            selection.append(" AND ${Telephony.Sms.DATE} >= ?")
            args.add(it.toString())
        }
        query.untilMillis?.let {
            selection.append(" AND ${Telephony.Sms.DATE} < ?")
            args.add(it.toString())
        }
        val senders = query.senders.orEmpty().filter { it.isNotBlank() }
        if (senders.isNotEmpty()) {
            selection.append(" AND LOWER(${Telephony.Sms.ADDRESS}) IN (")
            selection.append(senders.joinToString(",") { "?" })
            selection.append(")")
            args.addAll(senders.map { it.lowercase() })
        }

        val rows = ArrayList<SmsMessageData>(minOf(limit, 256))
        context.contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            PROJECTION,
            selection.toString(),
            args.toTypedArray(),
            "${Telephony.Sms._ID} ASC",
        )?.use { cursor ->
            val id = cursor.getColumnIndexOrThrow(Telephony.Sms._ID)
            val address = cursor.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
            val body = cursor.getColumnIndexOrThrow(Telephony.Sms.BODY)
            val date = cursor.getColumnIndexOrThrow(Telephony.Sms.DATE)
            val dateSent = cursor.getColumnIndexOrThrow(Telephony.Sms.DATE_SENT)
            val subscription = cursor.getColumnIndex(Telephony.Sms.SUBSCRIPTION_ID)
            val thread = cursor.getColumnIndexOrThrow(Telephony.Sms.THREAD_ID)
            val read = cursor.getColumnIndexOrThrow(Telephony.Sms.READ)
            while (rows.size < limit && cursor.moveToNext()) {
                rows.add(
                    SmsMessageData(
                        id = cursor.getLong(id),
                        address = cursor.getString(address).orEmpty(),
                        body = cursor.getString(body).orEmpty(),
                        dateMillis = cursor.getLong(date),
                        dateSentMillis = cursor.longOrNull(dateSent)?.takeIf { it > 0 },
                        subscriptionId = if (subscription >= 0) cursor.longOrNull(subscription) else null,
                        threadId = cursor.longOrNull(thread),
                        isRead = cursor.getInt(read) != 0,
                    ),
                )
            }
        }
        return rows
    }

    private fun android.database.Cursor.longOrNull(index: Int): Long? =
        if (isNull(index)) null else getLong(index)

    private companion object {
        const val PERMISSION_REQUEST_CODE = 0x534D  // "SM"
        const val MAX_LIMIT = 5000L
        val PROJECTION = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
            Telephony.Sms.DATE_SENT,
            Telephony.Sms.SUBSCRIPTION_ID,
            Telephony.Sms.THREAD_ID,
            Telephony.Sms.READ,
        )
    }
}
