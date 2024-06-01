function calculate_values(model::ValueTable, feature_sets::Vector{BoardFeatures})
    values = Vector{Float64}()

    for feature_set in feature_sets
        value = 0.0
        for feature in feature_set
            value += (isnothing(model[feature])) ? 0.0 : gmean(model[feature])
        end
        push!(values, value)
    end

    return values
end

function print_training_metadata(count, nr_of_games, correct_predictions, total_predictions, global_start_time)
    elapsed_time = time() - global_start_time
    time_per_game = elapsed_time / count
    games_left = nr_of_games - count
    time_left = ceil(Int, games_left * time_per_game)

    print("\r\033[1mPrognosed time left: $(time_left ÷ 3600)h $((time_left ÷ 60) % 60)m $(time_left % 60)s\033[0m\t\033[1;30m(game $count/$nr_of_games | accurracy: $(round(correct_predictions / total_predictions, digits=4)))\033[0m")
end

function train_on_game(game_str::T, model::ValueTable) where T<:AbstractString
    # SET BOARD INTO INITIAL STATE
    board = Board()
    set_by_fen!(board, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

    correct_predictions = 0
    total_predictions = 0
    move_strings = split(game_str)
    for move_str in move_strings
        # generate all legal moves for board b
        _, legals = generate_legals(board)
        move = extract_move_by_san(board, move_str)

        # sort the played move to the front of the list
        # since it is the best move in the expert's opinion
        best_move_idx = findfirst(mv -> mv.src == move.src && mv.dst == move.dst && mv.type == move.type, legals)
        legals[1], legals[best_move_idx] = legals[best_move_idx], legals[1]

        # a moves value is given by the value of the 
        # resulting board (i.e. after the move is played).
        # a board is represented as a set of features.
        # to rank the possible moves, we need to rank
        # the resulting boards. hence, for every board we 
        # need to extract it's features
        features_of_all_boards = extract_features_from_all_boards(board, legals)

        # make an online prediction of the value of the resulting boards
        values_of_all_board = calculate_values(model, features_of_all_boards)
        if argmax(values_of_all_board) == 1
            correct_predictions += 1
        end
        total_predictions += 1

        # UPDATE THE MODEL (i.e. the feature values)
        ranking_update!(model, features_of_all_boards, beta=5.0)

        do_move!(board, move)
    end

    return correct_predictions, total_predictions
end

function train_model(path::String; exclude=[], folder="./data/models", dump_frequency=5000)
    # FIND LATEST MODEL VERSION
    files = filter(x -> occursin(r"model_v\d+\.txt", x), readdir(folder))
    model_version = (isempty(files)) ? 1 : maximum(map(x -> parse(Int, match(r"model_v(\d+)\.txt", x).captures[1]), files)) + 1

    # INITIALIZE EMPTY MODEL
    model = ValueTable(no_bits = 24)

    # HELPER VARIABLES
    count = 0
    global_start_time = time()
    nr_of_games = count_lines_in_files(path)
    correct_predictions = 0
    total_predictions = 0

    # TRAIN MODEL
    games = open(path, "r")
    while !eof(games)
        count += 1
        game_str = strip(readline(games))

        if count in exclude continue end

        # TRAIN ON GAME
        correct, total = train_on_game(game_str, model)
        correct_predictions += correct
        total_predictions += total

        # PRINT PROGNOSED TIME LEFT
        print_training_metadata(count, nr_of_games, correct_predictions, total_predictions, global_start_time)

        # DUMP MODEL
        if count % dump_frequency == 0
            filename_dump = abspath(expanduser("$folder/model_v$(model_version)_dump$(count).txt"))
            save_model(model, filename_dump)
        end
    end

    close(games)

    # SAVE MODEL
    filename_model = "$folder/model_v$(model_version).txt"
    save_model(model, filename_model)

    return filename_model
end
