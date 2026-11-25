package com.example.resqme

import android.app.Activity
import android.content.Intent
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.net.Uri
import android.os.Build
import android.os.CancellationSignal
import android.provider.OpenableColumns
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import java.util.concurrent.Executor
import java.util.concurrent.atomic.AtomicBoolean

private const val TIER2_CHANNEL = "resqme/tier2_key"
private const val LOG_TAG = "ResQMeBiometric"
private const val PICK_EXCEL_REQUEST = 9401
private const val MAX_EXCEL_BYTES = 2 * 1024 * 1024

class MainActivity : FlutterActivity() {
    private var biometricCancellation: CancellationSignal? = null
    private var pendingExcelResult: MethodChannel.Result? = null

    override fun onStop() {
        biometricCancellation?.cancel()
        super.onStop()
    }

    override fun onDestroy() {
        biometricCancellation?.cancel()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TIER2_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
                    result.error("unsupported", "Biometric signing requires Android 9 or later.", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "checkBiometricAvailability" -> {
                        val readinessError = checkBiometricStrongReady()
                        result.success(readinessError?.first ?: "ready")
                    }
                    "enrollStudentKey" -> enrollStudentKey(
                        call.argument<String>("deviceId"),
                        call.argument<String>("message"),
                        result
                    )
                    "createKey" -> try {
                        val alias = alias(call.argument<String>("deviceId"))
                        val keyStore = keyStore()
                        if (!keyStore.containsAlias(alias)) {
                            val generator = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore")
                            generator.initialize(
                                KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_SIGN)
                                    .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                                    .setDigests(KeyProperties.DIGEST_SHA256)
                                    .setUserAuthenticationRequired(true)
                                    .setUserAuthenticationValidityDurationSeconds(-1)
                                    .setInvalidatedByBiometricEnrollment(true)
                                    .build()
                            )
                            generator.generateKeyPair()
                        }
                        val certificate = keyStore.getCertificate(alias)
                            ?: throw IllegalStateException("Device key unavailable.")
                        result.success(Base64.encodeToString(certificate.publicKey.encoded, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING))
                    } catch (error: Exception) {
                        result.error("key_unavailable", "Unable to enroll this device for biometric access.", null)
                    }
                    "sign" -> sign(
                        alias(call.argument<String>("deviceId")),
                        call.argument<String>("message"),
                        "Unlock Tier 2 information",
                        "Confirm with your device biometrics",
                        result
                    )
                    "deleteKey" -> try {
                        keyStore().deleteEntry(alias(call.argument<String>("deviceId")))
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("key_unavailable", "Device key could not be removed.", null)
                    }
                    "createStaffKey" -> createStaffKey(
                        call.argument<String>("deviceId"),
                        call.argument<String>("challenge"),
                        call.argument<String>("message"),
                        result
                    )
                    "signStaff" -> sign(
                        staffAlias(call.argument<String>("deviceId")),
                        call.argument<String>("message"),
                        "Authorize Staff Tier 2 Read",
                        "Scan your fingerprint to view emergency medical information",
                        result
                    )
                    "deleteStaffKey" -> try {
                        keyStore().deleteEntry(staffAlias(call.argument<String>("deviceId")))
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("key_unavailable", "Staff device key could not be removed.", null)
                    }
                    "setSecureScreen" -> {
                        val enabled = call.argument<Boolean>("enabled") == true
                        runOnUiThread {
                            if (enabled) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            }
                            result.success(null)
                        }
                    }
                    "pickExcelFile" -> pickExcelFile(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun alias(deviceId: String?): String {
        require(!deviceId.isNullOrBlank() && deviceId.matches(Regex("[A-Za-z0-9_-]{20,80}")))
        return "resqme_tier2_$deviceId"
    }

    private fun staffAlias(deviceId: String?): String {
        require(!deviceId.isNullOrBlank() && deviceId.matches(Regex("[A-Za-z0-9_-]{20,80}")))
        return "resqme_staff_tier2_$deviceId"
    }

    private fun keyStore(): KeyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    private fun deleteAliasQuietly(keyAlias: String) {
        try {
            val ks = keyStore()
            if (ks.containsAlias(keyAlias)) {
                ks.deleteEntry(keyAlias)
            }
        } catch (_: Exception) { }
    }

    private fun pickExcelFile(result: MethodChannel.Result) {
        if (pendingExcelResult != null) {
            result.error("picker_busy", "File selection is already in progress.", null)
            return
        }
        pendingExcelResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf(
                    "application/vnd.ms-excel",
                    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                )
            )
        }
        startActivityForResult(intent, PICK_EXCEL_REQUEST)
    }

    private fun queryDisplayName(uri: Uri): String {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (idx >= 0 && cursor.moveToFirst()) {
                val name = cursor.getString(idx)
                if (!name.isNullOrBlank()) return name
            }
        }
        return "sf1_roster.xlsx"
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == PICK_EXCEL_REQUEST) {
            val callback = pendingExcelResult
            pendingExcelResult = null
            if (callback == null) return
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                callback.success(null)
                return
            }
            val uri = data.data!!
            try {
                val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                    ?: throw IllegalStateException("Unable to read selected file.")
                if (bytes.size > MAX_EXCEL_BYTES) {
                    callback.error("file_too_large", "Selected Excel file exceeds the 2 MB limit.", null)
                    return
                }
                val fileName = queryDisplayName(uri)
                val base64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
                callback.success(mapOf("fileName" to fileName, "fileBase64" to base64))
            } catch (error: Exception) {
                callback.error("file_read_error", "Unable to read selected spreadsheet file.", null)
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun checkBiometricStrongReady(): Pair<String, String>? {
        val manager = getSystemService(BiometricManager::class.java)
            ?: return "biometric_unsupported" to "Strong hardware-backed biometrics are unavailable on this device."
        val status = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            manager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)
        } else {
            @Suppress("DEPRECATION")
            manager.canAuthenticate()
        }
        return when (status) {
            BiometricManager.BIOMETRIC_SUCCESS -> null
            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED ->
                "biometric_not_enrolled" to "No strong biometric (fingerprint) is enrolled on this device."
            BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE,
            BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE,
            BiometricManager.BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED ->
                "biometric_unsupported" to "Strong hardware-backed biometrics are unavailable on this device."
            else ->
                "biometric_unavailable" to "Biometric verification is currently unavailable."
        }
    }

    private fun isKeyHardwareBacked(privateKey: PrivateKey): Boolean {
        return try {
            val factory = KeyFactory.getInstance(privateKey.algorithm, "AndroidKeyStore")
            val keyInfo = factory.getKeySpec(privateKey, KeyInfo::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                keyInfo.securityLevel == KeyProperties.SECURITY_LEVEL_TRUSTED_ENVIRONMENT ||
                    keyInfo.securityLevel == KeyProperties.SECURITY_LEVEL_STRONGBOX
            } else {
                KeyInfo::class.java.getMethod("isInsideSecurityHardware").invoke(keyInfo) as? Boolean == true
            }
        } catch (error: Exception) {
            Log.w(LOG_TAG, "KeyInfo inspection failed: ${error.javaClass.simpleName}")
            false
        }
    }

    private fun enrollStudentKey(
        deviceId: String?,
        message: String?,
        result: MethodChannel.Result
    ) {
        if (biometricCancellation != null) {
            result.error("biometric_busy", "Biometric confirmation is already in progress.", null)
            return
        }
        val readinessError = checkBiometricStrongReady()
        if (readinessError != null) {
            Log.w(LOG_TAG, "Student biometric not ready for enrollment: ${readinessError.first}")
            result.error(readinessError.first, readinessError.second, null)
            return
        }

        val keyAlias: String
        try {
            keyAlias = alias(deviceId)
            require(!message.isNullOrBlank() && message.length <= 2048)
        } catch (error: Exception) {
            result.error("invalid_argument", "Invalid biometric enrollment parameters.", null)
            return
        }

        try {
            val ks = keyStore()
            if (ks.containsAlias(keyAlias)) {
                ks.deleteEntry(keyAlias)
            }
            val generator = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore")
            val builder = KeyGenParameterSpec.Builder(keyAlias, KeyProperties.PURPOSE_SIGN)
                .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                .setDigests(KeyProperties.DIGEST_SHA256)
                .setUserAuthenticationRequired(true)
                .setInvalidatedByBiometricEnrollment(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                builder.setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
            } else {
                @Suppress("DEPRECATION")
                builder.setUserAuthenticationValidityDurationSeconds(-1)
            }
            generator.initialize(builder.build())
            generator.generateKeyPair()

            val privateKey = keyStore().getKey(keyAlias, null) as? PrivateKey
                ?: throw IllegalStateException("Generated student key unavailable.")
            if (!isKeyHardwareBacked(privateKey)) {
                deleteAliasQuietly(keyAlias)
                Log.w(LOG_TAG, "Rejected software-backed keystore key during student enrollment")
                result.error("biometric_unsupported", "Hardware-backed biometric keystore is required.", null)
                return
            }

            val certificate = keyStore().getCertificate(keyAlias)
                ?: throw IllegalStateException("Student device certificate unavailable.")
            val publicKey = Base64.encodeToString(
                certificate.publicKey.encoded,
                Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING
            )

            promptBiometricSignature(
                privateKey = privateKey,
                message = message!!,
                title = "Set Up Biometric Security",
                subtitle = "Confirm with your fingerprint to activate biometric protection",
                onSuccess = { encodedSignature ->
                    Log.i(LOG_TAG, "Student biometric enrollment proof signed")
                    result.success(
                        mapOf(
                            "publicKey" to publicKey,
                            "signature" to encodedSignature
                        )
                    )
                },
                onFailure = { code, text ->
                    deleteAliasQuietly(keyAlias)
                    result.error(code, text, null)
                }
            )
        } catch (error: Exception) {
            deleteAliasQuietly(keyAlias)
            Log.w(LOG_TAG, "enrollStudentKey failed: ${error.javaClass.simpleName}")
            result.error("biometric_unsupported", "Unable to set up hardware biometric security on this device.", null)
        }
    }

    private fun createStaffKey(
        deviceId: String?,
        challenge: String?,
        message: String?,
        result: MethodChannel.Result
    ) {
        if (biometricCancellation != null) {
            result.error("biometric_busy", "Biometric confirmation is already in progress.", null)
            return
        }
        val readinessError = checkBiometricStrongReady()
        if (readinessError != null) {
            Log.w(LOG_TAG, "Biometric not ready for enrollment: ${readinessError.first}")
            result.error(readinessError.first, readinessError.second, null)
            return
        }

        val keyAlias: String
        try {
            keyAlias = staffAlias(deviceId)
            require(!challenge.isNullOrBlank() && challenge.length <= 256)
            require(!message.isNullOrBlank() && message.length <= 2048)
        } catch (error: Exception) {
            result.error("invalid_argument", "Invalid staff enrollment parameters.", null)
            return
        }

        try {
            val challengeBytes = Base64.decode(challenge, Base64.URL_SAFE or Base64.NO_WRAP)
            require(challengeBytes.size >= 16)
            val ks = keyStore()
            if (ks.containsAlias(keyAlias)) {
                ks.deleteEntry(keyAlias)
            }
            val generator = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore")
            val builder = KeyGenParameterSpec.Builder(keyAlias, KeyProperties.PURPOSE_SIGN)
                .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                .setDigests(KeyProperties.DIGEST_SHA256)
                .setUserAuthenticationRequired(true)
                .setInvalidatedByBiometricEnrollment(true)
                .setAttestationChallenge(challengeBytes)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                builder.setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
            } else {
                @Suppress("DEPRECATION")
                builder.setUserAuthenticationValidityDurationSeconds(-1)
            }
            generator.initialize(builder.build())
            generator.generateKeyPair()

            val privateKey = keyStore().getKey(keyAlias, null) as? PrivateKey
                ?: throw IllegalStateException("Generated staff key unavailable.")
            if (!isKeyHardwareBacked(privateKey)) {
                deleteAliasQuietly(keyAlias)
                Log.w(LOG_TAG, "Rejected software-backed keystore key during enrollment")
                result.error("biometric_unsupported", "Hardware-backed biometric keystore is required.", null)
                return
            }

            val chain = keyStore().getCertificateChain(keyAlias)
                ?: throw IllegalStateException("Attestation chain unavailable.")
            require(chain.size >= 2)
            val publicKey = Base64.encodeToString(
                chain[0].publicKey.encoded,
                Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING
            )
            val encodedChain = chain.map { cert ->
                Base64.encodeToString(cert.encoded, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
            }

            promptBiometricSignature(
                privateKey = privateKey,
                message = message!!,
                title = "Enroll Trusted Biometric Device",
                subtitle = "Scan your fingerprint to verify and activate this device",
                onSuccess = { encodedSignature ->
                    Log.i(LOG_TAG, "Staff enrollment biometric proof signed")
                    result.success(
                        mapOf(
                            "publicKey" to publicKey,
                            "attestationChain" to encodedChain,
                            "signature" to encodedSignature
                        )
                    )
                },
                onFailure = { code, text ->
                    deleteAliasQuietly(keyAlias)
                    result.error(code, text, null)
                }
            )
        } catch (error: Exception) {
            deleteAliasQuietly(keyAlias)
            Log.w(LOG_TAG, "createStaffKey failed: ${error.javaClass.simpleName}")
            result.error("biometric_unsupported", "Unable to enroll this staff device with hardware biometrics.", null)
        }
    }

    private fun sign(
        keyAlias: String,
        message: String?,
        title: String,
        subtitle: String,
        result: MethodChannel.Result
    ) {
        if (biometricCancellation != null) {
            result.error("biometric_busy", "Biometric confirmation is already in progress.", null)
            return
        }
        val readinessError = checkBiometricStrongReady()
        if (readinessError != null) {
            Log.w(LOG_TAG, "Biometric not ready for signing: ${readinessError.first}")
            result.error(readinessError.first, readinessError.second, null)
            return
        }
        if (message.isNullOrBlank() || message.length > 2048) {
            result.error("invalid_argument", "Invalid signing challenge.", null)
            return
        }

        val privateKey = try {
            keyStore().getKey(keyAlias, null) as? PrivateKey
        } catch (error: Exception) {
            Log.w(LOG_TAG, "Key lookup failed: ${error.javaClass.simpleName}")
            null
        }
        if (privateKey == null) {
            result.error("key_unavailable", "Enroll this trusted staff device with biometrics first.", null)
            return
        }

        promptBiometricSignature(
            privateKey = privateKey,
            message = message,
            title = title,
            subtitle = subtitle,
            onSuccess = { encodedSignature ->
                Log.i(LOG_TAG, "Tier 2 biometric challenge signed")
                result.success(encodedSignature)
            },
            onFailure = { code, text ->
                if (code == "key_invalidated") {
                    deleteAliasQuietly(keyAlias)
                }
                result.error(code, text, null)
            }
        )
    }

    private fun promptBiometricSignature(
        privateKey: PrivateKey,
        message: String,
        title: String,
        subtitle: String,
        onSuccess: (String) -> Unit,
        onFailure: (String, String) -> Unit
    ) {
        val completed = AtomicBoolean(false)
        fun finishFailure(code: String, text: String) {
            if (completed.compareAndSet(false, true)) {
                biometricCancellation = null
                onFailure(code, text)
            }
        }

        val signature = Signature.getInstance("SHA256withECDSA")
        try {
            signature.initSign(privateKey)
        } catch (invalidated: KeyPermanentlyInvalidatedException) {
            Log.w(LOG_TAG, "Key permanently invalidated by biometric enrollment change")
            finishFailure("key_invalidated", "Biometric enrollment changed on this device.")
            return
        } catch (error: Exception) {
            Log.w(LOG_TAG, "Signature initSign failed: ${error.javaClass.simpleName}")
            finishFailure("key_unavailable", "Biometric key is unavailable on this device.")
            return
        }

        val crypto = BiometricPrompt.CryptoObject(signature)
        val executor: Executor = mainExecutor
        val signal = CancellationSignal()
        biometricCancellation = signal

        runOnUiThread {
            try {
                val promptBuilder = BiometricPrompt.Builder(this)
                    .setTitle(title)
                    .setSubtitle(subtitle)
                    .setNegativeButton("Cancel", executor) { _, _ ->
                        finishFailure("cancelled", "Biometric confirmation cancelled.")
                    }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    promptBuilder.setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                }
                promptBuilder
                    .build()
                    .authenticate(crypto, signal, executor, object : BiometricPrompt.AuthenticationCallback() {
                        override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                            try {
                                val authenticatedSignature = authResult.cryptoObject?.signature
                                    ?: throw IllegalStateException("Biometric key unavailable.")
                                authenticatedSignature.update(message.toByteArray(Charsets.UTF_8))
                                val proof = authenticatedSignature.sign()
                                if (completed.compareAndSet(false, true)) {
                                    biometricCancellation = null
                                    onSuccess(
                                        Base64.encodeToString(
                                            proof,
                                            Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING
                                        )
                                    )
                                }
                            } catch (error: Exception) {
                                Log.w(LOG_TAG, "Signature completion failed: ${error.javaClass.simpleName}")
                                finishFailure("sign_failed", "Biometric confirmation could not be verified.")
                            }
                        }

                        override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                            Log.w(LOG_TAG, "BiometricPrompt error code=$errorCode")
                            val code = when (errorCode) {
                                BiometricPrompt.BIOMETRIC_ERROR_CANCELED,
                                BiometricPrompt.BIOMETRIC_ERROR_USER_CANCELED -> "cancelled"
                                BiometricPrompt.BIOMETRIC_ERROR_LOCKOUT,
                                BiometricPrompt.BIOMETRIC_ERROR_LOCKOUT_PERMANENT -> "biometric_lockout"
                                BiometricPrompt.BIOMETRIC_ERROR_NO_BIOMETRICS -> "biometric_not_enrolled"
                                BiometricPrompt.BIOMETRIC_ERROR_HW_NOT_PRESENT,
                                BiometricPrompt.BIOMETRIC_ERROR_HW_UNAVAILABLE -> "biometric_unsupported"
                                else -> "biometric_unavailable"
                            }
                            finishFailure(code, "Biometric confirmation did not complete.")
                        }

                        override fun onAuthenticationFailed() { }
                    })
            } catch (error: Exception) {
                Log.w(LOG_TAG, "BiometricPrompt launch failed: ${error.javaClass.simpleName}")
                finishFailure("biometric_unavailable", "Biometric verification is unavailable on this device.")
            }
        }
    }
}
