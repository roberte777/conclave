use crate::errors::{ApiError, Result};
use crate::models::*;
use chrono::Utc;
use sqlx::{Row, SqlitePool};
use uuid::Uuid;

pub async fn create_pool() -> Result<SqlitePool> {
    let pool = SqlitePool::connect("sqlite:conclave.db?mode=rwc").await?;
    run_migrations(&pool).await?;
    Ok(pool)
}

async fn run_migrations(pool: &SqlitePool) -> Result<()> {
    sqlx::migrate!("./migrations")
        .run(pool)
        .await
        .map_err(|e| ApiError::Internal(e.into()))?;
    Ok(())
}

// User operations are handled by Clerk, so no local user functions needed

// Game operations
pub async fn create_game(
    pool: &SqlitePool,
    name: &str,
    starting_life: i32,
    creator_clerk_user_id: &str,
) -> Result<Game> {
    // Check if game name already exists
    let existing =
        sqlx::query("SELECT COUNT(*) as count FROM games WHERE name = ? AND status != 'finished'")
            .bind(name)
            .fetch_one(pool)
            .await?;

    let count: i64 = existing.get("count");
    if count > 0 {
        return Err(ApiError::BadRequest("Game name already exists".to_string()));
    }

    let game = Game {
        id: Uuid::new_v4(),
        name: name.to_string(),
        status: "active".to_string(),
        starting_life,
        created_at: Utc::now(),
        finished_at: None,
    };

    sqlx::query(
        "INSERT INTO games (id, name, status, starting_life, created_at) VALUES (?, ?, ?, ?, ?)",
    )
    .bind(game.id.to_string())
    .bind(&game.name)
    .bind(&game.status)
    .bind(game.starting_life)
    .bind(game.created_at.to_rfc3339())
    .execute(pool)
    .await?;

    // Add the creator as the first player
    join_game(pool, game.id, creator_clerk_user_id).await?;

    Ok(game)
}

pub async fn join_game(pool: &SqlitePool, game_id: Uuid, clerk_user_id: &str) -> Result<Player> {
    // Verify game exists and is active
    let game = get_game_by_id(pool, game_id).await?;
    if game.status == "finished" {
        return Err(ApiError::BadRequest(
            "Cannot join finished game".to_string(),
        ));
    }

    // Check if user is already in game
    let existing = sqlx::query(
        "SELECT COUNT(*) as count FROM players WHERE game_id = ? AND clerk_user_id = ?",
    )
    .bind(game_id.to_string())
    .bind(clerk_user_id)
    .fetch_one(pool)
    .await?;

    let count: i64 = existing.get("count");
    if count > 0 {
        return Err(ApiError::BadRequest("User already in game".to_string()));
    }

    // Check player count
    let players = get_players_in_game(pool, game_id).await?;
    if players.len() >= MAX_PLAYERS_PER_GAME {
        return Err(ApiError::BadRequest(format!(
            "Game is full (max {} players)",
            MAX_PLAYERS_PER_GAME
        )));
    }

    // Determine position for new player
    let position = (players.len() + 1) as i32;

    let player = Player {
        id: Uuid::new_v4(),
        game_id,
        clerk_user_id: clerk_user_id.to_string(),
        current_life: game.starting_life,
        position,
        is_eliminated: false,
    };

    sqlx::query(
        "INSERT INTO players (id, game_id, clerk_user_id, current_life, position, is_eliminated) VALUES (?, ?, ?, ?, ?, ?)",
    )
    .bind(player.id.to_string())
    .bind(player.game_id.to_string())
    .bind(&player.clerk_user_id)
    .bind(player.current_life)
    .bind(player.position)
    .bind(player.is_eliminated)
    .execute(pool)
    .await?;

    Ok(player)
}

pub async fn leave_game(pool: &SqlitePool, game_id: Uuid, clerk_user_id: &str) -> Result<()> {
    // Verify game exists
    let game = get_game_by_id(pool, game_id).await?;
    if game.status == "finished" {
        return Err(ApiError::BadRequest(
            "Cannot leave finished game".to_string(),
        ));
    }

    // Check if user is in game
    let players = get_players_in_game(pool, game_id).await?;
    let player = players
        .iter()
        .find(|p| p.clerk_user_id == clerk_user_id)
        .ok_or(ApiError::PlayerNotFound)?;

    // Remove player
    sqlx::query("DELETE FROM players WHERE id = ?")
        .bind(player.id.to_string())
        .execute(pool)
        .await?;

    // Update positions of remaining players
    let remaining_players = get_players_in_game(pool, game_id).await?;
    for (index, remaining_player) in remaining_players.iter().enumerate() {
        let new_position = (index + 1) as i32;
        sqlx::query("UPDATE players SET position = ? WHERE id = ?")
            .bind(new_position)
            .bind(remaining_player.id.to_string())
            .execute(pool)
            .await?;
    }

    // If no players left, end the game
    if remaining_players.is_empty() {
        end_game(pool, game_id).await?;
    }

    Ok(())
}

pub async fn get_game_by_id(pool: &SqlitePool, game_id: Uuid) -> Result<Game> {
    let row = sqlx::query("SELECT * FROM games WHERE id = ?")
        .bind(game_id.to_string())
        .fetch_optional(pool)
        .await?;

    match row {
        Some(row) => Ok(Game {
            id: Uuid::parse_str(&row.get::<String, _>("id")).unwrap(),
            name: row.get("name"),
            status: row.get("status"),
            starting_life: row.get("starting_life"),
            created_at: chrono::DateTime::parse_from_rfc3339(&row.get::<String, _>("created_at"))
                .unwrap()
                .with_timezone(&Utc),
            finished_at: row.get::<Option<String>, _>("finished_at").map(|s| {
                chrono::DateTime::parse_from_rfc3339(&s)
                    .unwrap()
                    .with_timezone(&Utc)
            }),
        }),
        None => Err(ApiError::GameNotFound),
    }
}

pub async fn get_game_state(pool: &SqlitePool, game_id: Uuid) -> Result<GameState> {
    let game = get_game_by_id(pool, game_id).await?;
    let players = get_players_in_game(pool, game_id).await?;
    let recent_changes = get_recent_life_changes(pool, game_id, 20).await?;

    Ok(GameState {
        game,
        players,
        recent_changes,
    })
}

pub async fn get_players_in_game(pool: &SqlitePool, game_id: Uuid) -> Result<Vec<Player>> {
    let rows = sqlx::query("SELECT * FROM players WHERE game_id = ? ORDER BY position")
        .bind(game_id.to_string())
        .fetch_all(pool)
        .await?;

    let players = rows
        .into_iter()
        .map(|row| Player {
            id: Uuid::parse_str(&row.get::<String, _>("id")).unwrap(),
            game_id: Uuid::parse_str(&row.get::<String, _>("game_id")).unwrap(),
            clerk_user_id: row.get("clerk_user_id"),
            current_life: row.get("current_life"),
            position: row.get("position"),
            is_eliminated: row.get("is_eliminated"),
        })
        .collect();

    Ok(players)
}

pub async fn get_user_games(pool: &SqlitePool, clerk_user_id: &str) -> Result<Vec<GameWithUsers>> {
    let rows = sqlx::query(
        r#"
        SELECT DISTINCT g.*
        FROM games g
        INNER JOIN players p ON g.id = p.game_id
        WHERE p.clerk_user_id = ? AND g.status != 'finished'
        ORDER BY g.created_at DESC
        "#,
    )
    .bind(clerk_user_id)
    .fetch_all(pool)
    .await?;

    let mut games = Vec::new();
    for row in rows {
        let game_id = Uuid::parse_str(&row.get::<String, _>("id")).unwrap();
        let game = Game {
            id: game_id,
            name: row.get("name"),
            status: row.get("status"),
            starting_life: row.get("starting_life"),
            created_at: chrono::DateTime::parse_from_rfc3339(&row.get::<String, _>("created_at"))
                .unwrap()
                .with_timezone(&Utc),
            finished_at: row.get::<Option<String>, _>("finished_at").map(|s| {
                chrono::DateTime::parse_from_rfc3339(&s)
                    .unwrap()
                    .with_timezone(&Utc)
            }),
        };

        // Get users in this game
        let player_rows = sqlx::query(
            "SELECT DISTINCT clerk_user_id FROM players WHERE game_id = ? ORDER BY position",
        )
        .bind(game_id.to_string())
        .fetch_all(pool)
        .await?;

        let users = player_rows
            .into_iter()
            .map(|row| UserInfo {
                clerk_user_id: row.get("clerk_user_id"),
            })
            .collect::<Vec<UserInfo>>();

        games.push(GameWithUsers { game, users });
    }

    Ok(games)
}

pub async fn update_player_life(
    pool: &SqlitePool,
    player_id: Uuid,
    change_amount: i32,
) -> Result<(Player, LifeChange)> {
    // Get current player
    let player_row = sqlx::query("SELECT * FROM players WHERE id = ?")
        .bind(player_id.to_string())
        .fetch_optional(pool)
        .await?;

    let player_row = player_row.ok_or(ApiError::PlayerNotFound)?;

    let mut player = Player {
        id: Uuid::parse_str(&player_row.get::<String, _>("id")).unwrap(),
        game_id: Uuid::parse_str(&player_row.get::<String, _>("game_id")).unwrap(),
        clerk_user_id: player_row.get("clerk_user_id"),
        current_life: player_row.get("current_life"),
        position: player_row.get("position"),
        is_eliminated: player_row.get("is_eliminated"),
    };

    if player.is_eliminated {
        return Err(ApiError::BadRequest(
            "Cannot modify life of eliminated player".to_string(),
        ));
    }

    // Update life
    player.current_life += change_amount;

    // Check if player should be eliminated
    if player.current_life <= 0 {
        player.is_eliminated = true;
        player.current_life = 0;
    }

    // Update player in database
    sqlx::query("UPDATE players SET current_life = ?, is_eliminated = ? WHERE id = ?")
        .bind(player.current_life)
        .bind(player.is_eliminated)
        .bind(player.id.to_string())
        .execute(pool)
        .await?;

    // Record life change
    let life_change = LifeChange {
        id: Uuid::new_v4(),
        game_id: player.game_id,
        player_id: player.id,
        change_amount,
        new_life_total: player.current_life,
        created_at: Utc::now(),
    };

    sqlx::query(
        "INSERT INTO life_changes (id, game_id, player_id, change_amount, new_life_total, created_at) VALUES (?, ?, ?, ?, ?, ?)",
    )
    .bind(life_change.id.to_string())
    .bind(life_change.game_id.to_string())
    .bind(life_change.player_id.to_string())
    .bind(life_change.change_amount)
    .bind(life_change.new_life_total)
    .bind(life_change.created_at.to_rfc3339())
    .execute(pool)
    .await?;

    Ok((player, life_change))
}

pub async fn get_recent_life_changes(
    pool: &SqlitePool,
    game_id: Uuid,
    limit: i32,
) -> Result<Vec<LifeChange>> {
    let rows = sqlx::query(
        "SELECT * FROM life_changes WHERE game_id = ? ORDER BY created_at DESC LIMIT ?",
    )
    .bind(game_id.to_string())
    .bind(limit)
    .fetch_all(pool)
    .await?;

    let changes = rows
        .into_iter()
        .map(|row| LifeChange {
            id: Uuid::parse_str(&row.get::<String, _>("id")).unwrap(),
            game_id: Uuid::parse_str(&row.get::<String, _>("game_id")).unwrap(),
            player_id: Uuid::parse_str(&row.get::<String, _>("player_id")).unwrap(),
            change_amount: row.get("change_amount"),
            new_life_total: row.get("new_life_total"),
            created_at: chrono::DateTime::parse_from_rfc3339(&row.get::<String, _>("created_at"))
                .unwrap()
                .with_timezone(&Utc),
        })
        .collect();

    Ok(changes)
}

pub async fn end_game(pool: &SqlitePool, game_id: Uuid) -> Result<Game> {
    sqlx::query("UPDATE games SET status = 'finished', finished_at = ? WHERE id = ?")
        .bind(Utc::now().to_rfc3339())
        .bind(game_id.to_string())
        .execute(pool)
        .await?;

    get_game_by_id(pool, game_id).await
}

pub async fn get_user_game_history(pool: &SqlitePool, clerk_user_id: &str) -> Result<GameHistory> {
    let rows = sqlx::query(
        r#"
        SELECT DISTINCT g.*
        FROM games g
        INNER JOIN players p ON g.id = p.game_id
        WHERE p.clerk_user_id = ? AND g.status = 'finished'
        ORDER BY g.finished_at DESC
        "#,
    )
    .bind(clerk_user_id)
    .fetch_all(pool)
    .await?;

    let mut games = Vec::new();
    for row in rows {
        let game_id = Uuid::parse_str(&row.get::<String, _>("id")).unwrap();
        let game = Game {
            id: game_id,
            name: row.get("name"),
            status: row.get("status"),
            starting_life: row.get("starting_life"),
            created_at: chrono::DateTime::parse_from_rfc3339(&row.get::<String, _>("created_at"))
                .unwrap()
                .with_timezone(&Utc),
            finished_at: row.get::<Option<String>, _>("finished_at").map(|s| {
                chrono::DateTime::parse_from_rfc3339(&s)
                    .unwrap()
                    .with_timezone(&Utc)
            }),
        };

        let players = get_players_in_game(pool, game_id).await?;
        let winner = players.iter().find(|p| !p.is_eliminated).cloned();

        games.push(GameWithPlayers {
            game,
            players,
            winner,
        });
    }

    Ok(GameHistory { games })
}

pub async fn get_available_games(
    pool: &SqlitePool,
    clerk_user_id: &str,
) -> Result<Vec<GameWithUsers>> {
    let rows = sqlx::query(
        r#"
        SELECT g.*
        FROM games g
        WHERE g.status = 'active'
        AND g.id NOT IN (
            SELECT DISTINCT p.game_id 
            FROM players p 
            WHERE p.clerk_user_id = ?
        )
        ORDER BY g.created_at DESC
        LIMIT 50
        "#,
    )
    .bind(clerk_user_id)
    .fetch_all(pool)
    .await?;

    let mut games = Vec::new();
    for row in rows {
        let game_id = Uuid::parse_str(&row.get::<String, _>("id")).unwrap();
        let game = Game {
            id: game_id,
            name: row.get("name"),
            status: row.get("status"),
            starting_life: row.get("starting_life"),
            created_at: chrono::DateTime::parse_from_rfc3339(&row.get::<String, _>("created_at"))
                .unwrap()
                .with_timezone(&Utc),
            finished_at: row.get::<Option<String>, _>("finished_at").map(|s| {
                chrono::DateTime::parse_from_rfc3339(&s)
                    .unwrap()
                    .with_timezone(&Utc)
            }),
        };

        // Get users in this game
        let player_rows = sqlx::query(
            "SELECT DISTINCT clerk_user_id FROM players WHERE game_id = ? ORDER BY position",
        )
        .bind(game_id.to_string())
        .fetch_all(pool)
        .await?;

        let users = player_rows
            .into_iter()
            .map(|row| UserInfo {
                clerk_user_id: row.get("clerk_user_id"),
            })
            .collect::<Vec<UserInfo>>();

        // Only include games that aren't full
        if users.len() < MAX_PLAYERS_PER_GAME {
            games.push(GameWithUsers { game, users });
        }
    }

    Ok(games)
}
