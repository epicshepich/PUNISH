CREATE SCHEMA IF NOT EXISTS models;

CREATE SCHEMA IF NOT EXISTS games;

CREATE TABLE IF NOT EXISTS models.models(
    model_hash VARCHAR(32) NOT NULL PRIMARY KEY,
    model_name VARCHAR(32) NOT NULL,
    model_version VARCHAR (16) NOT NULL,
    model_card LONGTEXT NOT NULL,
    UNIQUE (model_name, model_version)
);

CREATE TABLE IF NOT EXISTS games.players(
    player_id INTEGER PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(32) UNIQUE,
    model_hash VARCHAR(32) NULL, --Human players will have a null value here. 
    FOREIGN KEY (model_hash) REFERENCES models.models(model_hash)
);

CREATE TABLE IF NOT EXISTS games.games(
    game_id INTEGER PRIMARY KEY AUTO_INCREMENT,
    winner_id INTEGER NOT NULL, 
    loser_id INTEGER NOT NULL,
    play_timestamp INTEGER NOT NULL,
    post_timestamp INTEGER NOT NULL,
    FOREIGN KEY (winner_id) REFERENCES games.players(player_id),
    FOREIGN KEY (loser_id) REFERENCES games.players(player_id),
    UNIQUE (winner_id, play_timestamp),
    UNIQUE (loser_id, play_timestamp)
    -- These constraints help prevent accidental duplicates.
);

CREATE TABLE IF NOT EXISTS games.bot_parameters(
    game_id INTEGER NOT NULL,
    is_winner INTEGER NOT NULL,
    parameter VARCHAR(32) NOT NULL,
    val FLOAT NOT NULL,
    FOREIGN KEY (game_id) REFERENCES games.games(game_id),
    UNIQUE (game_id, is_winner, parameter)
    -- Each parameter should only be specified once per bot (in case of bot v bot) per game.
);

CREATE TABLE IF NOT EXISTS games.breaths(
    game_id INTEGER NOT NULL,
    is_winner INTEGER NOT NULL,
    information INTEGER NOT NULL, -- i.e. state
    choice INTEGER NOT NULL, -- i.e. action
    FOREIGN KEY (game_id) REFERENCES games.games(game_id)
);

