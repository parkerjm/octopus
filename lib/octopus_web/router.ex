defmodule OctopusWeb.Router do
  use OctopusWeb, :router
  import Phoenix.LiveDashboard.Router
  import Plug.BasicAuth

  pipeline :admins_only do
    plug :basic_auth, Application.fetch_env!(:octopus, :dashboard)
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {OctopusWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/" do
    pipe_through [:browser, :admins_only]
    live_dashboard "/dashboard", metrics: OctopusWeb.Telemetry, ecto_repos: [Octopus.Repo]
  end

  scope "/", OctopusWeb do
    pipe_through :browser

    live "/", PageLive, :index
  end
end
