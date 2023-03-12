CREATE SCHEMA IF NOT EXISTS games;

CREATE SCHEMA IF NOT EXISTS models;

CREATE TABLE IF NOT EXISTS games.players(
    player_id INT NOT NULL AUTOINCREMENT,
    username TEXT NOT NULL,
    is_bot INT NOT NULL,
    PRIMARY KEY (player_id)
);

CREATE TABLE IF NOT EXISTS games.games(
    game_id INT NOT NULL,
    winner_id INT NOT NULL,
    loser_id INT NOT NULL,
    PRIMARY KEY (game_id),
    FOREIGN KEY (winner_id) REFERENCES players(player_id),
    FOREIGN KEY (loser_id) REFERENCES players(player_id)
);

CREATE TABLE IF NOT EXISTS games.bot_parameters(
    game_id INT NOT NULL,
    is_winner INT NOT NULL,
    parameter TEXT NOT NULL,
    value FLOAT NOT NULL,
    FOREIGN KEY (game_id) REFERENCES games(game_id)
);

CREATE TABLE IF NOT EXISTS games.breaths(
    game_id INT NOT NULL,
    is_winner INT NOT NULL,
    state INT NOT NULL,
    action INT NOT NULL,
    FOREIGN KEY (game_id) REFERENCES games(game_id)
);

CREATE TABLE IF NOT EXISTS models.models(
    model_hash TEXT NOT NULL PRIMARY KEY,
    model_name TEXT NOT NULL,
    model_version TEXT NOT NULL,
    model_card TEXT NOT NULL
);
