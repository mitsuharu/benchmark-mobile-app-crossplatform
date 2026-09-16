package com.example.benchmark.nativeapp

import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.text.NumberFormat
import kotlinx.coroutines.launch

/**
 * The second screen: searches GitHub for the keyword the home screen handed
 * over and lists the repositories.
 */
class RepoSearchActivity : ComponentActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    val keyword = intent.getStringExtra(EXTRA_KEYWORD) ?: HomeViewModel.DEFAULT_KEYWORD

    setContent {
      MaterialTheme {
        RepoSearchScreen(
          keyword = keyword,
          apiBaseUrl = AppConfig.apiBaseUrl,
          onClose = { finish() },
          modifier = Modifier.safeDrawingPadding(),
        )
      }
    }
  }

  companion object {
    const val EXTRA_KEYWORD = "keyword"

    fun createIntent(context: Context, keyword: String): Intent =
      Intent(context, RepoSearchActivity::class.java).putExtra(EXTRA_KEYWORD, keyword)
  }
}

/** Keywords that can be pushed into the screen while it is open. */
val PRESET_KEYWORDS = listOf("expo", "swift", "kotlin")

@Composable
fun RepoSearchScreen(
  keyword: String,
  onClose: () -> Unit,
  modifier: Modifier = Modifier,
  apiBaseUrl: String = GitHubClient.DEFAULT_BASE_URL,
  channel: AppChannel = AppChannel.shared,
) {
  val model = remember { RepoSearchModel(keyword, GitHubClient(apiBaseUrl), channel) }
  val scope = rememberCoroutineScope()
  DisposableEffect(model) { onDispose { model.dispose() } }

  // withFrameNanos resumes on the frame after the one being built, i.e. once
  // the change has been drawn.
  LaunchedEffect(Unit) {
    withFrameNanos {}
    BenchMarker.mark("searchFirstFrame")
  }
  LaunchedEffect(model.repositories) {
    if (model.repositories.isNotEmpty()) {
      withFrameNanos {}
      BenchMarker.mark("searchRendered")
    }
  }
  val initialKeyword = remember { keyword }
  LaunchedEffect(model.keyword) {
    if (model.keyword != initialKeyword) {
      withFrameNanos {}
      BenchMarker.mark("keywordApplied")
    }
  }

  Column(modifier = modifier.fillMaxSize().background(Color.White)) {
    Column(modifier = Modifier.padding(start = 20.dp, top = 24.dp, end = 20.dp)) {
      Text("GitHub Repositories", fontSize = 24.sp, fontWeight = FontWeight.Bold)
      Text(
        "keyword: ${model.keyword}",
        color = Palette.subtitle,
        fontSize = 14.sp,
        modifier = Modifier.padding(top = 4.dp),
      )
    }

    // Replacing the keyword on the open screen goes over the channel, the same
    // path the other implementations take.
    Row(
      horizontalArrangement = Arrangement.spacedBy(8.dp),
      modifier = Modifier.padding(start = 20.dp, top = 16.dp, end = 20.dp),
    ) {
      PRESET_KEYWORDS.forEach { preset ->
        OutlinedButton(
          onClick = {
            BenchMarker.mark("commandSent")
            channel.send(RepoSearchCommand.SetKeyword(preset))
          }
        ) {
          Text(preset)
        }
      }
    }

    Row(
      horizontalArrangement = Arrangement.spacedBy(8.dp),
      modifier = Modifier.padding(horizontal = 20.dp, vertical = 16.dp),
    ) {
      ActionButton(
        label = if (model.isLoading) "検索中..." else "リポジトリを検索",
        enabled = !model.isLoading,
        onClick = {
          BenchMarker.mark("searchTapped")
          scope.launch { model.search() }
        },
        modifier = Modifier.weight(1f),
      )
      ActionButton(label = "ホームに戻る", secondary = true, onClick = onClose)
    }

    model.errorMessage?.let { message ->
      Text(
        message,
        color = Palette.error,
        modifier = Modifier.padding(start = 20.dp, end = 20.dp, bottom = 8.dp),
      )
    }

    when {
      model.isLoading && model.repositories.isEmpty() ->
        CircularProgressIndicator(
          modifier = Modifier.padding(top = 32.dp).align(Alignment.CenterHorizontally)
        )
      model.repositories.isEmpty() ->
        if (model.errorMessage == null) {
          Text(
            "ボタンを押すと検索結果が表示されます。",
            color = Palette.placeholder,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().padding(top = 32.dp),
          )
        }
      else ->
        LazyColumn(contentPadding = PaddingValues(start = 20.dp, end = 20.dp, bottom = 32.dp)) {
          items(model.repositories, key = { it.id }) { repository -> RepositoryRow(repository) }
        }
    }
  }
}

object Palette {
  val primary = Color(0xFF111827)
  val secondary = Color(0xFFE5E7EB)
  val subtitle = Color(0xFF6B7280)
  val description = Color(0xFF4B5563)
  val placeholder = Color(0xFF9CA3AF)
  val error = Color(0xFFB91C1C)
}

@Composable
private fun RowScope.ActionButton(
  label: String,
  onClick: () -> Unit,
  modifier: Modifier = Modifier,
  secondary: Boolean = false,
  enabled: Boolean = true,
) {
  Button(
    onClick = onClick,
    enabled = enabled,
    shape = RoundedCornerShape(10.dp),
    colors =
      ButtonDefaults.buttonColors(
        containerColor = if (secondary) Palette.secondary else Palette.primary,
        contentColor = if (secondary) Palette.primary else Color.White,
        disabledContainerColor = Palette.primary.copy(alpha = 0.5f),
        disabledContentColor = Color.White,
      ),
    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
    modifier = modifier,
  ) {
    Text(label, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
  }
}

@Composable
private fun RepositoryRow(repository: Repository) {
  Column {
    HorizontalDivider(thickness = 0.5.dp, color = Palette.secondary)
    Column(modifier = Modifier.padding(vertical = 12.dp)) {
      Text(repository.fullName, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
      repository.description?.let { description ->
        Text(
          description,
          color = Palette.description,
          fontSize = 13.sp,
          maxLines = 2,
          overflow = TextOverflow.Ellipsis,
          modifier = Modifier.padding(top = 4.dp),
        )
      }
      Text(
        buildString {
          append("★ ${NumberFormat.getIntegerInstance().format(repository.stars)}")
          repository.language?.let { append(" · $it") }
        },
        color = Palette.subtitle,
        fontSize = 12.sp,
        modifier = Modifier.padding(top = 6.dp),
      )
    }
  }
}
