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