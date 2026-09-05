package com.example.pororocasample.ui.main

import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation3.runtime.NavKey
import com.example.pororocasample.data.DefaultDataRepository
import com.example.pororocasample.theme.MyApplicationTheme
import dev.pororoca.ota.PororocaDocument
import dev.pororoca.ota.PororocaHost
import dev.pororoca.ota.PororocaScreen

@Composable
fun MainScreen(
  onItemClick: (NavKey) -> Unit,
  modifier: Modifier = Modifier,
  viewModel: MainScreenViewModel = viewModel { MainScreenViewModel(DefaultDataRepository()) },
) {
  val state by viewModel.uiState.collectAsStateWithLifecycle()
  when (state) {
    MainScreenUiState.Loading -> {
      // Blank
    }
    is MainScreenUiState.Success -> {
      MainScreen(data = (state as MainScreenUiState.Success).data, modifier = modifier)
    }
    is MainScreenUiState.Error -> {
      Text("Error loading data: ${(state as MainScreenUiState.Error).throwable.message}")
    }
  }
}

@Composable
internal fun MainScreen(data: List<String>, modifier: Modifier = Modifier) {
  val document = remember { PororocaDocument.decode(DEMO_DOCUMENT.encodeToByteArray()) }
  var status by remember { mutableStateOf("Ready for ${data.joinToString()}") }
  PororocaScreen(
    document = document,
    modifier = modifier,
    host =
      PororocaHost(
        strings = mapOf("title" to "Pororoca OTA", "status" to status),
        onAction = { action -> if (action == "inspect_update") status = "Native action received" },
      ),
  )
}

@Preview(showBackground = true)
@Composable
fun MainScreenPreview() {
  MyApplicationTheme { MainScreen(listOf("Android")) }
}

@Preview(showBackground = true, widthDp = 340)
@Composable
fun MainScreenPortraitPreview() {
  MyApplicationTheme { MainScreen(listOf("Android")) }
}

private const val DEMO_DOCUMENT =
  """{"format":1,"screen":"delivery","platform":"android","requires":{"runtime":"1"},"root":{"t":"vstack","p":{"spacing":16},"c":[{"t":"text","p":{"value":{"${'$'}t":"title"}}},{"t":"text","p":{"value":"This screen was decoded and rendered by the native Compose SDK."}},{"t":"button","p":{"action":{"name":"inspect_update"}},"c":[{"t":"text","p":{"value":"Inspect update"}}]},{"t":"text","p":{"value":{"${'$'}t":"status"}}}]}}"""
