using Serialization

struct Prediction
    predicted_values::Vector{Float64}
    predicted_rank::Int

    ply_number::Int
    nr_of_possible_moves::Int

    move_type::UInt8
end

function accuracy(predictions::Vector{Prediction})
    if length(predictions) == 0
        @warn "No predictions to calculate accuracy on"
        return 0.0
    end
    return count(x -> x.predicted_rank == 1, predictions) / length(predictions)
end

function top_k_accuracy(predictions::Vector{Prediction}, k::Int)
    if length(predictions) == 0
        @warn "No predictions to calculate top-k accuracy on"
        return 0.0
    end
    return count(x -> x.predicted_rank <= k, predictions) / length(predictions)
end

function accuracy_random(predictions::Vector{Prediction})
    if length(predictions) == 0
        @warn "No predictions to calculate accuracy on"
        return 0.0
    end
    return count(x -> 1 == rand(1:x.nr_of_possible_moves), predictions) / length(predictions)
end

function top_k_accuracy_random(predictions::Vector{Prediction}, k::Int)
    if length(predictions) == 0
        @warn "No predictions to calculate top-k accuracy on"
        return 0.0
    end
    return count(x -> rand(1:x.nr_of_possible_moves) <= k, predictions) / length(predictions)
end

function save_predictions(predictions::Vector{Prediction}, filename::AbstractString)
    open(filename, "w") do io
        serialize(io, predictions)
    end

    @info("Predictions saved!",
        filename=filename,
        file_size_in_mb=stat(filename).size / 1024^2,
        nr_of_predictions=length(predictions),
        accuracy=accuracy(predictions)
    )
end

function load_predictions(filename::AbstractString)
    predictions::Vector{Prediction} = deserialize(filename)

    @info("Predictions loaded!",
        filename=filename,
        file_size_in_mb=stat(filename).size / 1024^2,
        nr_of_predictions=length(predictions),
        accuracy=accuracy(predictions)
    )
    return predictions
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

function predict_on_boardval_model(feature_values::Dict{UInt64, Gaussian}, features_of_all_boards::AbstractArray, board::Board, legals::Vector{Move})
    values = calculate_board_values(feature_values, features_of_all_boards)
    
    predicted_rank = count(x -> x >= values[1], values) # >= forces s.t. predicted rank is only 1, if it is the (true) maximum (not one of possibly multiple maxima)
    return Prediction(values, predicted_rank, board.ply, length(legals), legals[1].type)
end

function predict_on_urgency_model(urgencies::Dict{UInt64, Gaussian}, move_ids::AbstractArray, board::Board, legals::Vector{Move})
    values = [(!haskey(urgencies, move_id)) ? 0.0 : mean(urgencies[move_id]) for move_id in move_ids]
    
    predicted_rank = count(x -> x >= values[1], values) # >= forces s.t. predicted rank is only 1, if it is the (true) maximum (not one of possibly multiple maxima)
    
    return Prediction(values, predicted_rank, board.ply, length(legals), legals[1].type)
end

function predict_on_random_model(board::Board, legals::Vector{Move})
    values = rand(length(legals))
    predicted_rank = count(x -> x >= values[1], values) # >= forces s.t. predicted rank is only 1, if it is the (true) maximum (not one of possibly multiple maxima)
    
    return Prediction(values, predicted_rank, board.ply, length(legals), legals[1].type)
end