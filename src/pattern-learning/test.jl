function test_on_game(game_str::T, urgencies::Dict{UInt64, Gaussian}, metadata::TestMetadata; compute_max_accuracy=false, mask_in_prior, beta, loop_eps) where T <: AbstractString
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

        prediction = predict_on(urgencies, board, legals, mask_in_prior=mask_in_prior, beta=beta, loop_eps=loop_eps)
        push!(metadata.predictions, prediction)
        
        if compute_max_accuracy
            board_hash = board.history[board.ply].hash
            move_hash = move_to_hash(move)

            if !haskey(metadata.hashtable, board_hash)
                metadata.hashtable[board_hash] = Dict{UInt64, Vector{Int}}()
            end

            if !haskey(metadata.hashtable[board_hash], move_hash)
                metadata.hashtable[board_hash][move_hash] = zeros(Int, 100)
            end

            metadata.hashtable[board_hash][move_hash][min(board.ply, 100)] += 1
        end

        do_move!(board, move)
    end

end

function test_model(filename_model::T, filename_games; compute_max_accuracy=false, mask_in_prior=2, beta=0.5) where T <: AbstractString
    urgencies = load_model(filename_model)
    model_version = parse(Int, match(r"model_v(\d+).*", filename_model).captures[1])

    # HELPER VARIABLES
    metadata = TestMetadata(filename_games)

    if compute_max_accuracy
        @warn "compute_max_accuracy is set to true!\nThis should only be used if really necessary, since it is very memory intensive!"
    end

    # TEST MODEL
    games = open(filename_games, "r")
    while !eof(games)
        metadata.count += 1
        game_str = strip(readline(games))

        # TEST ON GAME
        test_on_game(game_str, urgencies, metadata, compute_max_accuracy=compute_max_accuracy, mask_in_prior=mask_in_prior, beta=beta, loop_eps=0.1)
        print(metadata)
    end

    plot_metadata(metadata, model_version, plot_max_accuracy=compute_max_accuracy)

    close(games)

end