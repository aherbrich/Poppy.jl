using Random

function test_on_game_urgency_model(game_str::AbstractString, urgencies::Dict{UInt64, Gaussian}, hash_func::Symbol, metadata::TestMetadata)
    # SET BOARD INTO INITIAL STATE
    board = Board()
    set_by_fen!(board, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

    # TEST PRECISION OF MODEL ON GAME
    move_strings = split(game_str)
    for (i, move_str) in enumerate(move_strings)
        # SORT EXPERT MOVE TO THE FRONT OF THE MOVE LIST
        _, legals = generate_legals(board)
        move = extract_move_by_san(board, move_str)
        best_move_idx = findfirst(mv -> mv.src == move.src && mv.dst == move.dst && mv.type == move.type, legals)
        legals[1], legals[best_move_idx] = legals[best_move_idx], legals[1]

        # ID EXTRACTION
        move_ids = map(mv -> move_to_hash(mv, board, hash_func=hash_func), legals)

        # PREDICT ON MODEL
        prediction = predict_on_urgency_model(urgencies, move_ids, board, legals)
        push!(metadata.predictions, prediction)

        do_move!(board, move)
    end

end

function test_urgency_model(urgencies::Dict{UInt64, Gaussian}, hash_func::Symbol, test_file::AbstractString; exclude_games=Vector{Int}())
    metadata = TestMetadata(test_file, exclude_games)

    # TEST MODEL
    open(test_file, "r") do games
        for (idx, game_str) in enumerate(eachline(games))
            if idx in exclude_games continue end

            # TEST ON GAME
            test_on_game_urgency_model(game_str, urgencies, hash_func, metadata)
            metadata.processed += 1
            print(metadata)
        end
    end

    return metadata
end

function test_urgency_model(filename_model::AbstractString, hash_func::Symbol, test_file::AbstractString; exclude_games=Vector{Int}())
    return test_urgency_model(load_model(filename_model), hash_func, test_file, exclude_games=exclude_games)
end

function test_on_game_boardval_model(game_str::AbstractString, feature_values::Dict{UInt64, Gaussian}, feature_set::Symbol, metadata::TestMetadata)
    # SET BOARD INTO INITIAL STATE
    board = Board()
    set_by_fen!(board, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

    # TEST PRECISION OF MODEL ON GAME
    move_strings = split(game_str)
    for (i, move_str) in enumerate(move_strings)
        # SORT EXPERT MOVE TO THE FRONT OF THE MOVE LIST
        _, legals = generate_legals(board)
        move = extract_move_by_san(board, move_str)
        best_move_idx = findfirst(mv -> mv.src == move.src && mv.dst == move.dst && mv.type == move.type, legals)
        legals[1], legals[best_move_idx] = legals[best_move_idx], legals[1]

        # FEATURE EXTRACTION
        features_of_all_boards = extract_features_from_all_boards(board, legals, feature_set)

        # PREDICT ON MODEL
        prediction = predict_on_boardval_model(feature_values, features_of_all_boards, board, legals)
        push!(metadata.predictions, prediction)

        do_move!(board, move)
    end

end

function test_model_boardval_model(feature_values::Dict{UInt64, Gaussian}, feature_set::Symbol, test_file::AbstractString; exclude_games=Vector{Int}())
    metadata = TestMetadata(test_file, exclude_games)
    
    # TEST MODEL
    open(test_file, "r") do games
        for (idx, game_str) in enumerate(eachline(games))
            if idx in exclude_games continue end

            # TEST ON GAME
            test_on_game_boardval_model(game_str, feature_values, feature_set, metadata)
            metadata.processed += 1
            print(metadata)
        end
    end

    return metadata
end

function test_model_boardval_model(filename_model::AbstractString, feature_set::Symbol, test_file::AbstractString;  exclude_games=Vector{Int}())
    return test_model_boardval_model(load_model(filename_model), feature_set, test_file, exclude_games=exclude_games)
end

function test_on_game_random_model(game_str::AbstractString, metadata::TestMetadata)
    # SET BOARD INTO INITIAL STATE
    board = Board()
    set_by_fen!(board, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

    # TEST PRECISION OF MODEL ON GAME
    move_strings = split(game_str)
    for (i, move_str) in enumerate(move_strings)
        # SORT EXPERT MOVE TO THE FRONT OF THE MOVE LIST
        _, legals = generate_legals(board)
        move = extract_move_by_san(board, move_str)
        best_move_idx = findfirst(mv -> mv.src == move.src && mv.dst == move.dst && mv.type == move.type, legals)
        legals[1], legals[best_move_idx] = legals[best_move_idx], legals[1]

        # PREDICT ON MODEL
        prediction = predict_on_random_model(board, legals)
        push!(metadata.predictions, prediction)

        do_move!(board, move)
    end

end

function test_random_model(test_file::AbstractString;  exclude_games=Vector{Int}())
    metadata = TestMetadata(test_file, exclude_games)
    
    # TEST MODEL
    open(test_file, "r") do games
        for (idx, game_str) in enumerate(eachline(games))
            if idx in exclude_games continue end

            # TEST ON GAME
            test_on_game_random_model(game_str, metadata)
            metadata.processed += 1
            print(metadata)
        end
    end

    return metadata
end

function save_test_history(filename::AbstractString, training_file::AbstractString, training_indices::Vector{Int}, test_indices::Vector{Int})
    open(filename, "w") do file
        write(file, "$(abspath(expanduser(training_file)))\n")
        write(file, "$(join(training_indices, " "))\n")
        write(file, "$(join(test_indices, " "))\n")
    end
end

function read_test_history(filename::AbstractString)
    file = open(filename, "r") 
    training_file = readline(file)
    training_indices = parse.(Int, split(readline(file)))
    test_indices = parse.(Int, split(readline(file)))
     
    close(file)

    return training_file, training_indices, test_indices
end

function train_and_test_models(training_file::AbstractString, training_id::Int, training_indices::Vector{Int}, test_indices::Vector{Int})
    # TEST RANDOM MODEL
    test_metadata = test_random_model(training_file, exclude_games=test_indices)
    save_predictions(test_metadata.predictions, "./data/predictions/random_model_id_$(training_id).bin")

    # TRAIN AND TEST URGENCY MODEL
    _ , metadata = train_urgency_model(training_file, :v1, exclude_games=test_indices, beta=1.0, loop_eps=0.01, dump_model=true, training_id=training_id)
    for model_file in metadata.model_files
        test_metadata = test_urgency_model(model_file , :v1, training_file, exclude_games=training_indices)
        save_predictions(test_metadata.predictions, "./data/predictions/$(split(basename(model_file), ".")[1]).bin")
    end

    _ , metadata = train_urgency_model(training_file, :v2, exclude_games=test_indices, beta=1.0, loop_eps=0.01, dump_model=true, training_id=training_id)
    for model_file in metadata.model_files
        test_metadata = test_urgency_model(model_file , :v2, training_file, exclude_games=training_indices)
        save_predictions(test_metadata.predictions, "./data/predictions/$(split(basename(model_file), ".")[1]).bin")
    end

    _ , metadata = train_urgency_model(training_file, :v3, exclude_games=test_indices, beta=1.0, loop_eps=0.01, dump_model=true, training_id=training_id)
    for model_file in metadata.model_files
        test_metadata = test_urgency_model(model_file , :v3, training_file, exclude_games=training_indices)
        save_predictions(test_metadata.predictions, "./data/predictions/$(split(basename(model_file), ".")[1]).bin")
    end

    # TRAIN AND TEST BOARDVAL MODEL
    _ , metadata = train_model_boardval_model(training_file, :v1, exclude_games=test_indices, beta=2.0, loop_eps=0.01, dump_model=true, training_id=training_id)
    for model_file in metadata.model_files
        test_metadata = test_model_boardval_model(model_file, :v1, training_file, exclude_games=training_indices)
        save_predictions(test_metadata.predictions, "./data/predictions/$(split(basename(model_file), ".")[1]).bin")
    end

    _ , metadata = train_model_boardval_model(training_file, :v2, exclude_games=test_indices, beta=2.0, loop_eps=0.01, dump_model=true, training_id=training_id)
    for model_file in metadata.model_files
        test_metadata = test_model_boardval_model(model_file, :v2, training_file, exclude_games=training_indices)
        save_predictions(test_metadata.predictions, "./data/predictions/$(split(basename(model_file), ".")[1]).bin")
    end

    _ , metadata = train_model_boardval_model(training_file, :v3, exclude_games=test_indices, beta=2.0, loop_eps=0.01, dump_model=true, training_id=training_id)
    for model_file in metadata.model_files
        test_metadata = test_model_boardval_model(model_file, :v3, training_file, exclude_games=training_indices)
        save_predictions(test_metadata.predictions, "./data/predictions/$(split(basename(model_file), ".")[1]).bin")
    end

end

function train_and_test_models(training_file::String=""; max_test_set_size::Int=10000)
    nr_of_training_games = count_lines_in_files(training_file)
        
    # COMPUTE TRAINING AND TEST SET
    indices = shuffle(1:nr_of_training_games)
    split_point = max(round(Int, 0.85 * nr_of_training_games), nr_of_training_games - max_test_set_size)
    training_indices = indices[1:split_point]
    test_indices = indices[split_point+1:end]

    # SAVE TRAINING AND TEST INDICES (FOR REPRODUCIBILITY)
    test_id = rand(1:100000000)
    filename = "./data/test_history/$(test_id).txt"
    save_test_history(filename, training_file, training_indices, test_indices)

    train_and_test_models(training_file, test_id, training_indices, test_indices)
end

function train_and_test_models(test_set_id::Int)
    filename = "./data/test_history/$(test_set_id).txt"
    training_file, training_indices, test_indices = read_test_history(filename)
    train_and_test_models(training_file, test_set_id, training_indices, test_indices)
end