use axum::{extract::{FromRef, Path, Query}, routing::{get, post}, Router};
use axum::{extract::State};
use axum::{response::{Response, IntoResponse}, Json, http::StatusCode};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use axum::debug_handler;
use std::sync::Arc;
use axum::{
    response::Html,
    http::{Uri, header::{self, HeaderMap, HeaderName}},
};

use crate::settings::Setings;

use crate::{app_state::AppState, models::{Person, NewPerson}};
use crate::errors::AppError;
use crate::version;
use crate::models as m;

pub async fn get_person(Path(user_id): Path<i64>, State(app): State<AppState>) -> Result<ApiResponse<Person>, AppError> {
    let mut s = app.pool.begin().await.unwrap();
    let p: Result<Person, sqlx::Error> = sqlx::query_as!(m::Person, 
        r#"SELECT id, name, surname, age, address, tel from persons WHERE id = $1"#, 
        user_id
    ).fetch_one(&mut *s).await;
    let _ = s.commit().await?;
    Ok(ApiResponse::Json(p?))
}

impl FromRef<AppState> for Setings {
    fn from_ref(app_state: &AppState) -> Setings {
        app_state.settings.clone()
    }
}

#[debug_handler]
pub async fn create_person(State(app): State<AppState>, Json(person): Json<NewPerson>) -> Result<ApiResponse<Person>, AppError> {
    let mut s = app.pool.begin().await.unwrap();
    let p: Result<m::Person, sqlx::Error> = sqlx::query_as!(m::Person, 
        r#"
            INSERT INTO persons (name, surname, age, address, tel) 
            VALUES ($1, $2, $3, $4, $5) 
            RETURNING id, name, surname, age, address, tel"#, 
            person.name, person.surname, person.age, person.address, person.tel
    ).fetch_one(&mut *s).await;
    let _ = s.commit().await?;
    Ok(ApiResponse::Json(p?))
}

// here we show a type that implements Serialize + Send
#[derive(Serialize)]
struct Message {
    message: String
}

#[derive(Serialize)]
pub enum ApiResponse<T>
where
    T: Serialize
{
    OK,
    Json(T),
}

impl<T: Serialize> IntoResponse for ApiResponse<T> {
    fn into_response(self) -> Response {
        match self {
            Self::OK => (StatusCode::OK).into_response(),
            Self::Json(data) => (StatusCode::OK, Json(data)).into_response()
        }
    }
}

pub const BUILD_VERSION: &str = env!("BUILD_VERSION");

pub async fn build_version<'a>() -> ApiResponse<&'a str> {
    ApiResponse::Json(BUILD_VERSION)
}

pub fn router(state: AppState) -> Router {
    Router::new()
    .route("/array_headers", get(array_headers))
    .route("/bytes", get(bytes))
    .route("/empty", get(empty))
    .route("/headers", get(headers))
    .route("/html", get(html))
    .route("/impl_trait", get(impl_trait))
    .route("/json", get(json))
    .route("/json2", get(json2))
    .route("/plain_text_String", get(plain_text_String))
    .route("/plain_text", get(plain_text))
    .route("/status", get(status))
    .route("/version", get(build_version))
    .route("/persons", post(create_person))
    .route("/persons/:user_id", get(get_person))
    .with_state(state)
}


async fn plain_text() -> &'static str {
    "foo"
}

async fn json() -> Json<Value> {
    Json(json!({ "data": 42 }))
}

// `()` gives an empty response
async fn empty() {}

// String will get a `content-type: text/plain; charset=utf-8`
async fn plain_text_String(uri: Uri) -> String {
    format!("Hi from {}", uri.path())
}

// Bytes will get a `application/octet-stream` content-type
async fn bytes() -> Vec<u8> {
    vec![1, 2, 3, 4]
}

// `Json` will get a `application/json` content-type and work with anything that implements `serde::Serialize`
async fn json2() -> Json<Vec<String>> {
    Json(vec!["foo".to_owned(), "bar".to_owned()])
}

// `Html` will get a `text/html` content-type
async fn html() -> Html<&'static str> {
    Html("<p>Hello, World!</p>")
}

// `StatusCode` gives an empty response with that status code
async fn status() -> StatusCode {
    StatusCode::NOT_FOUND
}

// `HeaderMap` gives an empty response with some headers
async fn headers() -> HeaderMap {
    let mut headers = HeaderMap::new();
    headers.insert(header::SERVER, "axum".parse().unwrap());
    headers
}

// An array of tuples also gives headers
async fn array_headers() -> [(HeaderName, &'static str); 2] {
    [
        (header::SERVER, "axum"),
        (header::CONTENT_TYPE, "text/plain")
    ]
}

// Use `impl IntoResponse` to avoid writing the whole type
async fn impl_trait() -> impl IntoResponse {
    [
        (header::SERVER, "axum"),
        (header::CONTENT_TYPE, "text/plain")
    ]
}

