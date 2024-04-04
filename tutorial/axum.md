# Table of contents
- [Table of contents](#table-of-contents)
- [Intro](#intro)
  - [Tokio stack](#tokio-stack)
  - [Demo tokio server](#demo-tokio-server)
  - [Demo tokio client](#demo-tokio-client)
  - [Tower](#tower)
- [Routing](#routing)
    - [Example of route defenition](#example-of-route-defenition)
- [Routing to infallible handlers](#routing-to-infallible-handlers)
- [Routing to fallible handlers](#routing-to-fallible-handlers)
- [Handling errors](#handling-errors)
      - [Example](#example)
- [impl IntoResponse](#impl-intoresponse)
- [`Result` type for returns](#result-type-for-returns)
- [State](#state)
- [Sub state](#sub-state)
- [Router fallback](#router-fallback)
- [Extractors](#extractors)
      - [Order of extractors](#order-of-extractors)
      - [Optional extractors](#optional-extractors)
  - [Common extractors](#common-extractors)
    - [`axum::extract::State` extractor](#axumextractstate-extractor)
    - [`axum::Json` extractor](#axumjson-extractor)
    - [`axum::extract::Path` extractor](#axumextractpath-extractor)
    - [`axum::extract::Query`](#axumextractquery)
  - [`axum-extra` extractors](#axum-extra-extractors)
    - [`TypedHeader` extractor](#typedheader-extractor)
    - [`CookieJar` extractor](#cookiejar-extractor)
  - [Custom extractors](#custom-extractors)
    - [`FromRequest`](#fromrequest)
    - [`FromRequestParts`](#fromrequestparts)
- [Middleware](#middleware)
      - [Example](#example-1)
  - [`Tower`'s middelware](#towers-middelware)
  - [Ordering](#ordering)
- [Static files](#static-files)

<br>

# Intro
**Axum** is built on **Tokio** and inherits its capabilities in handling *async tasks* and *I/O operations*.<br>
**Axum doesn't** have its own middleware system but instead uses `tower::Service` and thus can share **middleware** with applications written using **hyper** or **tonic**.<br>

<br>

## Tokio stack
**Tokio stack** is **reliable**, **easy**, **fast** and **flexible**.

<br>

The **Tokio stack** includes:
- **Runtime**
  - the **foundation of asynchronous applications**;
  - includes:
    - **I/O**
    - **timer**
    - **filesystem**
    - **synchronization**
    - **scheduling facilities**
- **Tower**
  - provides **building blocks** for writing **network applications**: **clients** and **servers**;
  - **protocol agnostic**, but designed around a **request/response pattern**;
  - includes capabilities for
    - **load balancing**;
    - **retrying**;
    - **filtering**;
    - **rate limitimg**;
    - **timeouts**;
- **Hyper**
  - **low-level library** for building HTTP clients and servers;
  - supports both **HTTP/1** and **HTTP/2** protocols;
- **Tonic**
  - **low-level library** for building gRPC clients and servers;
- **Mio**
  - **event driven API** on the top of OS evented I/O API;
- **Tracing**
  - provides structured, event-based, data collection and logging.
- **Bytes**
  - provides a rich set of utilities for manipulating byte arrays.

<br>

`Cargo.toml` **example**:

```toml
tokio = {version = "1.37.0", features = [ "full"] }
tower = {version = "0.4.13", features = [ "full"] }
hyper = {version = "1.2.0", features = [ "full"] }
tonic = {version = "0.11.0" }
```

<br>

## Demo tokio server
- `src/main.rs`

```rust
use tokio;

#[tokio::main]
async fn main() {
    let listener = tokio::net::TcpListener::bind("localhost:3000").await.unwrap();
    loop {
        let (socket, _address) = listener.accept().await.unwrap();
        tokio::spawn(async move { 
            process(socket).await;
        }); 
    }
}
async fn process(socket: tokio::net::TcpStream) {
    println!("process socket");
}
```

<br>

## Demo tokio client
```rust

```

<br>

## Tower
**Tower** provides a **core** abstraction, [Service](https://docs.rs/tower/latest/tower/trait.Service.html) trait, and **additional** abstraction, [Layer](https://docs.rs/tower/latest/tower/trait.Layer.html) trait and the [ServiceBuilder](https://docs.rs/tower/latest/tower/struct.ServiceBuilder.html) type:
- A `Service` can be thought of as an **asynchronous function** from a `Request` type to a `Result<Response, Error>` type:
```rust
async fn abc(Request) -> Result<Response, Error>
```
- A `Layer` is a function taking a `Service` of **one** type and returning a `Service` of a **different** type.<br>
- The `ServiceBuilder` type is used to add **middleware to a service** by composing it with multiple `Layer`s. <br>

<br>

# Routing
**Routing** is a **mapping between** incoming **HTTP requests** to specific **handlers** based on *URL* and *HTTP method*. **Handlers** must be registered in `axum::Router`.<br>
**Handler** is an async function that **processes the request** and return anything that `axum` can convert into **HTTP response**, so **handler** must return:
- [axum::response::Response](https://docs.rs/axum/latest/axum/response/type.Response.html) *type*

**OR**

- any type that implements [axum::response::IntoResponse](https://docs.rs/axum/latest/axum/response/trait.IntoResponse.html) *trait*.

<br>

This is **already implemented** for *most primitive types* (`Result`, `String`, `str`, `Vec`) and *all of* `axum`'s *types*.

<br>

### Example of route defenition
- `Cargo.toml`
```toml
[dependencies]
axum = { version = "0.7.4", features = ["macros"]}
axum-extra = { version = "0.9.3", features = ["typed-header"]}
env_logger = { version = "0.11.2" }
log = { version =  "0.4.20" }
serde = { version = "1.0.196", features = ["derive"] }
serde_json = { version = "1.0.113" }
sqlx = { version = "0.7.3" , default_features = false, features = ["postgres", "runtime-tokio-native-tls", "macros", "chrono"]}
tokio = { version = "1", features = ["full"] }
```
- `src/main.rs`
```rust
use axum::{
    self,
    extract::{Path, Query, State},
    http::{header, Uri},
    response::{Html, IntoResponse, Response},
    routing::get,
    Json, Router,
};
use serde_json::{json, Value};
use tokio;

#[tokio::main]
async fn main() {
    let app = router();

    let listener = tokio::net::TcpListener::bind("0.0.0.0:8888").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

pub fn router() -> Router {
    Router::new()
        .route("/bytes", get(bytes))
        .route("/empty", get(empty))
        .route("/impl_trait", get(impl_trait))
        .route("/json", get(json))
        .route("/plain_text/str", get(plain_text_str))
        .route("/plain_text/string", get(plain_text_string))
}

// Bytes will get a `application/octet-stream` content-type
async fn bytes() -> Vec<u8> {
    vec![1, 2, 3, 4]
}

// `()` gives an empty response
async fn empty() {}

// Use `impl IntoResponse` to avoid writing the whole type
async fn impl_trait() -> impl IntoResponse {
    [
        (header::SERVER, "axum"),
        (header::CONTENT_TYPE, "text/plain"),
    ]
}

// `Json` will get a `application/json` content-type and work with anything that implements `serde::Serialize`
async fn json() -> Json<Value> {
    Json(json!({ "data": 42 }))
}

// str will get a `content-type: text/plain; charset=utf-8`
async fn plain_text_str() -> &'static str {
    "foo"
}

// String will get a `content-type: text/plain; charset=utf-8`
async fn plain_text_string(uri: Uri) -> String {
    format!("Hi from {}", uri.path())
}
```

<br>

# Routing to infallible handlers
`Axum` **requires** all handlers to be **infallible**, meaning that they don't run into errors while they are running.<br>
That means the only way a handler can send error responses is to return a `Result::Err` variant.<br>
**Infallible handlers** are registered in `Router` by `.route()` method, example:
```rust
Router::new().route("/", get(some_infallible_handler))
```

When `axum` server **fails** it return a **no-content response**. To prevent server from returning a no-content response, we need to handle the errors directly through pattern matching.

<br>

# Routing to fallible handlers
If handler can run into error at runtime and you don't know all errors handler can run into you may skip explicit error handlig for such errors and just register such handler in Router as fallible handler.<br>
We cannot route to `some_fallible_handler` directly since it might **fail**. So, we have to use `handle_error` which converts its errors into responses.<br>
```rust
let app = Router::new().route_service("/", HandleError::new(some_fallible_handler, handle_error));

async fn handle_error(err: anyhow::Error) -> (StatusCode, String) {
    (
        StatusCode::INTERNAL_SERVER_ERROR,
        format!("Something went wrong: {err}"),
    )
}
```

<br>

# Handling errors
**Errors** are useful for letting the client know what went wrong with its request.<br>
We need to impl `IntoResponse` trait for **custom** error types to let `axum` know how to deel with them.<br>

<br>

#### Example
```rust
use sqlx::error::Error as SqlxErr;
use axum::http::StatusCode;
use axum::{response::{Response, IntoResponse}};
use std::error::Error;
use std::fmt;

#[derive(Debug)]
pub enum AppError {
    DB(String),
    IO(String),
    Serialize(String),
    UnprocessableInput(String)
}

impl Error for AppError {}

impl fmt::Display for AppError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            AppError::DB(e) => write!(f, "DB error"),
            AppError::IO(e) => write!(f, "IO error"),
            AppError::Serialize(e) => write!(f, "Serialize/Deserialize error"),
            AppError::UnprocessableInput(e) => write!(f, "Unprocessable input"),
        }
    }
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        match self {
            AppError::DB(e) => (StatusCode::UNPROCESSABLE_ENTITY, e).into_response(),
            AppError::IO(e) => (StatusCode::NOT_FOUND, e).into_response(),
            AppError::Serialize(e) => (StatusCode::BAD_REQUEST, e).into_response(),
            AppError::UnprocessableInput(e) => (StatusCode::UNPROCESSABLE_ENTITY, e).into_response(),
        }
    }
}

/// This enables sqlx errors to be converted to AppError using `?` operator.
impl From<SqlxErr> for AppError {
    fn from(e: SqlxErr) -> Self {
        AppError::DB(e.to_string())
    }
}
```

<br>

# impl IntoResponse
It's possible to implement `IntoResponse` for an **enum** or a **struct** that we can then use as the **return type**.<br>

- example of **handler**:
```rust
pub const BUILD_VERSION: &str = env!("BUILD_VERSION");

pub async fn build_version<'a>() -> ApiResponse<&'a str> {
    ApiResponse::Json(BUILD_VERSION)
}
```
- type `ApiResponse`:
```rust
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
```

<br>

# `Result` type for returns
- example of **handler**:
```rust
pub async fn get_person(Path(user_id): Path<i64>, State(app): State<AppState>) -> Result<ApiResponse<Person>, AppError> {
    let mut s = app.pool.begin().await.unwrap();
    let p: Result<Person, sqlx::Error> = sqlx::query_as!(m::Person, 
        r#"SELECT id, name, surname, age, address, tel from persons WHERE id = $1"#, 
        user_id
    ).fetch_one(&mut *s).await;
    let _ = s.commit().await?;
    Ok(ApiResponse::Json(p?))
}
```

<br>

# State
**State** in `axum` is a way to **share data** at whole app level, for example, **state** can store **db pool** or something like this.<br>
To **add state** to `Router` there is `.with_state()` method.<br>

- `AppState` type:
```rust
use sqlx::postgres::{PgPoolOptions, PgPool};

use crate::settings::Setings;

#[derive(Clone)]
pub struct AppState {
    pub settings: Setings,
    pub pool: PgPool,
}

impl AppState {
    pub async fn new() -> Self {
        let s = Setings::new();
        log::debug!("{}", &s.pg_url.to_string());
        Self {
            pool: PgPoolOptions::new().max_connections(10).connect(&s.pg_url.to_string()).await.unwrap(),
            settings: s,
        }
    }
}
```

- `settings.rs`
```rust
use std::env;

#[derive(Clone)]
pub struct Postgresql {
    user: String,
    password: String,
    db: String,
    port: u16,
    host: String,
}

impl ToString for Postgresql {
    fn to_string(&self) -> String {
        String::from(format!("postgres://{0}:{1}@{2}:{3}/{4}", self.user, self.password, self.host, self.port, self.db))
    }
}

impl Postgresql {
    pub fn new() -> Self {
        Self {
            user: env::var("PG_USER").expect("PG_USER is not set."),
            password: env::var("PG_PASSWORD").expect("PG_PASSWORD is not set."),
            db: env::var("PG_DB").expect("PG_DB is not set."),
            port: env::var("PG_PORT").expect("PG_PORT is not set.").parse::<u16>().unwrap(),
            host: env::var("PG_HOST").expect("PG_HOST is not set."),
        }
    }
}

#[derive(Clone)]
pub struct Setings {
    pub pg_url: Postgresql,
}

impl Setings {
    pub fn new() -> Self {
        Self {
            pg_url: Postgresql::new(),
        }
    }
}
```

- init `AppState`: 
```rust 
use axum::{self, Router, routing::get, response::{Html, IntoResponse}, extract::{Query, Path}};
use tokio;
use serde::Deserialize;
use std::sync::Arc;

use mylib::{self, app_state::AppState, handlers as r};

#[tokio::main]
async fn main() {
    let state = AppState::new().await;
    let app =     Router::new()
            .route("/bytes", get(bytes))
            .route("/empty", get(empty))
            .route("/impl_trait", get(impl_trait))
            .route("/json", get(json))
            .route("/plain_text/str", get(plain_text_str))
            .route("/plain_text/string", get(plain_text_string))
        .with_state(state)

    let listener = tokio::net::TcpListener::bind("0.0.0.0:8888").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
```

<br>

Instead of using `#[derive(Clone)]` we can also wrap the **app state** in `Arc` and `State<Arc<AppState>>` in handlers, example:
```rust
let state = Arc::new(AppState::new().await);
```

<br>

# Sub state
It is possible derive **sub state** from an **app state**.
The `AppState` type has attribute `settings` of type `Setings`. We can extract inside handler only `settings`, not whole `AppState` instance.<br>
There is `axum::extract::FromRef` type for it:
```rust
#[derive(Clone)]
pub struct Setings {
    pub pg_url: Postgresql,
}

impl FromRef<AppState> for Setings {
    fn from_ref(app_state: &AppState) -> Setings {
        app_state.settings.clone()
    }
}
```

<br>

# Router fallback
If router cannot find appropriate handler to process incoming request it sends `404` HTTP status code.<br>
The `Router`'s `.fallback()` method allows to register custom **fallback** function that will genereate response for such situations.<br>

```rust
use axum::routing::get;

pub async fn hello() -> String {
    "Hello, World!".into()
}

pub async fn fallback(uri: axum::http::Uri) -> impl axum::response::IntoResponse {
    (axum::http::StatusCode::NOT_FOUND, format!("No route {}", uri))
}

#[tokio::main]
pub async fn main () {
    let app = axum::Router::new().fallback(fallback).route("/", get(hello));
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
```

<br>

# Extractors
**Extractors** in `axum` **extract things** from **HTTP request**.<br>
There are *HTTP request* **headers** **extractors** and *HTTP request* **body** **extractors**. Note that *HTTP request headers extractors* **don't consume** the HTTP request **body**.<br>

#### Order of extractors
**Order of extractors matters**. Extractors always run in the order of the function parameters that is **from left to right**.<br>
The **request body** is an asynchronous stream that **can only be consumed once**. Therefore you can only have **one** extractor that consumes the **request body**.<br>
`axum` enforces this by requiring such extractors to be the **last argument** your handler takes.<br>

#### Optional extractors
All extractors **reject** the request if it **doesn’t match**. If you wish to make an extractor **optional** you can wrap it in `Option`.<br>

<br>

## Common extractors
[Common extractors](https://docs.rs/axum/latest/axum/extract/index.html)

<br>

### `axum::extract::State` extractor
There is `State` extractor to access to **state** in handlers:
- `State` extractor:
```rust
pub async fn create_person(State(app): State<AppState>, Json(person): Json<NewPerson>) -> Result<ApiResponse<Person>, AppError> { ... }
```

<br>

### `axum::Json` extractor
There is `Json` extractor to **consume** *HTTP request* **body** by extracting a *JSON request* **body**:
```rust
pub async fn create_person(Json(person): Json<NewPerson>) -> Result<ApiResponse<Person>, AppError> { ... }
```

<br>

### `axum::extract::Path` extractor
There is `Path` extractor to **extract** values from *URL*:
```rust
async fn hello_world(
    Path(id): Path<i32>
) -> impl IntoResponse {
    let string = format!("Hello world {}!", id);

    (StatusCode::OK, string)
}
```

<br>

### `axum::extract::Query`

<br>

## `axum-extra` extractors
[`axum_extra` extractors](https://docs.rs/axum-extra/latest/axum_extra/).<br>

<br>

- example of `Cargo.toml`:
```toml
axum-extra = { version = "0.9.3", features = ["typed-header"]}
```

<br>

### `TypedHeader` extractor
```rust
use axum_extra::{TypedHeader, headers::Origin};
async fn example(TypedHeader(origin): TypedHeader<Origin>) {}
```

<br>

### `CookieJar` extractor

<br>

## Custom extractors
You can also define your own extractors by implementing either `FromRequestParts` or `FromRequest`:
- if extractor **doesn’t** need access to the *request* **body** it must implement `FromRequestParts`;
- If extractor **needs** to **consume** the *request* **body** you must implement `FromRequest`;

<br>

### `FromRequest`
```rust
use axum::{
    async_trait,
    extract::{Request, FromRequest},
    response::{Response, IntoResponse},
    body::{Bytes, Body},
    http::{
        header::{HeaderValue, USER_AGENT},
    },
};

struct ValidatedBody(Bytes);

impl<S> FromRequest<S> for ValidatedBody
where
    Bytes: FromRequest<S>,
    S: Send + Sync,
{
    type Rejection = Response;

    async fn from_request(req: Request, state: &S) -> Result<Self, Self::Rejection> {
        let body = Bytes::from_request(req, state)
            .await
            .map_err(IntoResponse::into_response)?;

        // do validation...

        Ok(Self(body))
    }
}

async fn handler(ValidatedBody(body): ValidatedBody) {
    // ...
}
```

<br>

### `FromRequestParts`
```rust
use axum::{
    async_trait,
    extract::FromRequestParts,
    routing::get,
    Router,
    http::{
        StatusCode,
        header::{HeaderValue, USER_AGENT},
        request::Parts,
    },
};

struct ExtractUserAgent(HeaderValue);

impl<S> FromRequestParts<S> for ExtractUserAgent
where
    S: Send + Sync,
{
    type Rejection = (StatusCode, &'static str);

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        if let Some(user_agent) = parts.headers.get(USER_AGENT) {
            Ok(ExtractUserAgent(user_agent.clone()))
        } else {
            Err((StatusCode::BAD_REQUEST, "`User-Agent` header is missing"))
        }
    }
}

async fn handler(ExtractUserAgent(user_agent): ExtractUserAgent) {
    // ...
}
```

<br>

# Middleware
**Middleware** is a function that runs **before** the **handler**.<br>
`axum` allows add **middleware** anywhere:
- to **entire router** with `Router::layer` and `Router::route_layer`;
- to **router's method** with `MethodRouter::layer` and `MethodRouter::route_layer`;
- to **individual handlers** with `Handler::layer`;

<br>

#### Example
- define **custom middleware**:
```rust
async fn check_hello_world<B>(
    req: Request<B>,
    next: Next<B>
) -> Result<Response, StatusCode> {
    // requires the http crate to get the header name
    if req.headers().get(CONTENT_TYPE).unwrap() != "application/json" {
        return Err(StatusCode::BAD_REQUEST);
    }

    Ok(next.run(req).await)
}
```
- **wrap** `middleware::from_fn` middleware and **add** it to **router**:
```rust
Router::new()
    .route("/", get(hello_world))
    .layer(middleware::from_fn(check_hello_world))
```

<br>

We can also add middleware that uses **state** using `middleware::from_fn_with_state` function:
```rust
 Router::new()
    .route("/", get(hello_world))
    .layer(middleware::from_fn_with_state(check_hello_world))
    .with_state(state)
```

<br>

## `Tower`'s middelware
`axum` is compatible with `tower` crate and **any** `tower`'s **middleware can be used** in `axum`.<br>

`Tower`s middleware to **compress** responses:
```rust
use tower_http::compression::CompressionLayer;
use axum::{routing::get, Router};

fn init_router() -> Router {
    Router::new().route("/", get(hello_world)).layer(CompressionLayer::new)
}
```

<br>

## Ordering
Consider example:
```rust
use axum::{routing::get, Router};

async fn handler() {}

let app = Router::new()
    .route("/", get(handler))
    .layer(layer_one)
    .layer(layer_two)
    .layer(layer_three);
```

<br>

Here **each new layer wraps all previous layers** and the order of executing of middlewares is folowing:
```
        requests
           |
           v
+----- layer_three -----+
| +---- layer_two ----+ |
| | +-- layer_one --+ | |
| | |               | | |
| | |    handler    | | |
| | |               | | |
| | +-- layer_one --+ | |
| +---- layer_two ----+ |
+----- layer_three -----+
           |
           v
        responses
```

<br>

It’s **recommended** to add **multiple middleware** using `tower::ServiceBuilder`:
```rust
use tower::ServiceBuilder;
use axum::{routing::get, Router};

async fn handler() {}

let app = Router::new()
    .route("/", get(handler))
    .layer(
        ServiceBuilder::new()
            .layer(layer_one)
            .layer(layer_two)
            .layer(layer_three),
    );
```

However **this impacts ordering**: `layer_one` would receive the **request** **first**, then `layer_two`, then `layer_three`, then `handler`, and then the **response** would bubble back up through `layer_three`, then `layer_two`, and finally `layer_one`.<br>

<br>

# Static files
To handle **static-generated files**, there are `.nest_service()` **method** and `ServeDir`/`ServeFile` **types**:
```rust
use tower_http::services::{ServeDir, ServeFile};

Router::new().nest_service(
    "/", ServeDir::new("dist").not_found_service(ServeFile::new("dist/index.html")),
);
```