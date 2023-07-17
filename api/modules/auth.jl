using JSON3
using JSONWebTokens
using DotEnv

if !("DISCORD_CLIENT_SECRET" in keys(ENV))
    # If running locally, load environment variables from .env file
    # (ENV variables pre-set when running from podman-compose).
    DotEnv.config("../.env")
end


const jwt_encoding = JSONWebTokens.HS256(ENV["JWT_SECRET"])


function validate_jwt(encoded_jwt::String)
    """Ensures that a string JWT is valid and not expired."""
    try
        decoded_jwt = JSONWebTokens.decode(encoded_jwt, jwt_encoding)

        if(decoded_jwt["eat"] < round(Int64,time()))
            return (false, 400, "JWT expired.")
        end
    catch (err)
        return (false, 400, "Invalid JWT: $err")
    end

    return (true, 200, decoded_jwt)
end