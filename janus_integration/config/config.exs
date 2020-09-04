import Config

config :janus_integration, :config,
  gateway_ws_url: System.get_env("GATEWAY_WS_URL") || "ws://localhost:8188",
  gateway_ws_admin_url: System.get_env("GATEWAY_WS_ADMIN_URL") || "ws://localhost:7188"
