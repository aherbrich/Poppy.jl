struct Prediction
    predicted_values::Vector{Float64}
    predicted_rank::Int

    ply_number::Int
    nr_of_possible_moves::Int

    move_type::UInt8
end

function calculate_board_values(model::ValueTable, feature_sets::Vector{BoardFeatures})
    values = Vector{Float64}()

    for feature_set in feature_sets
        value = 0.0
        for feature in feature_set
            value += (isnothing(model[feature])) ? 0.0 : gmean(model[feature])
        end
        push!(values, value)
    end

    return values
end

function calculate_board_values(urgencies::Dict{UInt64, Gaussian}, weights::Dict{Tuple{UInt64, UInt64}, Gaussian}, feature_sets::Vector{BoardFeatures}; beta)
    return predict_on_new(urgencies, weights, feature_sets, beta=beta)
end

function predict_on(model::ValueTable, board::Board, legals::Vector{Move})
    features_of_all_boards = extract_features_from_all_boards(board, legals)
    values = calculate_board_values(model, features_of_all_boards)

    predicted_rank = count(x -> x >= values[1], values) # >= forces s.t. predicted rank is only 1, if it is the (true) maximum (not one of possibly multiple maxima)
    return Prediction(values, predicted_rank, board.ply, length(legals), legals[1].type)
end

function predict_on(urgencies::Dict{UInt64, Gaussian}, weights::Dict{Tuple{UInt64, UInt64}, Gaussian}, board::Board, legals::Vector{Move}; beta)
    features_of_all_boards = extract_features_from_all_boards(board, legals)
    vals = calculate_board_values(urgencies, weights, features_of_all_boards, beta=beta)
    values = map(x -> gmean(x), vals)
    
    predicted_rank = count(x -> x >= values[1], values) # >= forces s.t. predicted rank is only 1, if it is the (true) maximum (not one of possibly multiple maxima)
    return Prediction(values, predicted_rank, board.ply, length(legals), legals[1].type)
end

function accuracy(predictions::Vector{Prediction})
    return count(x -> x.predicted_rank == 1, predictions) / length(predictions)
end

