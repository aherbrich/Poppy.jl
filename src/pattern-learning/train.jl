function train_on_game_model_b(game_str::T, model::Dict{UInt64, Gaussian}, metadata::TrainingMetadata; with_prediction, beta, loop_eps) where T<:AbstractString
    # SET BOARD INTO INITIAL STATE
    board = Board()
    set_by_fen!(board, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

    move_strings = split(game_str)
    for (i, move_str) in enumerate(move_strings)
        # sort expert move to the front of the move list
        _, legals = generate_legals(board)
        move = extract_move_by_san(board, move_str)
        best_move_idx = findfirst(mv -> mv.src == move.src && mv.dst == move.dst && mv.type == move.type, legals)
        legals[1], legals[best_move_idx] = legals[best_move_idx], legals[1]

        # make an prediction given the current model
        if with_prediction
            prediction = predict_on(model, board, legals)
            push!(metadata.predictions, prediction)
        end

        # nothing to rank if only one legal move
        if length(legals) == 1
            do_move!(board, move)
            continue
        end

        # UPDATE THE MODEL
        features_of_all_boards = extract_features_from_all_boards(board, legals)
        ranking_update_model_b!(model, features_of_all_boards, beta=beta, loop_eps=loop_eps)
        do_move!(board, move)
    end
end

function train_model(training_file::String; exclude=[], folder="./data/models", dump_frequency=50000, with_prediction=false, beta=5.0, loop_eps=0.1)
    # FIND LATEST MODEL VERSION
    files = filter(x -> occursin(r"model_v\d+.*", x), readdir(folder))
    model_version = (isempty(files)) ? 1 : maximum(map(x -> parse(Int, match(r"model_v(\d+).*", x).captures[1]), files)) + 1

    # INITIALIZE EMPTY MODEL
    model_b = Dict{UInt64, Gaussian}()

    # HELPER VARIABLES
    metadata = TrainingMetadata(training_file)

    # TRAIN MODEL
    games = open(training_file, "r")
    while !eof(games)
        metadata.count += 1
        game_str = strip(readline(games))

        if count in exclude continue end

        # TRAIN ON GAME
        train_on_game_model_b(game_str, model_b, metadata, with_prediction=with_prediction, beta=beta, loop_eps=loop_eps)
        print(metadata)

        # DUMP MODEL
        if metadata.count % dump_frequency == 0
            filename_dump = abspath(expanduser("$folder/model_v$(model_version)_dump$(metadata.count).txt"))
            save_model(model, filename_dump)
        end
    end

    close(games)

    # SAVE MODEL
    filename_model = "$folder/model_v$(model_version).txt"
    save_model(model, filename_model)

    return filename_model
end