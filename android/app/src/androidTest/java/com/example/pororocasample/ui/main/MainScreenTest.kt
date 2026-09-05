package com.example.pororocasample.ui.main

import androidx.activity.ComponentActivity
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import org.junit.Before
import org.junit.Rule
import org.junit.Test

/** UI tests for [com.example.pororocasample.ui.main.MainScreen]. */
class MainScreenTest {

  @get:Rule val composeTestRule = createAndroidComposeRule<ComponentActivity>()

  @Before
  fun setup() {
    composeTestRule.setContent { MainScreen(FAKE_DATA) }
  }

  @Test
  fun pororocaDocument_isRendered() {
    composeTestRule.onNodeWithText("Pororoca OTA").assertExists()
    composeTestRule.onNodeWithText("Inspect update").assertExists()
    composeTestRule.onNodeWithText("Ready for ${FAKE_DATA.joinToString()}").assertExists()
  }
}

private val FAKE_DATA = listOf("Sample1", "Sample2", "Sample3")
