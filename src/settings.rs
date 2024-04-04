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

// fn get_env_var<T>(env_var_name: &str) -> T
// where
//     T: FromStr,
//     T::Err: Debug,
// {
//     let var = env::var(env_var_name).unwrap();
//     var.parse::<T>().unwrap()
// }