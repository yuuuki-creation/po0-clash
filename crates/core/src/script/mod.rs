//! FlClash's override scripts: `main(config)` rewrites the profile's config, in QuickJS as the Flutter app ran it.

mod console;

use std::time::{Duration, Instant};

use rquickjs::{CatchResultExt, Context, Function, Runtime, Value};

const ENTRY: &str = "main";
/// A profile script finishes in milliseconds; anything still running after this is a loop that would block the
/// profile from ever being applied.
const TIMEOUT: Duration = Duration::from_secs(10);
const MEMORY_LIMIT: usize = 256 * 1024 * 1024;

pub fn evaluate(script: &str, config: &str) -> Result<String, String> {
    evaluate_within(script, config, TIMEOUT)
}

/// Whether the script parses and defines `main`, without running it on a config.
pub fn check(script: &str) -> Result<(), String> {
    with_context(TIMEOUT, |ctx| {
        ctx.eval::<Value, _>(script.as_bytes())
            .catch(&ctx)
            .map_err(describe)?;
        entry(&ctx).map(|_| ())
    })
}

fn with_context<T>(
    timeout: Duration,
    body: impl for<'js> FnOnce(rquickjs::Ctx<'js>) -> Result<T, String>,
) -> Result<T, String> {
    let runtime = Runtime::new().map_err(|error| error.to_string())?;
    runtime.set_memory_limit(MEMORY_LIMIT);
    let deadline = Instant::now() + timeout;
    runtime.set_interrupt_handler(Some(Box::new(move || Instant::now() >= deadline)));
    let context = Context::full(&runtime).map_err(|error| error.to_string())?;
    context.with(|ctx| {
        console::install(&ctx).catch(&ctx).map_err(describe)?;
        body(ctx)
    })
}

/// Evaluated as an expression, since a top-level `const main = …` is a lexical binding rather than a global property.
fn entry<'js>(ctx: &rquickjs::Ctx<'js>) -> Result<Function<'js>, String> {
    ctx.eval(ENTRY.as_bytes())
        .map_err(|_| format!("the script does not define {ENTRY}()"))
}

fn evaluate_within(script: &str, config: &str, timeout: Duration) -> Result<String, String> {
    with_context(timeout, |ctx| {
        ctx.eval::<Value, _>(script.as_bytes())
            .catch(&ctx)
            .map_err(describe)?;
        let entry = entry(&ctx)?;
        let parsed: Value = ctx
            .json_parse(config)
            .catch(&ctx)
            .map_err(|_| "the profile is not valid JSON".to_owned())?;
        let result: Value = entry.call((parsed,)).catch(&ctx).map_err(describe)?;
        let result = match result.as_promise() {
            Some(promise) => {
                promise
                    .finish::<Value>()
                    .catch(&ctx)
                    .map_err(|error| match error {
                        // `finish` gives up once the job queue is empty, which only a promise waiting on a timer or
                        // I/O can cause.
                        rquickjs::CaughtError::Error(rquickjs::Error::WouldBlock) => {
                            format!("{ENTRY}() returned a Promise that did not settle")
                        }
                        other => describe(other),
                    })?
            }
            None => result,
        };
        if result.is_undefined() || result.is_null() {
            return Ok(config.to_owned());
        }
        let json = ctx
            .json_stringify(result)
            .catch(&ctx)
            .map_err(describe)?
            .ok_or_else(|| format!("{ENTRY}() returned a value that is not JSON"))?;
        json.to_string().map_err(|error| error.to_string())
    })
}

fn describe(error: rquickjs::CaughtError<'_>) -> String {
    match error {
        rquickjs::CaughtError::Exception(exception) => {
            let message = exception.message().unwrap_or_else(|| exception.to_string());
            match exception.stack() {
                Some(stack) if !stack.trim().is_empty() => format!("{message}\n{}", stack.trim()),
                _ => message,
            }
        }
        other => other.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use serde_json::{Value as Json, json};

    use super::*;

    fn run(script: &str, config: Json) -> Result<Json, String> {
        evaluate(script, &config.to_string()).map(|out| serde_json::from_str(&out).unwrap())
    }

    #[test]
    fn main_rewrites_the_config() {
        let config = json!({ "mode": "rule", "proxies": [{ "name": "a" }, { "name": "b" }] });
        assert_eq!(
            run(
                "function main(config) { config.mode = 'global'; return config }",
                config.clone()
            )
            .unwrap()["mode"],
            json!("global")
        );
        assert_eq!(
            run("const main = (config) => config", config.clone()).unwrap(),
            config
        );
        assert_eq!(
            run("function main(config) {}", config.clone()).unwrap(),
            config
        );
        assert_eq!(
            run(
                "async function main(config) { config.mode = 'direct'; return config }",
                config.clone()
            )
            .unwrap()["mode"],
            json!("direct")
        );
        let modern = "const flags = new Map([['a', '🇭🇰']]);
            function main(config) {
              console.log('renaming', config.proxies.length);
              return { ...config, names: config.proxies.map((p) => `${flags.get(p.name) ?? ''} ${p.name}`.trim()) };
            }";
        assert_eq!(run(modern, config).unwrap()["names"], json!(["🇭🇰 a", "b"]));
    }

    #[test]
    fn script_failures_are_reported() {
        let thrown = run(
            "function main() { throw new Error('bad profile') }",
            json!({}),
        )
        .unwrap_err();
        assert!(thrown.contains("bad profile"), "{thrown}");
        let syntax = run("function main( {", json!({})).unwrap_err();
        assert!(syntax.contains(":1:"), "{syntax}");
        assert!(
            run("const value = 1", json!({}))
                .unwrap_err()
                .contains("main()")
        );
        let pending = run(
            "function main() { return new Promise(() => {}) }",
            json!({}),
        )
        .unwrap_err();
        assert!(pending.contains("did not settle"), "{pending}");
        let started = Instant::now();
        assert!(
            evaluate_within(
                "function main() { while (true) {} }",
                "{}",
                Duration::from_millis(100)
            )
            .is_err()
        );
        assert!(started.elapsed() < Duration::from_secs(5));
        assert!(check("const main = (config) => config").is_ok());
        assert!(check("const value = 1").is_err());
        assert!(check("function main( {").is_err());
    }
}
