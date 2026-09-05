package dev.pororoca.ota

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

public data class PororocaDocument(val screen: String, val platform: String, val root: JsonObject) {
  public companion object {
    private val json = Json { ignoreUnknownKeys = false }
    private val rootKeys = setOf("format", "screen", "platform", "requires", "local", "root")
    private val nodeKeys = setOf("t", "p", "mod", "c")
    private val supportedNodes = setOf("vstack", "hstack", "zstack", "box", "spacer", "scroll", "lazycolumn", "text", "divider", "progress", "button")

    public fun decode(bytes: ByteArray): PororocaDocument {
      val value = json.parseToJsonElement(bytes.decodeToString()).jsonObject
      val unknown = value.keys - rootKeys
      require(unknown.isEmpty()) { "Unknown document key: ${unknown.first()}" }
      require(value.getValue("format").jsonPrimitive.content == "1") { "Unsupported document format" }
      require(value.getValue("platform").jsonPrimitive.content == "android") { "Expected an Android document" }
      val root = value.getValue("root").jsonObject
      validateNode(root, "/root")
      return PororocaDocument(value.getValue("screen").jsonPrimitive.content, "android", root)
    }

    private fun validateNode(node: JsonObject, path: String) {
      val unknown = node.keys - nodeKeys
      require(unknown.isEmpty()) { "Unknown node key at $path: ${unknown.first()}" }
      val type = node.getValue("t").jsonPrimitive.content
      require(type in supportedNodes) { "Unsupported node at $path: $type" }
      (node["c"] as? JsonArray)?.forEachIndexed { index: Int, child: JsonElement -> validateNode(child.jsonObject, "$path/c/$index") }
    }
  }
}
