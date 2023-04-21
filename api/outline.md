basepath: api

Should we allow any "GET" requests on players/games?
    - How public do we want game data to be?
    - `games` table uses player ID and `breaths` uses gameid
    - We could de-identify `games.players` table to drop usernames/etc. but keep info like registration date and human/ai indicator

- Have a way to get your own data

- /models
    - POST: will create record in `models.models` table (and `games.players`) based on model metadata
        - Requires authenticated admin account (should we hard-code these or have another table/column in players table)
        - Should we POST the entire nested dict in a single request or have many little request
            - Recommendation: all at once will let us run validation without having to modify the db 
            - Decision: post al in one
    - GET: returns overview of all models (`SELECT * FROM models.models`)
    - /{hash}
        - GET: Returns a single JSON object containing model metadata and entire q-function
            - /meta
                - GET: returns only the model's metadata (`SELECT * FROM models.models where hash = {hash}`)
            - /q
                - GET: returns model's entire q-function as a nested dictionary (`SELECT * FROM models.{hash}`)
                - /{state}
                    - GET: returns dictionary of action-values (`SELECT * FROM models.{hash} WHERE state = {state}`)
- /games
    - POST: validates the game and writes the appropriate information to `games.games`, `games.bot_parameters`, and `games.breaths`
        - Requires login/API key
        - Only with a 200 response will the record from the client's local SQLite db be purged 
- /players
    - DELETE:
        - Option 1: purges all game data associated with player and removes their record from the database
        - Option 2: de-identifies player (overwrites username/password hash with %DELETED%) while maintaining 
    - /register
        - GET: renders registration form in browser
        - POST: registers new player to `games.players` db
            - Requires validation   
                - Are there any protected names (e.g. "null")
                - Try to prevent hash-like names in case of collisions? (very very unlikely but could be an epic prank)

