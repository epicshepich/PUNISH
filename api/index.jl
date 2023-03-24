using HTTP
using JSON3
using MySQL

host = ENV["MYSQL_HOST"]
port = parse(Int, ENV["MYSQL_PORT"])
user = ENV["MYSQL_USER"]
password = ENV["MYSQL_PASSWORD"]
database = ENV["MYSQL_DATABASE"]

const ROUTER = HTTP.Router();


HTTP.register!(ROUTER, "GET", "/models/{model_hash}/{state}", query_model)


function query_model(req::HTTP.Request)

    conn = MySQL.connect(host, port, user, password, database)
    # Prepare the query statement with placeholders
    stmt = MySQL.Stmt(conn, "SELECT * FROM models.%s WHERE state=%s")    
    # Bind the variables to the statement
    MySQL.bind!(stmt, [HTTP.getparams(req)["model_hash"], HTTP.getparams(req)["state"]])
    # execute the query and fetch the results
    results = MySQL.query(conn, stmt)
    rows = MySQL.fetchall(results)    
    MySQL.close(conn)

    return HTTP.Response(200,JSON3.write(rows))

end

server = HTTP.serve!(ROUTER, "0.0.0.0", 3000)

