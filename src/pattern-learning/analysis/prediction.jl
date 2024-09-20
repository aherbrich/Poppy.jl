struct Prediction
    predicted_values::Vector{Float64}
    predicted_rank::Int

    ply_number::Int
    nr_of_possible_moves::Int

    move_type::UInt8
end

function accuracy(predictions::Vector{Prediction})
    return count(x -> x.predicted_rank == 1, predictions) / length(predictions)
end

function calculate_board_values(feature_values::Dict{UInt64, Gaussian}, features_of_all_boards::AbstractArray)
    values = Vector{Float64}()

    for board in features_of_all_boards
        value = 0.0
        for feature in board
            value += (!haskey(feature_values, feature)) ? 0.0 : mean(feature_values[feature])
        end
        push!(values, value)
    end

    return values
end

function predict_on_model_b(urgencies::Dict{UInt64, Gaussian}, features_of_all_boards::AbstractArray, board::Board, legals::Vector{Move})
    values = calculate_board_values(urgencies, features_of_all_boards)
    
    predicted_rank = count(x -> x >= values[1], values) # >= forces s.t. predicted rank is only 1, if it is the (true) maximum (not one of possibly multiple maxima)
    return Prediction(values, predicted_rank, board.ply, length(legals), legals[1].type)
end
