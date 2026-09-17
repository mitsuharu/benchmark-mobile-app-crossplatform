package com.example.benchmark.qr.nativeapp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.unit.dp
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** How often the screen redraws while decoding; see AGENTS.md. */
private const val PROGRESS_INTERVAL_MS = 100L

/**
 * The QR decode benchmark, written natively: unpack the bundled images, then
 * decode them one after the other with ML Kit.
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
          QrScreen(modifier = Modifier.padding(innerPadding))
        }
      }
    }
  }
}

private sealed interface Phase {
  data object Preparing : Phase

  data object Ready : Phase

  data object Running : Phase

  data class Failed(val message: String) : Phase

  data class Done(val decoded: Int, val totalMs: Long, val perImageMs: Double) : Phase
}

@Composable
private fun QrScreen(modifier: Modifier = Modifier) {
  val context = LocalContext.current
  val scope = rememberCoroutineScope()
  var phase by remember { mutableStateOf<Phase>(Phase.Preparing) }
  var paths by remember { mutableStateOf<List<String>>(emptyList()) }

  // The decode loop only writes this counter; the screen reads it on a timer
  // so a redraw never lands between two decodes.
  val progress = remember { AtomicInteger(0) }
  var done by remember { mutableStateOf(0) }
  var elapsedMs by remember { mutableStateOf(0L) }

  // Resumes on the frame after the first one, i.e. once it has been drawn.
  LaunchedEffect(Unit) {
    withFrameNanos {}
    BenchMarker.markLaunch()
    phase =
      try {
        paths = withContext(Dispatchers.IO) { unpackImages(context) }
        Phase.Ready
      } catch (e: Exception) {
        Phase.Failed(e.message ?: e.toString())
      }
  }

  Column(
    modifier = modifier.fillMaxSize().padding(24.dp),
    verticalArrangement = Arrangement.spacedBy(12.dp),
  ) {
    Text("QR デコード", style = MaterialTheme.typography.headlineSmall)
    Text("native · ML Kit", style = MaterialTheme.typography.bodyMedium)

    when (val current = phase) {
      is Phase.Preparing -> Text("画像を展開中...")
      is Phase.Failed -> Text("失敗: ${current.message}", color = MaterialTheme.colorScheme.error)
      else -> Text("準備完了: ${paths.size} 枚")
    }

    if (phase is Phase.Ready || phase is Phase.Done) {
      Button(
        onClick = {
          progress.set(0)
          done = 0
          elapsedMs = 0
          phase = Phase.Running
          scope.launch {
            val startedAt = System.currentTimeMillis()
            val ticker = launch {
              while (true) {
                done = progress.get()
                elapsedMs = System.currentTimeMillis() - startedAt
                delay(PROGRESS_INTERVAL_MS)
              }
            }
            phase =
              try {
                val run = withContext(Dispatchers.Default) { decodeAll(context, paths, progress) }
                // Written now that the loop is over, so logging stays out of
                // the measurement (see AGENTS.md).
                BenchMarker.mark("decodeStarted", run.startedAt)
                BenchMarker.mark("decodeFinished", run.finishedAt)
                BenchMarker.markValue("decodedCount", run.decoded.toString())
                BenchMarker.markValue("decodeDurationsUs", run.durationsUs.joinToString(","))
                val sorted = run.durationsUs.sorted()
                Phase.Done(
                  decoded = run.decoded,
                  totalMs = run.finishedAt - run.startedAt,
                  perImageMs = sorted[sorted.size / 2] / 1000.0,
                )
              } catch (e: Exception) {
                Phase.Failed(e.message ?: e.toString())
              } finally {
                ticker.cancel()
                done = progress.get()
              }
          }
        },
        modifier = Modifier.fillMaxWidth().testTag("startDecode"),
      ) {
        Text("デコードを開始")
      }
    }

    if (phase is Phase.Running) {
      Text("デコード中: $done / ${paths.size}", style = MaterialTheme.typography.titleMedium)
      Text("経過: %.1f 秒".format(elapsedMs / 1000.0))
    }

    (phase as? Phase.Done)?.let { current ->
      Text("デコード完了: ${current.decoded} / ${paths.size}", style = MaterialTheme.typography.titleMedium)
      Text("合計: ${current.totalMs} ms")
      Text("1 枚あたり: %.2f ms".format(current.perImageMs))
    }
  }
}
