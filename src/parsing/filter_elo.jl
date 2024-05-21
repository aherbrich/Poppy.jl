
function filter_elo(path::String, elo::Int; folder="./data/training/raw")
    filename_filtered = abspath(expanduser(joinpath(folder, "elo_$elo.pgn")))
    
    filtered_games = open(filename_filtered, "w")
    all_games = open(path, "r")

    metadata = Dict{String, String}()
    while !eof(all_games)
        line = strip(readline(all_games))

        # skip empty lines
        if isempty(line)
            continue
        end

        # parse game tags
        if startswith(line, "[") && endswith(line, "]")
            key_value = match(r"\[(\w+)\s+\"([^\"]+)\"\]", line)
            if key_value !== nothing
                key, value = key_value.captures[1], key_value.captures[2]
                metadata[key] = value
            end

        # parse move string
        elseif startswith(line, "1.")
            # filter games by elo
            if  haskey(metadata, "WhiteElo") && haskey(metadata, "BlackElo") &&
                metadata["WhiteElo"] != "?" && metadata["BlackElo"] != "?" &&
                parse(Int, metadata["WhiteElo"]) >= elo && parse(Int, metadata["BlackElo"]) >= elo

                for (key, value) in metadata
                    println(filtered_games, "[$key \"$value\"]")
                end
                println(filtered_games, "\n$line\n")
            end
            # reset metadata, after game is written
            metadata = Dict{String, String}()
        end
    end

    close(all_games)
    close(filtered_games)

    return filename_filtered
end

