use worker::{Request, Response, Result, RouteContext};

pub fn privacy_handler(_req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let app = ctx.param("app").map(|s| s.as_str()).unwrap_or("");
    Response::ok(render(app)).map(|mut r| {
        let _ = r.headers_mut().set("Content-Type", "text/html; charset=utf-8");
        r
    })
}

struct AppPrivacy {
    name: &'static str,
    ai: &'static str,
    uses_location: bool,
    voice_consent: bool,
}

fn config(app: &str) -> AppPrivacy {
    match app {
        "pixie" => AppPrivacy {
            name: "PixiePocket",
            ai: "the text prompts you enter, and any photos you provide for editing, are sent to OpenAI and Google to generate or edit images",
            uses_location: false,
            voice_consent: false,
        },
        "dreameater" => AppPrivacy {
            name: "Dream Eater",
            ai: "the dream you write is sent to Google Gemini to generate an interpretation, and an illustrative image is generated from it",
            uses_location: true,
            voice_consent: false,
        },
        "doublekick" => AppPrivacy {
            name: "Double Kick",
            ai: "photos of the menus you scan are sent to Google Gemini to read and translate the items",
            uses_location: false,
            voice_consent: false,
        },
        "psywave" => AppPrivacy {
            name: "Psywave",
            ai: "the description or photo you provide is sent to Google Gemini to generate a playlist",
            uses_location: false,
            voice_consent: false,
        },
        "psybeam" => AppPrivacy {
            name: "Psybeam",
            ai: "your speech is streamed directly from your device to OpenAI's real-time translation service over an encrypted connection and spoken back to you; the audio is processed only to translate, is not stored on our servers, and the conversation transcript stays on your device",
            uses_location: true,
            voice_consent: true,
        },
        _ => AppPrivacy {
            name: "This app",
            ai: "the content you submit is sent to our AI providers (OpenAI and Google) only to produce the result you requested",
            uses_location: false,
            voice_consent: false,
        },
    }
}

fn render(app: &str) -> String {
    let c = config(app);
    let location = if c.uses_location {
        "<h2>Location</h2><p>If you grant location access, your approximate location is used on your device to improve the experience (such as suggesting a nearby language) and is not sent to our servers.</p>"
    } else {
        ""
    };
    let consent = if c.voice_consent {
        " Where the app shows a cloud-AI consent control, you can withdraw it at any time in Settings; translation is unavailable until consent is granted."
    } else {
        ""
    };
    format!(
        r#"<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>{name} — Privacy Policy</title>
<style>body{{font-family:-apple-system,BlinkMacSystemFont,system-ui,sans-serif;max-width:680px;margin:40px auto;padding:0 20px;line-height:1.6;color:#1c1c1e}}h1{{font-size:28px}}h2{{font-size:18px;margin-top:28px}}a{{color:#06c}}@media(prefers-color-scheme:dark){{body{{background:#000;color:#e5e5ea}}a{{color:#4da3ff}}}}</style>
</head><body>
<h1>{name} Privacy Policy</h1>
<p><em>Last updated: June 2026</em></p>
<p>{name} is designed to collect as little as possible. This policy explains what is processed and why.</p>
<h2>AI processing</h2>
<p>To provide the app's core feature, {ai}. This data is processed only to produce your result and is not used to train AI models.</p>
<h2>Identity</h2>
<p>{name} works without an account. On first launch we create an anonymous, device-based identity used only to track your credit balance. You may optionally Sign in with Apple to sync your balance across devices, in which case we receive only the identifier Apple provides.</p>
<h2>Purchases</h2>
<p>Credit packs are sold through Apple In-App Purchase and validated via RevenueCat. We receive purchase records (which pack and a transaction identifier) to credit your balance. We never receive your payment-card details.</p>
<h2>On-device data</h2>
<p>Content you create in the app — such as results, history, and transcripts — is stored on your device and is not uploaded to us. You can remove it by deleting the app.</p>
{location}
<h2>What we don't do</h2>
<p>We do not sell your data, show advertising, or use third-party tracking or advertising identifiers.</p>
<h2>Your choices</h2>
<p>You can delete the app at any time to remove on-device data.{consent} For any questions, contact <a href="https://x.com/prblemslver">@prblemslver</a>.</p>
</body></html>"#,
        name = c.name,
        ai = c.ai,
        location = location,
        consent = consent,
    )
}
