function train_on_game_model_a(game_str::AbstractString, urgencies::Dict{UInt64, Gaussian}, metadata::TrainingMetadata; with_prediction::Bool, beta::Float64, loop_eps::Float64)
    # SET BOARD INTO INITIAL STATE
    board = Board()
    set_by_fen!(board, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

    for (i, move_str) in enumerate(split(game_str))
        # nothing to rank if only one legal move
        _, legals = generate_legals(board)
        move = extract_move_by_san(board, move_str)
        best_move_idx = findfirst(mv -> mv.src == move.src && mv.dst == move.dst && mv.type == move.type, legals)
        legals[1], legals[best_move_idx] = legals[best_move_idx], legals[1]

        # ID EXTRACTION
        move_ids = map(mv -> move_to_hash(mv, board, hash_func=:complex), legals)

        if with_prediction
            prediction = predict_on_model_a(urgencies, move_ids, board, legals)
            push!(metadata.predictions, prediction)
        end

        if length(legals) == 1  # nothing to rank if only one legal move
            do_move!(board, move)
            continue
        end

        # UPDATE THE MODEL (i.e. feature values)
        ranking_update_model_a!(urgencies, move_ids, beta=beta, loop_eps=loop_eps)
        do_move!(board, move)
    end
end


function train_model_a(training_file::AbstractString; exclude_games=Vector{Int}(), folder="./data/models", save_model=false, dump_frequency=5000, with_prediction=false, beta=1.0, loop_eps=0.01)
    # FIND LATEST MODEL VERSION
    files = filter(x -> occursin(r"model_v\d+.*", x), readdir(folder))
    model_version = (isempty(files)) ? 1 : maximum(map(x -> parse(Int, match(r"model_v(\d+).*", x).captures[1]), files)) + 1

    # INITIALIZE EMPTY MODEL
    urgencies = Dict{UInt64, Gaussian}()
    metadata = TrainingMetadata(training_file, exclude_games)

    # TRAIN MODEL
    open(training_file, "r") do games
        for (idx, game_str) in enumerate(eachline(games))
            if idx in exclude_games continue end

            # TRAIN ON GAME
            train_on_game_model_a(game_str, urgencies, metadata, with_prediction=with_prediction, beta=beta, loop_eps=loop_eps)
            metadata.processed += 1
            print(metadata)

            # DUMP MODEL
            if save_model && metadata.processed % dump_frequency == 0
                filename_dump = abspath(expanduser("$folder/model_v$(model_version)_dump$(metadata.processed).txt"))
                save_model(urgencies, filename_dump)
            end
        end
    end

    # SAVE MODEL
    if save_model
        filename_model = abspath(expanduser("$folder/model_v$(model_version).txt"))
        save_model(feature_values, filename_model)
    end

    return urgencies, metadata
end


function train_on_game_model_b(game_str::AbstractString, feature_values::Dict{UInt64, Gaussian}, metadata::TrainingMetadata; feature_set::Symbol, with_prediction::Bool, beta::Float64, loop_eps::Float64)
    # SET BOARD INTO INITIAL STATE
    board = Board()
    set_by_fen!(board, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

    for (i, move_str) in enumerate(split(game_str))
        # SORT EXPERT MOVE TO THE FRONT OF THE MOVE LIST
        _, legals = generate_legals(board)
        move = extract_move_by_san(board, move_str)
        best_move_idx = findfirst(mv -> mv.src == move.src && mv.dst == move.dst && mv.type == move.type, legals)
        legals[1], legals[best_move_idx] = legals[best_move_idx], legals[1]

        # FEATURE EXTRACTION
        features_of_all_boards = extract_features_from_all_boards(board, legals, feature_set)

        if with_prediction
            prediction = predict_on_model_b(feature_values, features_of_all_boards, board, legals)
            push!(metadata.predictions, prediction)
        end

        
        if length(legals) == 1  # nothing to rank if only one legal move
            do_move!(board, move)
            continue
        end

        # UPDATE THE MODEL (i.e. feature values)
        ranking_update_model_b!(feature_values, features_of_all_boards, beta=beta, loop_eps=loop_eps)
        do_move!(board, move)
    end
end

function train_model_b(training_file::AbstractString, feature_set::Symbol; exclude_games=Vector{Int}(), folder="./data/models", save_model=false, dump_frequency=5000, with_prediction=false, beta=1.0, loop_eps=0.01)
    # FIND LATEST MODEL VERSION
    files = filter(x -> occursin(r"model_v\d+.*", x), readdir(folder))
    model_version = (isempty(files)) ? 1 : maximum(map(x -> parse(Int, match(r"model_v(\d+).*", x).captures[1]), files)) + 1

    # INITIALIZE EMPTY MODEL
    feature_values = Dict{UInt64, Gaussian}()
    metadata = TrainingMetadata(training_file, exclude_games)

    # TRAIN MODEL
    open(training_file, "r") do games
        for (idx, game_str) in enumerate(eachline(games))
            if idx in exclude_games continue end

            # TRAIN ON GAME
            train_on_game_model_b(game_str, feature_values, metadata, feature_set=feature_set, with_prediction=with_prediction, beta=beta, loop_eps=loop_eps)
            metadata.processed += 1
            print(metadata)

            # DUMP MODEL
            if save_model && metadata.processed % dump_frequency == 0
                filename_dump = abspath(expanduser("$folder/model_v$(model_version)_dump$(metadata.processed).txt"))
                save_model(feature_values, filename_dump)
            end
        end
    end
    
    # SAVE MODEL
    if save_model
        filename_model = abspath(expanduser("$folder/model_v$(model_version).txt"))
        save_model(feature_values, filename_model)
    end

    return feature_values, metadata
end