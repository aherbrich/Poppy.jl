using Random

function test_on_game_model_a(game_str::T, urgencies::Dict{UInt64, Gaussian}, metadata::TestMetadata) where T <: AbstractString
    # SET BOARD INTO INITIAL STATE
    board = Board()
    set_by_fen!(board, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

    # TEST PRECISION OF MODEL ON GAME
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

        # PREDICT ON MODEL
        prediction = predict_on_model_a(urgencies, move_ids, board, legals)
        push!(metadata.predictions, prediction)

        do_move!(board, move)
    end

end

function test_model_a(urgencies::Dict{UInt64, Gaussian}, test_file::AbstractString; exclude=[])
    # METADATA
    metadata = TestMetadata(test_file, exclude)

    # TEST MODEL
    games = open(test_file, "r")
    game_count = 0
    while !eof(games)
        game_str = strip(readline(games))
        game_count += 1
        
        if game_count ∈ exclude continue end

        # TEST ON GAME
        test_on_game_model_a(game_str, urgencies, metadata)
        metadata.processed += 1
        print(metadata)
    end

    close(games)

    return metadata
end

function test_model_a(filename_model::T, test_file::AbstractString; exclude=[]) where T <: AbstractString
    urgencies = load_model(filename_model)
    
    return test_model_a(urgencies, test_file, exclude=exclude)
end

function test_on_game_model_b(game_str::T, feature_values::Dict{UInt64, Gaussian}, metadata::TestMetadata; feature_set::Symbol) where T <: AbstractString
    # SET BOARD INTO INITIAL STATE
    board = Board()
    set_by_fen!(board, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

    # TEST PRECISION OF MODEL ON GAME
    move_strings = split(game_str)
    for (i, move_str) in enumerate(move_strings)
        # sort expert move to the front of the move list
        _, legals = generate_legals(board)
        move = extract_move_by_san(board, move_str)
        best_move_idx = findfirst(mv -> mv.src == move.src && mv.dst == move.dst && mv.type == move.type, legals)
        legals[1], legals[best_move_idx] = legals[best_move_idx], legals[1]

        # feature extraction
        features_of_all_boards = extract_features_from_all_boards(board, legals, feature_set=feature_set)

        # PREDICT ON MODEL
        prediction = predict_on_model_b(feature_values, features_of_all_boards, board, legals)
        push!(metadata.predictions, prediction)

        do_move!(board, move)
    end

end

function test_model_b(feature_values::Dict{UInt64, Gaussian}, test_file::AbstractString; feature_set::Symbol, exclude=[])
    # METADATA
    metadata = TestMetadata(test_file, exclude)
    
    # TEST MODEL
    games = open(test_file, "r")
    game_count = 0
    while !eof(games)
        game_str = strip(readline(games))
        game_count += 1
        
        if game_count ∈ exclude continue end

        # TEST ON GAME
        test_on_game_model_b(game_str, feature_values, metadata, feature_set=feature_set)
        metadata.processed += 1
        print(metadata)
    end

    close(games)

    return metadata
end

function test_model_b(filename_model::T, test_file::AbstractString; feature_set::Symbol, exclude=[]) where T <: AbstractString
    urgencies = load_model(filename_model)
    
    return test_model_b(urgencies, test_file, feature_set=feature_set, exclude=exclude)
end

function analyse_models(training_file::String)
    nr_of_training_games = count_lines_in_files(training_file)
    
    # COMPUTE TRAINING AND TEST SET
    indices = shuffle(1:nr_of_training_games)
    training_indices = indices[1:round(Int, 0.85 * nr_of_training_games)]
    test_indices = indices[round(Int, 0.85 * nr_of_training_games):end]

    # TRAIN AND TEST MODEL A
    model_a , _ = train_model_a(training_file, exclude=test_indices, beta=1.0, loop_eps=0.01)
    test_metadata_a = test_model_a(model_a, training_file, exclude=training_indices)

    save_predictions(test_metadata_a.predictions, "./data/predictions/model_a.bin")

    # TRAIN AND TEST MODEL B
    model_b, _ = train_model_b(training_file, feature_set=:pieces, exclude=test_indices, beta=1.2, loop_eps=0.01)
    test_metadata_b = test_model_b(model_b, training_file, feature_set=:pieces, exclude=training_indices)

    save_predictions(test_metadata_b.predictions, "./data/predictions/model_b_pieces.bin")

    model_b, _ = train_model_b(training_file, feature_set=:possible_moves, exclude=test_indices, beta=1.2, loop_eps=0.01)
    test_metadata_b = test_model_b(model_b, training_file, feature_set=:possible_moves, exclude=training_indices)

    save_predictions(test_metadata_b.predictions, "./data/predictions/model_b_possible_moves.bin")

    model_b, _ = train_model_b(training_file, feature_set=:combi, exclude=test_indices, beta=1.2, loop_eps=0.01)
    test_metadata_b = test_model_b(model_b, training_file, feature_set=:combi, exclude=training_indices)

    save_predictions(test_metadata_b.predictions, "./data/predictions/model_b_combi.bin")
end