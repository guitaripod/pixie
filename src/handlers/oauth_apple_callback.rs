use worker::{Request, Response, RouteContext, Result};
use crate::error::AppError;
use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct AppleCallbackForm {
    code: String,
    state: String,
    #[serde(rename = "id_token")]
    id_token: Option<String>,
    user: Option<String>,
}

pub async fn apple_auth_callback_page(mut req: Request, _ctx: RouteContext<()>) -> Result<Response> {
    // Apple sends a form POST, not JSON
    let form_data = req.form_data().await
        .map_err(|e| AppError::BadRequest(format!("Failed to parse form data: {}", e)))?;
    
    let code = match form_data.get("code") {
        Some(worker::FormEntry::Field(value)) => value,
        _ => return Err(AppError::BadRequest("Missing or invalid code parameter".to_string()).into()),
    };
    
    let state = match form_data.get("state") {
        Some(worker::FormEntry::Field(value)) => value,
        _ => return Err(AppError::BadRequest("Missing or invalid state parameter".to_string()).into()),
    };
    
    // Build the callback page HTML
    let html = format!(r#"<!DOCTYPE html>
<html>
<head>
    <title>Apple Sign In - OpenAI Image Proxy</title>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Helvetica', 'Arial', sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f7;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
        }}
        .container {{
            background: white;
            padding: 40px;
            border-radius: 12px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            max-width: 500px;
            width: 100%;
        }}
        h1 {{
            color: #1d1d1f;
            margin-bottom: 20px;
            font-size: 28px;
        }}
        .loading {{
            text-align: center;
            color: #86868b;
        }}
        .success {{
            background: #d1fae5;
            color: #065f46;
            padding: 16px;
            border-radius: 8px;
            margin: 20px 0;
        }}
        .error {{
            background: #fee2e2;
            color: #991b1b;
            padding: 16px;
            border-radius: 8px;
            margin: 20px 0;
        }}
        .credentials {{
            background: #f3f4f6;
            padding: 16px;
            border-radius: 8px;
            font-family: monospace;
            word-break: break-all;
            margin: 10px 0;
        }}
        .label {{
            font-weight: 600;
            margin-top: 16px;
            margin-bottom: 8px;
            color: #1d1d1f;
        }}
        .command {{
            background: #1d1d1f;
            color: #f5f5f7;
            padding: 16px;
            border-radius: 8px;
            font-family: monospace;
            margin: 20px 0;
            overflow-x: auto;
        }}
        .instructions {{
            color: #86868b;
            margin-top: 20px;
            line-height: 1.6;
        }}
    </style>
</head>
<body>
    <div class="container">
        <h1>🍎 Apple Sign In</h1>
        <div id="content">
            <div class="loading">
                <p>Completing authentication...</p>
            </div>
        </div>
    </div>
    
    <script>
        const code = "{}";
        const state = "{}";
        
        async function completeAuth() {{
            const content = document.getElementById('content');
            
            try {{
                const response = await fetch('/v1/auth/apple/callback/json', {{
                    method: 'POST',
                    headers: {{
                        'Content-Type': 'application/json',
                    }},
                    body: JSON.stringify({{
                        code: code,
                        state: state,
                        redirect_uri: window.location.origin + '/v1/auth/apple/callback'
                    }})
                }});
                
                let data;
                const contentType = response.headers.get('content-type');
                if (contentType && contentType.includes('application/json')) {{
                    data = await response.json();
                }} else {{
                    // If not JSON, try to get the text for debugging
                    const text = await response.text();
                    console.error('Non-JSON response:', text);
                    throw new Error('Server returned non-JSON response');
                }}
                
                if (response.ok) {{
                    content.innerHTML = `
                        <div class="success">
                            ✅ Authentication successful!
                        </div>
                        
                        <div class="label">Your API Key:</div>
                        <div class="credentials">${{data.api_key}}</div>
                        
                        <div class="label">Your User ID:</div>
                        <div class="credentials">${{data.user_id}}</div>
                        
                        <div class="instructions">
                            <p><strong>Return to your terminal where pixie is waiting for input:</strong></p>
                            <p>1. When prompted for "API Key:", paste: <code>${{data.api_key}}</code></p>
                            <p>2. When prompted for "User ID:", paste: <code>${{data.user_id}}</code></p>
                            <br>
                            <p style="color: #86868b;">The pixie CLI is waiting for you to enter these values in your terminal.</p>
                        </div>
                    `;
                }} else {{
                    throw new Error(data.error?.message || 'Authentication failed');
                }}
            }} catch (error) {{
                content.innerHTML = `
                    <div class="error">
                        ❌ Authentication failed: ${{error.message}}
                    </div>
                    <div class="instructions">
                        <p>Please try again or contact support if the problem persists.</p>
                    </div>
                `;
            }}
        }}
        
        // Start authentication completion
        completeAuth();
    </script>
</body>
</html>"#, 
        code.replace("\"", "&quot;").replace("<", "&lt;").replace(">", "&gt;"),
        state.replace("\"", "&quot;").replace("<", "&lt;").replace(">", "&gt;")
    );
    
    Response::from_html(html)
}