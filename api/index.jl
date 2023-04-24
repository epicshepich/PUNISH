using HTTP
using JSON3
using DBInterface
using MySQL
using DotEnv
#using DataStreams

include("../common/game.jl")

if !("MYSQL_USER" in keys(ENV))
    # If running locally, load environment variables from .env file
    # (ENV variables pre-set when running from podman-compose).
    DotEnv.config("../.env")
    ENV["MYSQL_HOST"] = "127.0.0.1"
end

const punish_host = ENV["MYSQL_HOST"]
const punish_port = parse(Int, ENV["MYSQL_PORT"])
const punish_user = "root" # ENV["MYSQL_USER"]
const punish_password = replace(ENV["MYSQL_ROOT_PASSWORD"], "\\" =>"")
# Remove escape characters.


const ROUTER = HTTP.Router()


function query_model(req::HTTP.Request)
    try
        conn = DBInterface.connect(MySQL.Connection, punish_host, punish_user, punish_password, port=punish_port)
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


function register_player(req::HTTP.Request)
    try
        conn = DBInterface.connect(MySQL.Connection, punish_host, punish_user, punish_password, port=punish_port)
        stmt = DBInterface.prepare(conn, "INSERT INTO games.players(username, timestamp_registered) VALUES (?,?)")
        body = JSON3.read(String(req.body))
        DBInterface.execute(stmt, [body["username"], round(Int,time())])  
        DBInterface.close!(conn)
        return HTTP.Response(200,"Success!")
    catch e
        println(e)
        return HTTP.Response(500,"Error: $e")
    end

end

HTTP.register!(ROUTER, "GET", "/models/{model_hash}/{state}", query_model)

HTTP.register!(ROUTER, "POST", "/players", register_player)

println("API server running on port 3000")

server = HTTP.serve(ROUTER, "0.0.0.0", 3000)

run(server)
