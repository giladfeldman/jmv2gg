# A placeholder, not the websocket package: see DESCRIPTION. Any attempt to
# open a connection fails loudly; nothing is simulated.
unavailable <- function(...) {
  stop("WebSocket connections are not available in the jmv2gg browser preview ",
    "(this is a placeholder for the 'websocket' package). Render the report in native R.", call. = FALSE)
}

WebSocket <- local({
  generator <- new.env(parent = emptyenv())
  generator$new <- unavailable
  generator$classname <- "WebSocket"
  generator
})

is_jmv2gg_placeholder <- function() TRUE
