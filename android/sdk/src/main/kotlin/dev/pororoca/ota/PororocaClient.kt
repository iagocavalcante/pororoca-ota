package dev.pororoca.ota

import com.google.crypto.tink.subtle.Ed25519Verify
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.security.GeneralSecurityException
import java.security.MessageDigest
import java.time.Instant
import java.util.Base64
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put

public data class PororocaRemoteUpdate(
  val id: String,
  val documents: Map<String, PororocaDocument>,
  val rolloutBucket: Int,
  val documentBytes: Map<String, ByteArray> = emptyMap(),
)

public data class PororocaHttpResponse(val status: Int, val body: ByteArray)

public fun interface PororocaTransport {
  public suspend fun execute(method: String, url: URL, token: String, body: ByteArray?): PororocaHttpResponse
}

public class PororocaHttpTransport : PororocaTransport {
  override suspend fun execute(method: String, url: URL, token: String, body: ByteArray?): PororocaHttpResponse =
    withContext(Dispatchers.IO) {
      val connection = (url.openConnection() as HttpURLConnection)
      try {
        connection.requestMethod = method
        connection.setRequestProperty("Accept", "application/json")
        connection.setRequestProperty("Authorization", "Bearer $token")
        if (body != null) {
          connection.doOutput = true
          connection.setRequestProperty("Content-Type", "application/json")
          connection.outputStream.use { it.write(body) }
        }
        val status = connection.responseCode
        val stream = if (status in 200..299) connection.inputStream else connection.errorStream
        PororocaHttpResponse(status, stream?.use { it.readBytes() } ?: ByteArray(0))
      } finally {
        connection.disconnect()
      }
    }
}

public class PororocaClient(
  serverUrl: String,
  private val apiToken: String,
  private val app: String,
  private val installId: String,
  private val publicKey: ByteArray,
  private val channel: String = "production",
  private val transport: PororocaTransport = PororocaHttpTransport(),
) {
  private val baseUrl = serverUrl.trimEnd('/')

  init {
    val server = URL(baseUrl)
    require(server.protocol == "https" || (server.protocol == "http" && server.host in setOf("localhost", "127.0.0.1", "::1", "[::1]"))) {
      "Pororoca server URL must use HTTPS except on loopback"
    }
    require(app.matches(Regex("^[a-z0-9]+(?:-[a-z0-9]+)*$"))) { "Invalid Pororoca app slug" }
    require(channel.matches(Regex("^[a-z0-9]+(?:-[a-z0-9]+)*$"))) { "Invalid Pororoca channel" }
  }

  public suspend fun checkForUpdate(): PororocaRemoteUpdate? {
    val encodedInstallId = URLEncoder.encode(installId, Charsets.UTF_8.name())
    val url = URL("$baseUrl/api/v1/apps/$app/channels/$channel/resolve?install_id=$encodedInstallId")
    val response = transport.execute("GET", url, apiToken, null)
    if (response.status == 204) return null
    check(response.status == 200) { "Pororoca resolve failed with HTTP ${response.status}: ${response.body.decodeToString()}" }

    val root = Json.parseToJsonElement(response.body.decodeToString()).jsonObject
    val update = root.getValue("update").jsonObject
    val envelope = update.getValue("manifest").jsonObject
    val manifest = envelope.getValue("manifest").jsonObject
    val signature = envelope.getValue("signature").jsonPrimitive.content
    val keyId = envelope.getValue("keyID").jsonPrimitive.content
    val files = update.getValue("files").jsonObject
    val updateId = manifest.getValue("updateID").jsonPrimitive.content
    require(manifest.getValue("platform").jsonPrimitive.content == "android") { "Expected an Android update" }
    val expectedKeyId = MessageDigest.getInstance("SHA-256").digest(publicKey).toHex().take(16)
    require(keyId == expectedKeyId) { "Signed update key ID does not match the configured public key" }

    PororocaSignature.verify(
      publicKey = publicKey,
      signature = Base64.getDecoder().decode(signature),
      message = canonicalBytes(manifest),
    )

    val decodedFiles = verifyFiles(manifest, files)
    val documentBytes = mutableMapOf<String, ByteArray>()
    val documents =
      manifest.getValue("documents").jsonArray.associate { entry ->
        val metadata = entry.jsonObject
        val screen = metadata.getValue("screen").jsonPrimitive.content
        val path = metadata.getValue("path").jsonPrimitive.content
        val bytes = decodedFiles.getValue(path)
        val document = PororocaDocument.decode(bytes)
        require(document.screen == screen) { "Manifest screen does not match document at $path" }
        documentBytes[screen] = bytes
        screen to document
      }

    return PororocaRemoteUpdate(
      id = updateId,
      documents = documents,
      documentBytes = documentBytes,
      rolloutBucket = root.getValue("bucket").jsonPrimitive.content.toInt(),
    )
  }

  public suspend fun record(event: String, updateId: String? = null, metadata: Map<String, String> = emptyMap()) {
    val payload =
      buildJsonObject {
        put("install_id", installId)
        put("event", event)
        updateId?.let { put("update_id", it) }
        put("occurred_at", Instant.now().toString())
        put("metadata", buildJsonObject { metadata.forEach { (key, value) -> put(key, value) } })
      }
    val response =
      transport.execute(
        "POST",
        URL("$baseUrl/api/v1/apps/$app/channels/$channel/events"),
        apiToken,
        Json.encodeToString(JsonObject.serializer(), payload).encodeToByteArray(),
      )
    check(response.status == 202) { "Pororoca event failed with HTTP ${response.status}" }
  }

  private fun verifyFiles(manifest: JsonObject, files: JsonObject): Map<String, ByteArray> {
    val entries = manifest.getValue("documents").jsonArray + (manifest["assets"] as? JsonArray ?: JsonArray(emptyList()))
    return entries.associate { entry ->
      val metadata = entry.jsonObject
      val path = metadata.getValue("path").jsonPrimitive.content
      require(path.isSafeBundlePath()) { "Unsafe bundle path: $path" }
      val encoded = files[path]?.jsonPrimitive?.contentOrNull ?: error("Missing bundle file: $path")
      val bytes = Base64.getDecoder().decode(encoded)
      metadata["byteCount"]?.jsonPrimitive?.contentOrNull?.toIntOrNull()?.let { expected ->
        require(bytes.size == expected) { "Byte count mismatch for $path" }
      }
      val actual = "sha256:" + MessageDigest.getInstance("SHA-256").digest(bytes).toHex()
      require(actual == metadata.getValue("sha256").jsonPrimitive.content) { "Hash mismatch for $path" }
      path to bytes
    }
  }
}

public object PororocaSignature {
  public fun verify(publicKey: ByteArray, signature: ByteArray, message: ByteArray) {
    require(publicKey.size == 32) { "Ed25519 public key must contain 32 bytes" }
    try {
      Ed25519Verify(publicKey).verify(signature, message)
    } catch (error: GeneralSecurityException) {
      throw IllegalArgumentException("Signed update verification failed", error)
    }
  }
}

private val canonicalJson = Json { prettyPrint = false; explicitNulls = false }

private fun canonicalBytes(element: JsonElement): ByteArray {
  val canonical =
    when (element) {
      is JsonObject -> JsonObject(element.entries.sortedBy { it.key }.associate { it.key to canonicalElement(it.value) })
      else -> canonicalElement(element)
    }
  return canonicalJson.encodeToString(JsonElement.serializer(), canonical).encodeToByteArray()
}

private fun canonicalElement(element: JsonElement): JsonElement =
  when (element) {
    is JsonObject -> JsonObject(element.entries.sortedBy { it.key }.associate { it.key to canonicalElement(it.value) })
    is JsonArray -> JsonArray(element.map(::canonicalElement))
    else -> element
  }

private fun String.isSafeBundlePath(): Boolean =
  isNotEmpty() && !startsWith('/') && !endsWith('/') && !contains('\\') && split('/').none { it.isEmpty() || it == "." || it == ".." }

private fun ByteArray.toHex(): String = joinToString("") { "%02x".format(it) }
