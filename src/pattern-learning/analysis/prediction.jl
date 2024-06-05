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

function predict_on(model::ValueTable, board::Board, legals::Vector{Move})
    features_of_all_boards = extract_features_from_all_boards(board, legals)
    values = calculate_board_values(model, features_of_all_boards)

    predicted_rank = count(x -> x > values[1], values) + 1
    return Prediction(values, predicted_rank, board.ply, length(legals), legals[1].type)
end

function accuracy(predictions::Vector{Prediction})
    return count(x -> x.predicted_rank == 1, predictions) / length(predictions)
end

