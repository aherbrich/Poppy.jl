function calculate_values(legals, feature_values, board)
    values = zeros(Float64, length(legals))
    for (i, move) in enumerate(legals)
        do_move!(board, move)

        _, legals_prime = generate_legals(board)
        hashes = map(mv_prime -> move_to_hash(mv_prime), legals_prime)

        value = 0.0
        for i in eachindex(hashes)
            value += (isnothing(feature_values[hashes[i]]) ? 0.0 : gmean(feature_values[hashes[i]]))
            for j in i+1:length(hashes)
                hash = hashes[i] | (hashes[j] << 16)
                value += (isnothing(feature_values[hash]) ? 0.0 : gmean(feature_values[hash]))
            end
        end

        if length(legals_prime) == 0
            value += (isnothing(feature_values[UInt64(0)]) ? 0.0 : gmean(feature_values[UInt64(0)]))
        end
        
        values[i] = value

        undo_move!(board, move)
    end

    return values
end

function train_model(path::String; exclude=[], folder="./data/models")
    # find latest model version
    files = filter(x -> occursin(r"model_v\d+\.txt", x), readdir(folder))
    model_version = (isempty(files)) ? 1 : maximum(map(x -> parse(Int, match(r"model_v(\d+)\.txt", x).captures[1]), files)) + 1

    nr_of_games = count_lines_in_files(path)
    games = open(path, "r")
    feature_values = ValueTable(no_bits = 26)


    global_start_time = time()
    count = 0
    while !eof(games)
        count += 1
        game = strip(readline(games))

        # skip games which should not be trained on
        if count in exclude
            continue
        end

        # skip empty lines
        if isempty(game)
            continue
        end

        # load board into starting position
        board = Board()
        set_by_fen!(board, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

        # extract all moves made in the game
        moves = split(game)
        for (i, best_move) in enumerate(moves)
            # generate all legal moves for board b and sort the best (expert) move to the front
            _, legals = generate_legals(board)
            move = extract_move_by_san(board, best_move)

            best_move_idx = findfirst(mv -> mv.src == move.src && mv.dst == move.dst && mv.type == move.type, legals)
            legals[1], legals[best_move_idx] = legals[best_move_idx], legals[1]

            # update the model
            ranking_update!(feature_values, legals, board)

            # now play the best (expert) move on board b and continue with the next expert move
            do_move!(board, move)
        end


        if count % 1 == 0
            time_left_in_seconds = ceil(Int, (nr_of_games - count) * ((time() - global_start_time))/count)
            print("\r\033[1mPrognosed time left: $(time_left_in_seconds ÷ 3600)h $((time_left_in_seconds ÷ 60) % 60)m $(time_left_in_seconds % 60)s\033[0m\t\033[1;30m(game $count/$nr_of_games)\033[0m")# $(correct) / $(total) = $(correct / total)")
        end

        if count % 5000 == 0
            filename_dump = abspath(expanduser("$folder/model_v$(model_version)_dump$(count).txt"))
            model_file = open(filename_dump, "w")
            for (i, (key, value)) in enumerate(feature_values)
                println(model_file, "$key $(gmean(value)) $(variance(value))")
            end
            close(model_file)
            @info "Model dump saved to $filename_dump"
        end
    end

    println("Time spent: $(time() - global_start_time) seconds")
    close(games)

    filename_model = "$folder/model_v$(model_version).txt"
    model_file = open(filename_model, "w")

    # write model to file
    for (i, (key, value)) in enumerate(feature_values)
        println(model_file, "$key $(gmean(value)) $(variance(value))")
    end

    close(model_file)

    return filename_model
end
