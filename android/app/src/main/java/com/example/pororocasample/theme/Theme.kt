package com.example.pororocasample.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

private val DarkColorScheme =
  darkColorScheme(
    primary = PororocaWhite,
    onPrimary = PororocaBlack,
    secondary = PororocaMutedLight,
    background = PororocaBlack,
    onBackground = PororocaWhite,
    surface = PororocaBlack,
    onSurface = PororocaWhite,
  )

private val LightColorScheme =
  lightColorScheme(
    primary = PororocaBlack,
    onPrimary = PororocaWhite,
    secondary = PororocaMutedDark,
    background = PororocaWhite,
    onBackground = PororocaBlack,
    surface = PororocaWhite,
    onSurface = PororocaBlack,
  )

@Composable
fun MyApplicationTheme(
  darkTheme: Boolean = isSystemInDarkTheme(),
  content: @Composable () -> Unit,
) {
  val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme
  MaterialTheme(colorScheme = colorScheme, typography = Typography, content = content)
}
