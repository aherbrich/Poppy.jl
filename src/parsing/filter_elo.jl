function clean_moves_str(move_string::String)
    # remove everything in string which is in {} including the brackets
    move_string = replace(move_string, r"\{[^\}]*\}" => "")
    # remove all move numbers like 1. 2. 3. etc
    move_string = replace(move_string, r"\d+\." => "")
    # remove all . and # and + and ? and ! and *
    move_string = replace(move_string, r"\.|\#|\+|\?|\!|\*" => "")
    # remove all 1-0 0-1 1/2-1/2
    move_string = replace(move_string, r"1-0|0-1|1/2-1/2" => "")

    return join(split(move_string), " ")
end

function filter_elo(filename::String, elo::Int)
    file = open(filename, "r")

    metadata = Dict{String, String}()
    count = 0

    while !eof(file)
        line = readline(file)
        line = strip(line)

        if isempty(line)
            continue
        end

        if startswith(line, "[") && endswith(line, "]")
            key_value = match(r"\[(\w+)\s+\"([^\"]+)\"\]", line)
            if key_value !== nothing
                key, value = key_value.captures[1], key_value.captures[2]
                metadata[key] = value
            end
        elseif startswith(line, "1.")
            if haskey(metadata, "WhiteElo") && metadata["WhiteElo"] != "?" && parse(Int, metadata["WhiteElo"]) >= elo && haskey(metadata, "BlackElo") && metadata["BlackElo"] != "?" && parse(Int, metadata["BlackElo"]) >= elo
                count += 1
                println(stderr, "$count")
                move_string = clean_moves_str(String(line))
                for (key, value) in metadata
                    println("[$key \"$value\"]")
                end
                println("\n$move_string\n")

            end
            metadata = Dict{String, String}()
        end
    end
end

