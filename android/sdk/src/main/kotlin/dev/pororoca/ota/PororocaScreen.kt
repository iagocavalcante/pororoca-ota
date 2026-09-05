package dev.pororoca.ota

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

public data class PororocaHost(val strings: Map<String, String> = emptyMap(), val onAction: (String) -> Unit = {})

@Composable
public fun PororocaScreen(document: PororocaDocument, modifier: Modifier = Modifier, host: PororocaHost = PororocaHost()) {
  NodeView(document.root, modifier.fillMaxSize(), host)
}

@Composable
private fun NodeView(node: JsonObject, modifier: Modifier = Modifier, host: PororocaHost) {
  val props = node["p"] as? JsonObject ?: JsonObject(emptyMap())
  val children = node["c"] as? JsonArray ?: JsonArray(emptyList())
  val spacing = props["spacing"]?.jsonPrimitive?.content?.toDoubleOrNull()?.dp ?: 0.dp
  when (node.getValue("t").jsonPrimitive.content) {
    "vstack" -> Column(modifier, verticalArrangement = Arrangement.spacedBy(spacing)) { children.forEach { NodeView(it.jsonObject, host = host) } }
    "hstack" -> Row(modifier, horizontalArrangement = Arrangement.spacedBy(spacing)) { children.forEach { NodeView(it.jsonObject, host = host) } }
    "zstack", "box" -> Box(modifier) { children.forEach { NodeView(it.jsonObject, host = host) } }
    "scroll" -> Column(modifier.verticalScroll(rememberScrollState())) { children.forEach { NodeView(it.jsonObject, host = host) } }
    "lazycolumn" -> LazyColumn(modifier, verticalArrangement = Arrangement.spacedBy(spacing)) { items(children.size) { NodeView(children[it].jsonObject, host = host) } }
    "text" -> Text(resolveText(props["value"], host), modifier)
    "spacer" -> Spacer(modifier.height((props["minLength"]?.jsonPrimitive?.content?.toDoubleOrNull() ?: 0.0).dp))
    "divider" -> HorizontalDivider(modifier)
    "progress" -> CircularProgressIndicator(modifier)
    "button" -> Button(onClick = { host.onAction(props["action"]?.actionName().orEmpty()) }, modifier = modifier.padding(4.dp)) {
      children.firstOrNull()?.let { NodeView(it.jsonObject, host = host) }
    }
  }
}

private fun resolveText(value: JsonElement?, host: PororocaHost): String {
  if (value == null) return ""
  val objectValue = value as? JsonObject ?: return value.jsonPrimitive.content
  return objectValue["\$t"]?.jsonPrimitive?.content?.let { host.strings[it] ?: it } ?: ""
}

private fun JsonElement.actionName(): String = (this as? JsonObject)?.get("name")?.jsonPrimitive?.content ?: jsonPrimitive.content
