function train_on_game_model_b(game_str::T, feature_values::Dict{UInt64, Gaussian}, metadata::TrainingMetadata; feature_set::Symbol, with_prediction::Bool, beta::Float64, loop_eps::Float64) where T<:AbstractString
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

        # feature extraction
        features_of_all_boards = extract_features_from_all_boards(board, legals, feature_set=feature_set)

        # make an prediction given the current model
        if with_prediction
            prediction = predict_on_model_b(feature_values, features_of_all_boards, board, legals)
            push!(metadata.predictions, prediction)
        end

        # nothing to rank if only one legal move
        if length(legals) == 1
            do_move!(board, move)
            continue
        end

        # UPDATE THE MODEL (i.e. feature values)
        ranking_update_model_b!(feature_values, features_of_all_boards, beta=beta, loop_eps=loop_eps)
        do_move!(board, move)
    end
end

function train_model_b(training_file::String; exclude=Vector{Int}(), folder="./data/models", save_model=false, dump_frequency=5000, with_prediction=false, feature_set::Symbol, beta=5.0, loop_eps=0.1)
    # FIND LATEST MODEL VERSION
    files = filter(x -> occursin(r"model_v\d+.*", x), readdir(folder))
    model_version = (isempty(files)) ? 1 : maximum(map(x -> parse(Int, match(r"model_v(\d+).*", x).captures[1]), files)) + 1

    # INITIALIZE EMPTY MODEL
    feature_values = Dict{UInt64, Gaussian}()

    # METADATA
    metadata = TrainingMetadata(training_file, exclude)

    # TRAIN MODEL
    games = open(training_file, "r")
    game_count = 0
    while !eof(games)
        game_str = strip(readline(games))
        game_count += 1
        
        if game_count ∈ exclude continue end

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

    close(games)

    # SAVE MODEL
    if save_model
        filename_model = "$folder/model_v$(model_version).txt"
        save_model(feature_values, filename_model)
    end

    return feature_values, metadata
end

function train_on_game_model_a(game_str::T, urgencies::Dict{UInt64, Gaussian}, metadata::TrainingMetadata; with_prediction::Bool, beta::Float64, loop_eps::Float64) where T<:AbstractString
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

        # id extraction 
        remaining_pieces = count_ones(board.bb_occ)
        move_ids = map(mv -> ((UInt(remaining_pieces) << 16) | (UInt(mv.src) << 10) | (UInt(mv.dst) << 4) | UInt(mv.type)), legals)

        # make an prediction given the current model
        if with_prediction
            prediction = predict_on_model_a(urgencies, move_ids, board, legals)
            push!(metadata.predictions, prediction)
        end

        # nothing to rank if only one legal move
        if length(legals) == 1
            do_move!(board, move)
            continue
        end

        # UPDATE THE MODEL (i.e. feature values)
        ranking_update_model_a!(urgencies, move_ids, beta=beta, loop_eps=loop_eps)
        do_move!(board, move)
    end
end


function train_model_a(training_file::String; exclude=Vector{Int}(), folder="./data/models", save_model=false, dump_frequency=5000, with_prediction=false, beta=5.0, loop_eps=0.1)
    # FIND LATEST MODEL VERSION
    files = filter(x -> occursin(r"model_v\d+.*", x), readdir(folder))
    model_version = (isempty(files)) ? 1 : maximum(map(x -> parse(Int, match(r"model_v(\d+).*", x).captures[1]), files)) + 1

    # INITIALIZE EMPTY MODEL
    urgencies = Dict{UInt64, Gaussian}()

    # METADATA
    metadata = TrainingMetadata(training_file, exclude)

    # TRAIN MODEL
    games = open(training_file, "r")
    game_count = 0
    while !eof(games)
        game_str = strip(readline(games))
        game_count += 1
        
        if game_count ∈ exclude continue end

        # TRAIN ON GAME
        train_on_game_model_a(game_str, urgencies, metadata, with_prediction=with_prediction, beta=beta, loop_eps=loop_eps)
        metadata.processed += 1
        print(metadata)

        # DUMP MODEL
        if save_model && metadata.processed % dump_frequency == 0
            filename_dump = abspath(expanduser("$folder/model_v$(model_version)_dump$(metadata.processed).txt"))
            save_model(feature_values, filename_dump)
        end
    end

    close(games)

    # SAVE MODEL
    if save_model
        filename_model = "$folder/model_v$(model_version).txt"
        save_model(feature_values, filename_model)
    end

    return urgencies, metadata
end
