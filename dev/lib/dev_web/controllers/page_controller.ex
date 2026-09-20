defmodule DevWeb.AppWeb.PageController do
  use DevWeb.AppWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
