package com.example.benchmark.nativeapp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel

/**
 * The first screen: the keyword is typed here and handed to the search screen,
 * and the results come back over [AppChannel].
 */
class MainActivity : ComponentActivity() {
  @OptIn(ExperimentalComposeUiApi::class)
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setContent {
      MaterialTheme {
        Scaffold(
          // Exposes testTag as the resource-id agent-device selects by.
          modifier = Modifier.fillMaxSize().semantics { testTagsAsResourceId = true }
        ) { innerPadding ->
          HomeScreen(modifier = Modifier.padding(innerPadding))
        }
      }
    }
  }
}

@Composable
private fun HomeScreen(modifier: Modifier = Modifier, viewModel: HomeViewModel = viewModel()) {
  val context = LocalContext.current

  // Resumes on the frame after the first one, i.e. once it has been drawn.
  LaunchedEffect(Unit) {
    withFrameNanos {}
    BenchMarker.markLaunch()
  }

  Column(
    modifier = modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)
  ) {
    Text("Home", style = MaterialTheme.typography.headlineMedium)

    Text(
      "検索ワード",
      style = MaterialTheme.typography.labelLarge,
      modifier = Modifier.padding(top = 24.dp),
    )
    OutlinedTextField(
      value = viewModel.keyword,
      onValueChange = { viewModel.keyword = it },
      placeholder = { Text("keyword") },
      singleLine = true,
      modifier = Modifier.fillMaxWidth().padding(top = 8.dp).testTag("keywordField"),
    )

    Button(
      onClick = {
        BenchMarker.mark("searchOpenTapped")
        context.startActivity(RepoSearchActivity.createIntent(context, viewModel.effectiveKeyword))
      },
      modifier = Modifier.fillMaxWidth().padding(top = 16.dp).testTag("openSearch"),
    ) {
      Text("検索画面を開く")
    }

    Text(
      "検索画面から受け取った結果",
      style = MaterialTheme.typography.labelLarge,
      modifier = Modifier.padding(top = 32.dp),
    )

    val errorMessage = viewModel.errorMessage
    val lastKeyword = viewModel.lastKeyword

    when {
      errorMessage != null ->
        Text(
          errorMessage,
          color = MaterialTheme.colorScheme.error,
          modifier = Modifier.padding(top = 8.dp),
        )
      lastKeyword != null -> {
        Text("keyword: $lastKeyword", modifier = Modifier.padding(top = 8.dp))
        Text("件数: ${viewModel.repositories.size}")
        viewModel.repositories.take(3).forEach { repository ->
          HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
          Text(repository.fullName, style = MaterialTheme.typography.titleSmall)
          Text("★ ${repository.stars}${repository.language?.let { " · $it" } ?: ""}")
        }
      }
      else ->
        Text(
          "まだ結果を受け取っていません",
          color = MaterialTheme.colorScheme.onSurfaceVariant,
          modifier = Modifier.padding(top = 8.dp),
        )
    }
  }
}
