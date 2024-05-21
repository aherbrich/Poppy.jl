function clean_move_string(move_string::T) where T<:AbstractString
    move_string = replace(move_string, r"\{[^\}]*\}" => "")
    move_string = replace(move_string, r"\d+\." => "")
    move_string = replace(move_string, r"\.|\#|\+|\?|\!|\*" => "")
    move_string = replace(move_string, r"1-0|0-1|1/2-1/2" => "")

    return join(split(move_string), " ")
end

function clean_pgn(path::String; folder="./data/training/processed")
    filename_all = match(r"([^/]+)$", path).match
    filename_cleaned = abspath(expanduser(joinpath(folder, "games_$(filename_all)")))
    
    cleaned_games = open(filename_cleaned, "w")
    all_games = open(path, "r")

    while !eof(all_games)
        line = strip(readline(all_games))

        # skip empty lines
        if isempty(line)
            continue
        # skip game tags
        elseif startswith(line, "[") && endswith(line, "]")
            continue
        # parse move string
        elseif startswith(line, "1.")
            println(cleaned_games, "$(clean_move_string(line))")
        end
    end

    close(all_games)
    close(cleaned_games)

    return filename_cleaned
end