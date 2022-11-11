CREATE TABLE players(
    player_id INT NOT NULL,
    username TEXT NOT NULL,
    is_bot INT NOT NULL,
    PRIMARY KEY (player_id)
);

CREATE TABLE bot_parameters(
    paramset_id INT NOT NULL,
    temperature FLOAT,
    PRIMARY KEY (paramset_id)
);

CREATE TABLE games(
    game_id INT NOT NULL,
    winner_id INT NOT NULL,
    loser_id INT NOT NULL,
    winner_paramset_id INT,
    loser_paramset_id INT,
    PRIMARY KEY (game_id),
    FOREIGN KEY (winner_id) REFERENCES players(player_id),
    FOREIGN KEY (loser_id) REFERENCES players(player_id),
    FOREIGN KEY (winner_paramset_id) REFERENCES bot_parameters(paramset_id),
    FOREIGN KEY (loser_paramset_id) REFERENCES bot_parameters(paramset_id)
);

CREATE TABLE breaths(
    game_id INT NOT NULL,
    is_winner INT NOT NULL,
    state INT NOT NULL,
    action INT NOT NULL,
    FOREIGN KEY (game_id) REFERENCES games(game_id)
)
