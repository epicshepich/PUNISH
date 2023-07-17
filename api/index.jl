using HTTP
using JSON3
using DBInterface
using MySQL
using DotEnv
#using DataStreams

include("../common/game.jl")
include("modules/auth.jl")
include("modules/etl.jl")

if !("API_HOST" in keys(ENV))
    # If running locally, load environment variables from .env file
    # (ENV variables pre-set when running from podman-compose).
    DotEnv.config("../.env")
    ENV["API_HOST"] = "localhost"
    ENV["MYSQL_HOST"] = "localhost"
    # Set host to localhost when running locally.

end

const PUNISH_HOST = ENV["MYSQL_HOST"]
const PUNISH_PORT = parse(Int, ENV["MYSQL_PORT"])
const PUNISH_USER = "root" # ENV["MYSQL_USER"]
const PUNISH_PASSWORD = replace(ENV["MYSQL_ROOT_PASSWORD"], "\\" =>"")
# Remove escape characters.

const ROUTER = HTTP.Router()


function query_model(req::HTTP.Request)
    try
        conn = DBInterface.connect(MySQL.Connection, PUNISH_HOST, PUNISH_USER, PUNISH_PASSWORD, port=PUNISH_PORT)
        stmt = DBInterface.prepare(conn, "SELECT * FROM models.? WHERE state=?")
        results = DBInterface.execute(
            stmt, 
            [HTTP.getparams(req)["model_hash"], HTTP.getparams(req)["state"]]
        )
        rows = [row for row in results]
        DBInterface.close!(conn)    
        return HTTP.Response(200,JSON3.write(rows))
    catch e
        println(e)
        return HTTP.Response(500,"Error: $e")
    end
end
HTTP.register!(ROUTER, "GET", "/models/{model_hash}/{state}", query_model)


function register_player(req::HTTP.Request)
    try
        conn = DBInterface.connect(MySQL.Connection, PUNISH_HOST, PUNISH_USER, PUNISH_PASSWORD, port=PUNISH_PORT)
        stmt = DBInterface.prepare(conn, "INSERT INTO games.players(username, timestamp_registered) VALUES (?,?)")
        body = JSON3.read(String(req.body))
        DBInterface.execute(stmt, [body["username"], round(Int,time())])  
        DBInterface.close!(conn)
        return HTTP.Response(200,"Success!")
    catch err
        println(err)
        return HTTP.Response(500,"Error: $err")
    end
end
HTTP.register!(ROUTER, "POST", "/players", register_player)


function post_game(req::HTTP.Request)
    try
        (jwt_is_valid, jwt_status, jwt_response) = validate_jwt(body["jwt"])
        if jwt_is_valid  
            post_game(body["game"])
        else
            return HTTP.Response(jwt_status,jwt_response)
        end
    catch err
        println(err)
        return HTTP.Response(500,"Error: $err")
    end
end
HTTP.register!(ROUTER, "POST", "/games", post_game)



function generate_login_link(req::HTTP.Request)
    """Sends the URL for Discord OAuth2 login to the client."""
    link = HTTP.URI(
        scheme = "https",
        host = "discord.com",
        path = "/api/oauth2/authorize",
        query = Dict(
            "client_id" => ENV["DISCORD_CLIENT_ID"],
            "redirect_uri" => string(HTTP.URI(
                scheme = (ENV["API_HOST"]=="localhost") ? "http" : "https",
                # Use HTTP for the redirect URL when running locally.
                host = ENV["API_HOST"],
                port = ENV["API_PORT"],
                path =  ENV["API_BASEPATH"]*(endswith(ENV["API_BASEPATH"], "/") ? "" : "/")*"auth/discord"
            )),
            "response_type" => "code",
            "scope" => "identify"
        )
    )
    return HTTP.Response(200, string(link))

end
HTTP.register!(ROUTER, "GET", "/auth/login", generate_login_link)
# Call this route in Unity and set the href of the "Login with Discord" button based on the response.


function catch_oauth_send_jwt(req::HTTP.Request)
    """Catches the redirect from Discord OAuth2 and sends a JWT to the client."""
    println(req)
    return HTTP.Response(200, "Success!")
end
HTTP.register!(ROUTER, "GET", "/auth/discord", catch_oauth_send_jwt)
# Set this route to the redirect URL in Discord OAuth2 settings.








println("API server running on port 8248")

server = HTTP.serve(ROUTER, "0.0.0.0", 8248)

run(server)
