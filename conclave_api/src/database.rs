use crate::errors::{ApiError, Result};
use crate::models::*;
use chrono::Utc;
use sqlx::{Row, Sqlite, SqlitePool, Transaction};
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
    let mut tx = pool.begin().await?;
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

    match sqlx::query(
        "INSERT INTO games (id, name, status, starting_life, created_at) VALUES (?, ?, ?, ?, ?)",
    )
    .bind(game.id.to_string())
    .bind(&game.name)
    .bind(&game.status)
    .bind(game.starting_life)
    .bind(game.created_at.to_rfc3339())
    .execute(&mut *tx)
    .await
    {
        Ok(_) => {
            // Add the creator as the first player atomically
            join_game_in_tx(&mut tx, game.id, creator_clerk_user_id).await?;
            tx.commit().await?;
            Ok(game)
        }
        Err(sqlx::Error::Database(db_err)) if db_err.code() == Some("2067".into()) => {
            // SQLite unique constraint violation
            tx.rollback().await?;
            Err(ApiError::BadRequest("Game name already exists".to_string()))
        }
        Err(e) => {
            tx.rollback().await?;
            Err(ApiError::Database(e))
        }
    }
}

// Transaction-safe version of join_game
async fn join_game_in_tx(
    tx: &mut Transaction<'_, Sqlite>,
    game_id: Uuid,
    clerk_user_id: &str,
) -> Result<Player> {
    // Verify game exists and is active
    let game = get_game_by_id_in_tx(tx, game_id).await?;
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
    .fetch_one(&mut **tx)
    .await?;

    let count: i64 = existing.get("count");
    if count > 0 {
        return Err(ApiError::BadRequest("User already in game".to_string()));
    }

    // Get current player count atomically within transaction
    let player_count_result =
        sqlx::query("SELECT COUNT(*) as count FROM players WHERE game_id = ?")
            .bind(game_id.to_string())
            .fetch_one(&mut **tx)
            .await?;

    let player_count: i64 = player_count_result.get("count");
    if player_count >= MAX_PLAYERS_PER_GAME as i64 {
        return Err(ApiError::BadRequest(format!(
            "Game is full (max {MAX_PLAYERS_PER_GAME} players)"
        )));
    }

    // Use atomic position assignment
    let position = (player_count + 1) as i32;

    let player = Player {
        id: Uuid::new_v4(),
        game_id,
        clerk_user_id: clerk_user_id.to_string(),
        current_life: game.starting_life,
        position,
        is_eliminated: false,
    };

    // Database constraint will prevent duplicate positions
    sqlx::query(
        "INSERT INTO players (id, game_id, clerk_user_id, current_life, position, is_eliminated) VALUES (?, ?, ?, ?, ?, ?)",
    )
    .bind(player.id.to_string())
    .bind(player.game_id.to_string())
    .bind(&player.clerk_user_id)
    .bind(player.current_life)
    .bind(player.position)
    .bind(player.is_eliminated)
    .execute(&mut **tx)
    .await?;

    // Initialize commander damage entries for this player
    initialize_commander_damage_for_player_in_tx(tx, game_id, player.id).await?;

    Ok(player)
}

pub async fn join_game(pool: &SqlitePool, game_id: Uuid, clerk_user_id: &str) -> Result<Player> {
    let mut tx = pool.begin().await?;
    let player = join_game_in_tx(&mut tx, game_id, clerk_user_id).await?;
    tx.commit().await?;
    Ok(player)
}

pub async fn leave_game(pool: &SqlitePool, game_id: Uuid, clerk_user_id: &str) -> Result<()> {
    let mut tx = pool.begin().await?;

    // Verify game exists
    let game = get_game_by_id_in_tx(&mut tx, game_id).await?;
    if game.status == "finished" {
        return Err(ApiError::BadRequest(
            "Cannot leave finished game".to_string(),
        ));
    }

    // Find player and get their ID for commander damage cleanup
    let player_result =
        sqlx::query("SELECT id, position FROM players WHERE game_id = ? AND clerk_user_id = ?")
            .bind(game_id.to_string())
            .bind(clerk_user_id)
            .fetch_optional(&mut *tx)
            .await?;

    let player_row = player_result.ok_or(ApiError::PlayerNotFound)?;
    let player_id = Uuid::parse_str(&player_row.get::<String, _>("id")).unwrap();
    let removed_position: i32 = player_row.get("position");

    // Clean up commander damage entries involving this player
    sqlx::query(
        "DELETE FROM commander_damage WHERE game_id = ? AND (from_player_id = ? OR to_player_id = ?)"
    )
    .bind(game_id.to_string())
    .bind(player_id.to_string())
    .bind(player_id.to_string())
    .execute(&mut *tx)
    .await?;

    // Remove the player
    sqlx::query("DELETE FROM players WHERE game_id = ? AND clerk_user_id = ?")
        .bind(game_id.to_string())
        .bind(clerk_user_id)
        .execute(&mut *tx)
        .await?;

    // Shift positions down for players that were after the removed player
    sqlx::query("UPDATE players SET position = position - 1 WHERE game_id = ? AND position > ?")
        .bind(game_id.to_string())
        .bind(removed_position)
        .execute(&mut *tx)
        .await?;

    // No automatic game ending - games only end via explicit EndGame request

    tx.commit().await?;
    Ok(())
}

async fn get_game_by_id_in_tx(tx: &mut Transaction<'_, Sqlite>, game_id: Uuid) -> Result<Game> {
    let row = sqlx::query("SELECT * FROM games WHERE id = ?")
        .bind(game_id.to_string())
        .fetch_optional(&mut **tx)
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
    let commander_damage = get_commander_damage_for_game(pool, game_id).await?;

    Ok(GameState {
        game,
        players,
        recent_changes,
        commander_damage,
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
    let mut tx = pool.begin().await?;

    // Use atomic UPDATE with calculations in SQL
    let update_result = sqlx::query(
        r#"
        UPDATE players 
        SET current_life = current_life + ?
        WHERE id = ?
        RETURNING *
        "#,
    )
    .bind(change_amount)
    .bind(player_id.to_string())
    .fetch_optional(&mut *tx)
    .await?;

    let player_row = update_result.ok_or(ApiError::PlayerNotFound)?;

    let updated_player = Player {
        id: Uuid::parse_str(&player_row.get::<String, _>("id")).unwrap(),
        game_id: Uuid::parse_str(&player_row.get::<String, _>("game_id")).unwrap(),
        clerk_user_id: player_row.get("clerk_user_id"),
        current_life: player_row.get("current_life"),
        position: player_row.get("position"),
        is_eliminated: player_row.get("is_eliminated"),
    };

    // Record life change atomically
    let life_change = LifeChange {
        id: Uuid::new_v4(),
        game_id: updated_player.game_id,
        player_id: updated_player.id,
        change_amount,
        new_life_total: updated_player.current_life,
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
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;
    Ok((updated_player, life_change))
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
        let winner = players.iter().max_by_key(|p| p.current_life).cloned();

        games.push(GameWithPlayers {
            game,
            players,
            winner,
        });
    }

    Ok(GameHistory { games })
}

// Commander Damage operations
async fn initialize_commander_damage_for_player_in_tx(
    tx: &mut Transaction<'_, Sqlite>,
    game_id: Uuid,
    player_id: Uuid,
) -> Result<()> {
    // Get all existing players in the game
    let existing_players = sqlx::query("SELECT id FROM players WHERE game_id = ? AND id != ?")
        .bind(game_id.to_string())
        .bind(player_id.to_string())
        .fetch_all(&mut **tx)
        .await?;

    let now = Utc::now().to_rfc3339();

    // Create commander damage entries for new player TO all existing players (Commander 1 only)
    for existing_player_row in &existing_players {
        let existing_player_id =
            Uuid::parse_str(&existing_player_row.get::<String, _>("id")).unwrap();

        // From new player to existing player
        sqlx::query(
            "INSERT INTO commander_damage (id, game_id, from_player_id, to_player_id, commander_number, damage, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
        )
        .bind(Uuid::new_v4().to_string())
        .bind(game_id.to_string())
        .bind(player_id.to_string())
        .bind(existing_player_id.to_string())
        .bind(1) // Commander 1
        .bind(0) // Initial damage
        .bind(&now)
        .bind(&now)
        .execute(&mut **tx)
        .await?;

        // From existing player to new player
        sqlx::query(
            "INSERT INTO commander_damage (id, game_id, from_player_id, to_player_id, commander_number, damage, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
        )
        .bind(Uuid::new_v4().to_string())
        .bind(game_id.to_string())
        .bind(existing_player_id.to_string())
        .bind(player_id.to_string())
        .bind(1) // Commander 1
        .bind(0) // Initial damage
        .bind(&now)
        .bind(&now)
        .execute(&mut **tx)
        .await?;
    }

    Ok(())
}

pub async fn update_commander_damage(
    pool: &SqlitePool,
    game_id: Uuid,
    from_player_id: Uuid,
    to_player_id: Uuid,
    commander_number: i32,
    new_damage: i32,
) -> Result<CommanderDamage> {
    let mut tx = pool.begin().await?;

    // Validate damage amount
    if new_damage < 0 {
        return Err(ApiError::BadRequest(
            "Commander damage cannot be negative".to_string(),
        ));
    }
    if new_damage > 999 {
        return Err(ApiError::BadRequest(
            "Commander damage cannot exceed 999".to_string(),
        ));
    }

    // Validate commander number
    if commander_number != 1 && commander_number != 2 {
        return Err(ApiError::BadRequest(
            "Commander number must be 1 or 2".to_string(),
        ));
    }

    // Validate players exist and are in the game
    let from_player_exists =
        sqlx::query("SELECT COUNT(*) as count FROM players WHERE id = ? AND game_id = ?")
            .bind(from_player_id.to_string())
            .bind(game_id.to_string())
            .fetch_one(&mut *tx)
            .await?
            .get::<i64, _>("count")
            > 0;

    let to_player_exists =
        sqlx::query("SELECT COUNT(*) as count FROM players WHERE id = ? AND game_id = ?")
            .bind(to_player_id.to_string())
            .bind(game_id.to_string())
            .fetch_one(&mut *tx)
            .await?
            .get::<i64, _>("count")
            > 0;

    if !from_player_exists || !to_player_exists {
        return Err(ApiError::BadRequest(
            "One or both players not found in game".to_string(),
        ));
    }

    // Prevent self-damage
    if from_player_id == to_player_id {
        return Err(ApiError::BadRequest(
            "Players cannot deal commander damage to themselves".to_string(),
        ));
    }

    let now = Utc::now().to_rfc3339();

    // Update or insert commander damage entry
    let result = sqlx::query(
        r#"
        INSERT INTO commander_damage (id, game_id, from_player_id, to_player_id, commander_number, damage, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(game_id, from_player_id, to_player_id, commander_number) 
        DO UPDATE SET damage = ?, updated_at = ?
        RETURNING *
        "#
    )
    .bind(Uuid::new_v4().to_string())
    .bind(game_id.to_string())
    .bind(from_player_id.to_string())
    .bind(to_player_id.to_string())
    .bind(commander_number)
    .bind(new_damage)
    .bind(&now)
    .bind(&now)
    .bind(new_damage)
    .bind(&now)
    .fetch_one(&mut *tx)
    .await?;

    let commander_damage = CommanderDamage {
        id: Uuid::parse_str(&result.get::<String, _>("id")).unwrap(),
        game_id: Uuid::parse_str(&result.get::<String, _>("game_id")).unwrap(),
        from_player_id: Uuid::parse_str(&result.get::<String, _>("from_player_id")).unwrap(),
        to_player_id: Uuid::parse_str(&result.get::<String, _>("to_player_id")).unwrap(),
        commander_number: result.get("commander_number"),
        damage: result.get("damage"),
        created_at: chrono::DateTime::parse_from_rfc3339(&result.get::<String, _>("created_at"))
            .unwrap()
            .with_timezone(&Utc),
        updated_at: chrono::DateTime::parse_from_rfc3339(&result.get::<String, _>("updated_at"))
            .unwrap()
            .with_timezone(&Utc),
    };

    tx.commit().await?;
    Ok(commander_damage)
}

pub async fn get_commander_damage_for_game(
    pool: &SqlitePool,
    game_id: Uuid,
) -> Result<Vec<CommanderDamage>> {
    let rows = sqlx::query("SELECT * FROM commander_damage WHERE game_id = ? ORDER BY from_player_id, to_player_id, commander_number")
        .bind(game_id.to_string())
        .fetch_all(pool)
        .await?;

    let commander_damages = rows
        .into_iter()
        .map(|row| CommanderDamage {
            id: Uuid::parse_str(&row.get::<String, _>("id")).unwrap(),
            game_id: Uuid::parse_str(&row.get::<String, _>("game_id")).unwrap(),
            from_player_id: Uuid::parse_str(&row.get::<String, _>("from_player_id")).unwrap(),
            to_player_id: Uuid::parse_str(&row.get::<String, _>("to_player_id")).unwrap(),
            commander_number: row.get("commander_number"),
            damage: row.get("damage"),
            created_at: chrono::DateTime::parse_from_rfc3339(&row.get::<String, _>("created_at"))
                .unwrap()
                .with_timezone(&Utc),
            updated_at: chrono::DateTime::parse_from_rfc3339(&row.get::<String, _>("updated_at"))
                .unwrap()
                .with_timezone(&Utc),
        })
        .collect();

    Ok(commander_damages)
}

pub async fn toggle_partner(
    pool: &SqlitePool,
    game_id: Uuid,
    player_id: Uuid,
    enable_partner: bool,
) -> Result<()> {
    let mut tx = pool.begin().await?;

    // Validate player exists in game
    let player_exists =
        sqlx::query("SELECT COUNT(*) as count FROM players WHERE id = ? AND game_id = ?")
            .bind(player_id.to_string())
            .bind(game_id.to_string())
            .fetch_one(&mut *tx)
            .await?
            .get::<i64, _>("count")
            > 0;

    if !player_exists {
        return Err(ApiError::BadRequest("Player not found in game".to_string()));
    }

    if enable_partner {
        // Create Commander 2 entries for this player with all other players
        let other_players = sqlx::query("SELECT id FROM players WHERE game_id = ? AND id != ?")
            .bind(game_id.to_string())
            .bind(player_id.to_string())
            .fetch_all(&mut *tx)
            .await?;

        let now = Utc::now().to_rfc3339();

        for other_player_row in other_players {
            let other_player_id =
                Uuid::parse_str(&other_player_row.get::<String, _>("id")).unwrap();

            // From this player to other player (Commander 2)
            sqlx::query(
                "INSERT OR IGNORE INTO commander_damage (id, game_id, from_player_id, to_player_id, commander_number, damage, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
            )
            .bind(Uuid::new_v4().to_string())
            .bind(game_id.to_string())
            .bind(player_id.to_string())
            .bind(other_player_id.to_string())
            .bind(2) // Commander 2
            .bind(0) // Initial damage
            .bind(&now)
            .bind(&now)
            .execute(&mut *tx)
            .await?;

            // From other player to this player (Commander 2)
            sqlx::query(
                "INSERT OR IGNORE INTO commander_damage (id, game_id, from_player_id, to_player_id, commander_number, damage, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
            )
            .bind(Uuid::new_v4().to_string())
            .bind(game_id.to_string())
            .bind(other_player_id.to_string())
            .bind(player_id.to_string())
            .bind(2) // Commander 2
            .bind(0) // Initial damage
            .bind(&now)
            .bind(&now)
            .execute(&mut *tx)
            .await?;
        }
    } else {
        // Remove all Commander 2 entries involving this player
        sqlx::query(
            "DELETE FROM commander_damage WHERE game_id = ? AND commander_number = 2 AND (from_player_id = ? OR to_player_id = ?)"
        )
        .bind(game_id.to_string())
        .bind(player_id.to_string())
        .bind(player_id.to_string())
        .execute(&mut *tx)
        .await?;
    }

    tx.commit().await?;
    Ok(())
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
