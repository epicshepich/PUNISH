# Playing Punish with Reinforcement Learning
### Jim Shepich III

This repository contains the data, models, results, and analysis of my efforts to use reinforcement learning to train artificial agents to play PUNISH.

## About Punish
PUNISH a fast-paced card duelling game developed by Happy Slaying Studios. More information about PUNISH can be found at [happyslaying.gg/articles/punish-instructions](https://happyslaying.gg/articles/punish-instructions). A virtual version of PUNISH can be downloaded for free for Windows or Android devices from [thecometcloud.itch.io/punish](https://thecometcloud.itch.io/punish) (note: downloads from Itch do not always work on Chrome).

To play against artificial agents developed in this project:

1. Download the desired agent's Q-function JSON file from the `agents/` directory of this repository
2. Drop it into the `agents/` directory of the folder containing your local copy of the game
3. Set the `path` option in the `config.txt` file to the agents's filename; set the `name` to whatever you want displayed in the logs
4. Host a game, and then ready up in the empty room; your opponent will be the agent

Feel free to send us your data (the `saves.json` file in the root directory of your game folder) to include in our analyses!

## Time Log

Initial Investigation:
    - Code: 57 hours 32 minutes
    - Report: 8 hours 54 minutes
    - Slides: 6 hours 55 minutes
    - Total: 73 hours 21 minutes
Training Overhaul: 8 hours 5 minutes
Dashboard: 
Database Overhaul: 3 hours 21 minutes
Container Structure: 2 hours 56 minutes
API: 1 hours 50 minutes

## To Do

### Training
- Use seed 8248 to generate model hashes based on final trained nested Dict object.

### Telemetry

### Dashboard

- Statistics:
    - How many breaths in pulled data
    - How many starting states (and what fraction of all possible)
    - How many distinct states (and fraciton of possible)
    - Player table: player_id	username	wins	losses	games_played	win_rate

- Graphs:
    - Histogram of game durations (overall summary and by player)
    - Number of games by player, possibly separating wins and losses (overall summary only)
    - Win rates of each player (overall summary)
    - Total games played vs win rate (scatterplot summary)
    - Evolution of win rate vs number of games played (history by player)
    - PVP matchups (normalized win rates and non-normalized win counts)
    
