use axum::{self, Router, routing::get, response::{Html, IntoResponse}, extract::{Query, Path}};
use tokio;
use serde::Deserialize;
use std::sync::Arc;

use hello_axum::{self, app_state::AppState, handlers as r};

#[tokio::main]
async fn main() {
    let state = AppState::new().await;
    let app = r::router(state);

    let listener = tokio::net::TcpListener::bind("0.0.0.0:8888").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
