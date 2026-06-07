use worker::*;
use crate::error::AppError;

pub async fn check_and_acquire_lock(app_id: &str, user_id: &str, db: &D1Database) -> Result<()> {
    // Try to insert a lock record - will fail if one already exists
    let result = db
        .prepare("INSERT INTO user_locks (app_id, user_id, acquired_at) VALUES (?, ?, datetime('now'))")
        .bind(&[app_id.into(), user_id.into()])?
        .run()
        .await;

    match result {
        Ok(_) => Ok(()),
        Err(_) => {
            // Lock exists, check if it's stale (older than 60 seconds)
            let stale_check = db
                .prepare("DELETE FROM user_locks WHERE app_id = ? AND user_id = ? AND acquired_at < datetime('now', '-60 seconds')")
                .bind(&[app_id.into(), user_id.into()])?
                .run()
                .await?;

            if stale_check.meta().is_ok() && stale_check.meta().unwrap().is_some() && stale_check.meta().unwrap().unwrap().changes.unwrap_or(0) > 0 {
                // Stale lock removed, try again
                db.prepare("INSERT INTO user_locks (app_id, user_id, acquired_at) VALUES (?, ?, datetime('now'))")
                    .bind(&[app_id.into(), user_id.into()])?
                    .run()
                    .await
                    .map(|_| ())
                    .map_err(|_| worker::Error::from(AppError::RateLimitExceeded))
            } else {
                Err(worker::Error::from(AppError::RateLimitExceeded))
            }
        }
    }
}

pub async fn release_lock(app_id: &str, user_id: &str, db: &D1Database) -> Result<()> {
    db.prepare("DELETE FROM user_locks WHERE app_id = ? AND user_id = ?")
        .bind(&[app_id.into(), user_id.into()])?
        .run()
        .await?;
    Ok(())
}
