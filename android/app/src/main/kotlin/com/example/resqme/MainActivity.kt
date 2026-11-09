package com.example.resqme

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.hardware.biometrics.BiometricPrompt
import android.content.Context
import android.util.Base64
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import java.util.concurrent.Executor

private const val TIER2_CHANNEL = "resqme/tier2_key"

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TIER2_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
                    result.error("unsupported", "Biometric signing requires Android 9 or later.", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
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
                    "sign" -> sign(call.argument<String>("deviceId"), call.argument<String>("message"), result)
                    "deleteKey" -> try {
                        keyStore().deleteEntry(alias(call.argument<String>("deviceId")))
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("key_unavailable", "Device key could not be removed.", null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun alias(deviceId: String?): String {
        require(!deviceId.isNullOrBlank() && deviceId.matches(Regex("[A-Za-z0-9_-]{20,80}")))
        return "resqme_tier2_$deviceId"
    }

    private fun keyStore(): KeyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    private fun sign(deviceId: String?, message: String?, result: MethodChannel.Result) {
        try {
            val keyAlias = alias(deviceId)
            require(!message.isNullOrBlank() && message.length <= 2048)
            val privateKey = keyStore().getKey(keyAlias, null) as? java.security.PrivateKey
                ?: throw IllegalStateException("Device key unavailable.")
            val signature = Signature.getInstance("SHA256withECDSA")
            signature.initSign(privateKey)
            val crypto = BiometricPrompt.CryptoObject(signature)
            val executor: Executor = mainExecutor
            BiometricPrompt.Builder(this)
                .setTitle("Unlock Tier 2 information")
                .setSubtitle("Confirm with your device biometrics")
                .setNegativeButton("Cancel", executor) { _, _ -> result.error("cancelled", "Biometric confirmation cancelled.", null) }
                .build()
                .authenticate(crypto, cancellationSignal(), executor, object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                        try {
                            val authenticatedSignature = authResult.cryptoObject?.signature
                                ?: throw IllegalStateException("Biometric key unavailable.")
                            authenticatedSignature.update(message.toByteArray(Charsets.UTF_8))
                            val proof = authenticatedSignature.sign()
                            result.success(Base64.encodeToString(proof, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING))
                        } catch (error: Exception) {
                            result.error("sign_failed", "Biometric confirmation could not be verified.", null)
                        }
                    }

                    override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                        result.error("biometric_unavailable", "Biometric confirmation is unavailable.", null)
                    }

                    override fun onAuthenticationFailed() { }
                })
        } catch (error: Exception) {
            result.error("key_unavailable", "Biometric access is unavailable on this device.", null)
        }
    }

    @Suppress("DEPRECATION")
    private fun cancellationSignal(): android.os.CancellationSignal = android.os.CancellationSignal()
}
