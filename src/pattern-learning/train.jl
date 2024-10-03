function train_on_game_urgency_model(game_str::AbstractString, urgencies::Dict{UInt64, Gaussian}, hash_func::Symbol, metadata::TrainingMetadata; with_prediction::Bool, beta::Float64, loop_eps::Float64)
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
        move_ids = map(mv -> move_to_hash(mv, board, hash_func=hash_func), legals)

        if with_prediction
            prediction = predict_on_urgency_model(urgencies, move_ids, board, legals)
            push!(metadata.predictions, prediction)
        end

        if length(legals) == 1  # nothing to rank if only one legal move
            do_move!(board, move)
            continue
        end

        # UPDATE THE MODEL (i.e. feature values)
        ranking_update_urgency_model!(urgencies, move_ids, beta=beta, loop_eps=loop_eps)
        do_move!(board, move)
    end
end


function train_urgency_model(training_file::AbstractString, hash_func::Symbol; exclude_games=Vector{Int}(), folder="./data/models", dump_model=false, training_id=-1, with_prediction=false, beta=1.0, loop_eps=0.01)
    if dump_model && training_id == -1
        error("Please provide a unique training_id for model dump")
    end
    
    # INITIALIZE EMPTY MODEL
    urgencies = Dict{UInt64, Gaussian}()
    metadata = TrainingMetadata(training_file, exclude_games)

    dump_frequency = 1

    # TRAIN MODEL
    open(training_file, "r") do games
        for (idx, game_str) in enumerate(eachline(games))
            if idx in exclude_games continue end

            # TRAIN ON GAME
            train_on_game_urgency_model(game_str, urgencies, hash_func, metadata, with_prediction=with_prediction, beta=beta, loop_eps=loop_eps)
            metadata.processed += 1
            print(metadata)

            # DUMP MODEL
            if dump_model && metadata.processed % dump_frequency == 0
                filename_dump = abspath(expanduser("$folder/urgency_model_$(hash_func)_trained_on_$(metadata.processed)_id_$(training_id).bin"))
                save_model(urgencies, filename_dump)
                push!(metadata.model_files, filename_dump)
                dump_frequency *= 2
            end
        end
    end

    # SAVE MODEL
    if dump_model
        filename_model = abspath(expanduser("$folder/urgency_model_$(hash_func)_trained_on_$(metadata.processed)_id_$(training_id).bin"))
        save_model(urgencies, filename_model)
        push!(metadata.model_files, filename_model)
    end

    return urgencies, metadata
end


function train_on_game_boardval_model(game_str::AbstractString, feature_values::Dict{UInt64, Gaussian}, metadata::TrainingMetadata; feature_set::Symbol, with_prediction::Bool, beta::Float64, loop_eps::Float64)
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
            prediction = predict_on_boardval_model(feature_values, features_of_all_boards, board, legals)
            push!(metadata.predictions, prediction)
        end

        
        if length(legals) == 1  # nothing to rank if only one legal move
            do_move!(board, move)
            continue
        end

        # UPDATE THE MODEL (i.e. feature values)
        ranking_update_boardval_model!(feature_values, features_of_all_boards, beta=beta, loop_eps=loop_eps)
        do_move!(board, move)
    end
end

function train_model_boardval_model(training_file::AbstractString, feature_set::Symbol; exclude_games=Vector{Int}(), folder="./data/models", dump_model=false, training_id=-1, with_prediction=false, beta=1.0, loop_eps=0.01)
    if dump_model && training_id == -1
        error("Please provide a unique training_id for model dump")
    end

    # INITIALIZE EMPTY MODEL
    feature_values = Dict{UInt64, Gaussian}()
    metadata = TrainingMetadata(training_file, exclude_games)

    dump_frequency = 1

    # TRAIN MODEL
    open(training_file, "r") do games
        for (idx, game_str) in enumerate(eachline(games))
            if idx in exclude_games continue end

            # TRAIN ON GAME
            train_on_game_boardval_model(game_str, feature_values, metadata, feature_set=feature_set, with_prediction=with_prediction, beta=beta, loop_eps=loop_eps)
            metadata.processed += 1
            print(metadata)

            # DUMP MODEL
            if dump_model && metadata.processed % dump_frequency == 0
                filename_dump = abspath(expanduser("$folder/boardval_model_$(feature_set)_trained_on_$(metadata.processed)_id_$(training_id).bin"))
                save_model(feature_values, filename_dump)
                push!(metadata.model_files, filename_dump)
                dump_frequency *= 2
            end
        end
    end
    
    # SAVE MODEL
    if dump_model
        filename_model = abspath(expanduser("$folder/boardval_model_$(feature_set)_trained_on_$(metadata.processed)_id_$(training_id).bin"))
        save_model(feature_values, filename_model)
        push!(metadata.model_files, filename_model)
    end

    return feature_values, metadata
end