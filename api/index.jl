using HTTP
using JSON3
using DBInterface
using MySQL
#using DataStreams

include("../common/game.jl")

const punish_host = "127.0.0.1"#ENV["MYSQL_HOST"]
const punish_port = 3306#parse(Int, ENV["MYSQL_PORT"])
const punish_user = "root"#ENV["MYSQL_USER"]
const punish_password = "thewoods"#ENV["MYSQL_PASSWORD"]


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
