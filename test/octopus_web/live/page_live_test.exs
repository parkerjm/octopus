defmodule OctopusWeb.PageLiveTest do
  use OctopusWeb.ConnCase

  import Phoenix.LiveViewTest

  test "disconnected and connected render", %{conn: conn} do
    {:ok, page_live, disconnected_html} = live(conn, "/")
    assert disconnected_html =~ "Welcome to Phoenix!"
    assert render(page_live) =~ "Welcome to Phoenix!"
  end

  describe "basic auth" do
    test "connects with valid credentials", %{conn: conn} do
      resp =
        conn
        |> put_req_header("authorization", "Basic " <> Base.encode64("crown:caliber"))
        |> get("/dashboard/home")

      assert html_response(resp, 200)
    end

    test "does not connect with invalid credentials", %{conn: conn} do
      resp =
        conn
        |> put_req_header("authorization", "Basic " <> Base.encode64("crown:wrong"))
        |> get("/dashboard/home")

      assert response(resp, 401)
    end

    test "does not connect without credentials", %{conn: conn} do
      resp =
        conn
        |> get("/dashboard/home")

      assert response(resp, 401)
    end
  end
end
