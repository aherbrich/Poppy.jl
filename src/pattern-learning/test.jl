function test_on_game(game_str::T, model::ValueTable, metadata::TestMetadata) where T <: AbstractString
    # SET BOARD INTO INITIAL STATE
    board = Board()
    set_by_fen!(board, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

    # TEST PRECISION OF MODEL ON GAME
    move_strings = split(game_str)
    for (i, move_str) in enumerate(move_strings)
        # generate all legal moves for board b
        # and sort the played move to the front of the list
        # since it is the best move in the expert's opinion
        _, legals = generate_legals(board)
        move = extract_move_by_san(board, move_str)
        best_move_idx = findfirst(mv -> mv.src == move.src && mv.dst == move.dst && mv.type == move.type, legals)
        legals[1], legals[best_move_idx] = legals[best_move_idx], legals[1]

        prediction = predict_on(model, board, legals)
        push!(metadata.predictions, prediction)

        do_move!(board, move)
    end

end

function test_model(filename_model::T, filename_games) where T <: AbstractString
    model = load_model(filename_model)

    # HELPER VARIABLES
    metadata = TestMetadata(filename_model)

    # TEST MODEL
    games = open(filename_games, "r")
    while !eof(games)
        metadata.count += 1
        game_str = strip(readline(games))

        # TEST ON GAME
        test_on_game(game_str, model, metadata)
        print(metadata)
    end

    close(games)

end