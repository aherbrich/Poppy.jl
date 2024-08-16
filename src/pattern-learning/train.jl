function train_on_game(game_str::T, urgencies::Dict{UInt64, Gaussian}, metadata::TrainingMetadata; with_prediction=false, mask_in_prior, no_samples, beta) where T<:AbstractString
    # SET BOARD INTO INITIAL STATE
    board = Board()
    set_by_fen!(board, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

    move_strings = split(game_str)
    for (i, move_str) in enumerate(move_strings)
        print("\r$(metadata.count) games, $(i) moves")
        # generate all legal moves for board b
        # and sort the played move to the front of the list
        # since it is the best move in the expert's opinion
        _, legals = generate_legals(board)
        move = extract_move_by_san(board, move_str)
        best_move_idx = findfirst(mv -> mv.src == move.src && mv.dst == move.dst && mv.type == move.type, legals)
        legals[1], legals[best_move_idx] = legals[best_move_idx], legals[1]
        
        if length(legals) == 1
            do_move!(board, move)
            continue
        end

        # make an prediction given the current model
        if with_prediction
            prediction = predict_on(urgencies, board, legals, mask_in_prior=mask_in_prior, beta=beta)
            push!(metadata.predictions, prediction)
        end

        # UPDATE THE MODEL (i.e. the feature values)
        features_of_all_boards = extract_features_from_all_boards(board, legals)
        ranking_update!(urgencies, features_of_all_boards, mask_in_prior=mask_in_prior, beta=beta, loop_eps=0.1)
        do_move!(board, move)
    end
end

function train_model(training_file::String; exclude=[], folder="./data/models", dump_frequency=5000, with_prediction=false, mask_in_prior=2, no_samples=10000, beta=0.5)
    # FIND LATEST MODEL VERSION
    files = filter(x -> occursin(r"model_v\d+.*", x), readdir(folder))
    model_version = (isempty(files)) ? 1 : maximum(map(x -> parse(Int, match(r"model_v(\d+).*", x).captures[1]), files)) + 1

    # INITIALIZE EMPTY MODEL
    urgencies = Dict{UInt64, Gaussian}()

    # HELPER VARIABLES
    metadata = TrainingMetadata(training_file)

    # TRAIN MODEL
    games = open(training_file, "r")
    while !eof(games)
        metadata.count += 1
        game_str = strip(readline(games))

        if count in exclude continue end

        # TRAIN ON GAME
        train_on_game(game_str, urgencies,metadata, with_prediction=with_prediction, mask_in_prior=mask_in_prior, no_samples=no_samples, beta=beta)
        print(metadata)

        # DUMP MODEL
        if metadata.count % dump_frequency == 0
            filename_dump = abspath(expanduser("$folder/model_v$(model_version)_dump$(metadata.count).txt"))
            save_model(urgencies, weights, filename_dump)
        end
    end

    plot_metadata(metadata, model_version)

    close(games)

    # SAVE MODEL
    filename_model = "$folder/model_v$(model_version).txt"
    save_model(urgencies, weights, filename_model)

    return filename_model
end


function train_model_by_sampling(fen::String="7K/8/k1P5/7p/8/8/8/8 w - - 0 1"; mask_in_prior::Int=2, no_samples=100000, beta=1.0, logging=false)
    urgencies = Dict{UInt64, Gaussian}()
    urgencies2 = Dict{UInt64, Gaussian}()

    board = Board()
    set_by_fen!(board, fen)

    _ , legals = generate_legals(board)
    features_of_all_boards = extract_features_from_all_boards(board, legals)

    ranking_update_by_sampling!(urgencies, features_of_all_boards, mask_in_prior=mask_in_prior, no_samples=no_samples, beta=beta, logging=logging)


    ranking_update!(urgencies2, features_of_all_boards, mask_in_prior=mask_in_prior, beta=beta, loop_eps=0.01)

    println();
    if (logging)
        println("urgencies")
        for (k,v) in urgencies
            println(k, " ", v, " <=> ", urgencies2[k])  
        end
    end

    
    features_of_all_boards = extract_features_from_all_boards(board, legals)
    values = calculate_board_values(urgencies, features_of_all_boards, mask_in_prior=mask_in_prior, no_samples=no_samples, beta=beta)
    best_board_idx = argmax(values)
    
    for (k,board) in enumerate(legals)
        (values[k] > 0.0) ? @printf("board %d:\t+%.4f %s\n", k, values[k], k == best_board_idx ? "✅" : "") : @printf("board %d:\t%.4f %s\n", k, values[k], k == best_board_idx ? "✅" : "")
    end
end