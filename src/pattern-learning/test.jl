function print_test_metadata(count::Int, correct_predictions::Int, total_predictions::Int)
    print("\rcount: $count, correct: $correct_predictions, total: $total_predictions, accuracy: $(correct_predictions / total_predictions)")
end

function extract_move_values(model::ValueTable, legals::Vector{Move}, board::Board)
    values = zeros(Float64, length(legals))

    # EXTRACT EVERY MOVE'S VALUE
    for (i, move) in enumerate(legals)
        # a moves value is given by the value of the 
        # resulting board (i.e. after the move is played).
        # a board is represented as a set of features.
        board_value = 0.0
        
        # play the move to get the resulting board b'
        do_move!(board, move)

        board_features = BoardFeatures(board)

        for feature in board_features
            board_value += (isnothing(model[feature]) ? 0.0 : gmean(model[feature]))
        end
        
        values[i] = board_value

        undo_move!(board, move)
    end

    return values
end

function test_on_game(game_str::T, model::ValueTable) where T <: AbstractString
    # SET BOARD INTO INITIAL STATE
    board = Board()
    set_by_fen!(board, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

    # HELPER VARIABLES
    correct_predictions = 0
    total_predictions = 0

    # TEST PRECISION OF MODEL ON GAME
    move_strings = split(game_str)
    for move_str in move_strings
        # generate all legal moves for board b
        _, legals = generate_legals(board)
        move = extract_move_by_san(board, move_str)

        # sort the played move to the front of the list
        # since it is the best move in the expert's opinion
        best_move_idx = findfirst(mv -> mv.src == move.src && mv.dst == move.dst && mv.type == move.type, legals)
        legals[1], legals[best_move_idx] = legals[best_move_idx], legals[1]

        values = extract_move_values(model, legals, board)

        # our prediction is correct if the first move (the expert move)
        # is the move with the highest value
        if argmax(values) == 1
            correct_predictions += 1
        end
        total_predictions += 1

        do_move!(board, move)
    end

    return correct_predictions, total_predictions
end

function test_model(filename_model::T, filename_games) where T <: AbstractString
    model = load_model(filename_model)

    # HELPER VARIABLES
    count = 0
    correct_predictions = 0
    total_predictions = 0

    # TEST MODEL
    games = open(filename_games, "r")
    while !eof(games)
        count += 1
        game_str = strip(readline(games))

        # TRAIN ON GAME
        correct, total = test_on_game(game_str, model)

        # UPDATE METADATA
        correct_predictions += correct
        total_predictions += total

        # PRINT TEST METADATA
        print_test_metadata(count, correct_predictions, total_predictions)
    end

    close(games)

    return correct_predictions / total_predictions
end