function ranking_update_by_sampling!(urgencies::Dict{UInt64, Gaussian}, weights::Dict{Tuple{UInt64, UInt64}, Gaussian}, boards::AbstractArray; no_samples=100000, beta=1.0)
    # extract a set of all features in all boards
    feature_set = Set{UInt64}()
    for board in boards
        for feature in board
            if !haskey(urgencies, feature)
                urgencies[feature] = GaussianByMeanVariance(0.0, 1.0)
            end
            push!(feature_set, feature)
        end
    end

    # ensure that all weights (=combinations of feature1, feature2) are initialized
    for feature1 in feature_set
        for feature2 in feature_set
            if !haskey(weights, (feature1, feature2))
                weights[(feature1, feature2)] = GaussianByMeanVariance(-0.35, 0.5)
            end
        end
    end

    no_posterior_samples = 0
    posterior_weights = Dict{Tuple{UInt64, UInt64}, Tuple{Float64, Float64}}()
    posterior_urgencies = Dict{UInt64, Tuple{Float64, Float64}}()
    
    for _ in 1:no_samples
        weights_sample = Dict{Tuple{UInt64, UInt64}, Float64}()
        urgencies_sample = Dict{UInt64, Float64}()
        for feature1 in feature_set
            for feature2 in feature_set
                weight = weights[(feature1, feature2)]
                weights_sample[(feature1, feature2)] = rand(Normal(gmean(weight), sqrt(variance(weight))))
            end
            urgency = urgencies[feature1]
            urgencies_sample[feature1] = rand(Normal(gmean(urgency), sqrt(variance(urgency))))
        end
        

        sum_of_rows_all_boards = Vector{Dict{UInt64, Float64}}(undef, length(boards))
        mask_all_boards = Vector{Dict{UInt64, Float64}}(undef, length(boards))
        latent_urgencies_all_boards = Vector{Dict{UInt64, Float64}}(undef, length(boards))
        masked_urgencies_all_boards = Vector{Dict{UInt64, Float64}}(undef, length(boards))
        values_all_boards = Vector{Float64}(undef, length(boards))
        for (k,board) in enumerate(boards)
            sum_of_rows = Dict{UInt64, Float64}()
            mask = Dict{UInt64, Float64}()
            latent_urgencies = Dict{UInt64, Float64}()
            masked_urgencies = Dict{UInt64, Float64}()
            value = 0.0

            for feature in board
                latent_urgencies[feature] = rand(Normal(urgencies_sample[feature], beta))

                sum_of_row = 0.0
                for feature2 in board
                    sum_of_row += weights_sample[(feature, feature2)]
                end
                sum_of_rows[feature] = sum_of_row
                mask[feature] = (sum_of_row > 0.0) ? 1.0 : 0.0
                masked_urgencies[feature] = latent_urgencies[feature] * mask[feature]
                value += masked_urgencies[feature]
            end

            latent_urgencies_all_boards[k] = latent_urgencies
            sum_of_rows_all_boards[k] = sum_of_rows
            mask_all_boards[k] = mask
            masked_urgencies_all_boards[k] = masked_urgencies
            values_all_boards[k] = value
        end

        # check if the current sample is the first one that has the highest value
        if count(x -> x >= values_all_boards[1], values_all_boards) == 1
            for feature1 in feature_set
                for feature2 in feature_set
                    if !haskey(posterior_weights, (feature1, feature2))
                        posterior_weights[(feature1, feature2)] = (0.0, 0.0)
                    end
                    old_mean, old_S = posterior_weights[(feature1, feature2)]
                    new_mean = old_mean + (weights_sample[(feature1, feature2)] - old_mean) / (no_posterior_samples + 1)
                    new_S = old_S + (weights_sample[(feature1, feature2)] - old_mean) * (weights_sample[(feature1, feature2)] - new_mean)
                    
                    posterior_weights[(feature1, feature2)] = (new_mean, new_S)
                end
                if !haskey(posterior_urgencies, feature1)
                    posterior_urgencies[feature1] = (0.0, 0.0)
                end
                old_mean, old_S = posterior_urgencies[feature1]
                new_mean = old_mean + (urgencies_sample[feature1] - old_mean) / (no_posterior_samples + 1)
                new_S = old_S + (urgencies_sample[feature1] - old_mean) * (urgencies_sample[feature1] - new_mean)
                posterior_urgencies[feature1] = (new_mean, new_S)
            end

            no_posterior_samples += 1
        end

        if no_posterior_samples == 100
            break
        end
    end

    if no_posterior_samples < 100
        @warn "Not enough posterior samples ($no_posterior_samples/100) to update the model.
        The model will not be updated."
        return
    end

    for feature1 in feature_set
        for feature2 in feature_set
            mean, S = posterior_weights[(feature1, feature2)]
            weights[(feature1, feature2)] = GaussianByMeanVariance(mean, S / no_posterior_samples)
        end
        mean, S = posterior_urgencies[feature1]
        urgencies[feature1] = GaussianByMeanVariance(mean, S / no_posterior_samples)
    end
end

function predict_on_new(urgencies::Dict{UInt64, Gaussian}, weights::Dict{Tuple{UInt64, UInt64}, Gaussian}, boards::AbstractArray; beta=1.0)
    feature_set = Set{UInt64}()
    for board in boards
        for feature in board
            push!(feature_set, feature)
        end
    end

    values = zeros(Float64, length(boards))
    for i in 1:5000
        weights_sample = Dict{Tuple{UInt64, UInt64}, Float64}()
        urgencies_sample = Dict{UInt64, Float64}()
        for feature1 in feature_set
            for feature2 in feature_set
                μ = (haskey(weights, (feature1, feature2))) ? gmean(weights[(feature1, feature2)]) : -0.35
                σ = (haskey(weights, (feature1, feature2))) ? sqrt(variance(weights[(feature1, feature2)])) : 0.5
                weights_sample[(feature1, feature2)] = rand(Normal(μ, σ))
            end
            μ = haskey(urgencies, feature1) ? gmean(urgencies[feature1]) : 0.0
            σ = haskey(urgencies, feature1) ? sqrt(variance(urgencies[feature1])) : 1.0
            urgencies_sample[feature1] = rand(Normal(μ, σ))
        end
        

        sum_of_rows_all_boards = Vector{Dict{UInt64, Float64}}(undef, length(boards))
        mask_all_boards = Vector{Dict{UInt64, Float64}}(undef, length(boards))
        latent_urgencies_all_boards = Vector{Dict{UInt64, Float64}}(undef, length(boards))
        masked_urgencies_all_boards = Vector{Dict{UInt64, Float64}}(undef, length(boards))
        values_all_boards = Vector{Float64}(undef, length(boards))
        for (k,board) in enumerate(boards)
            sum_of_rows = Dict{UInt64, Float64}()
            mask = Dict{UInt64, Float64}()
            latent_urgencies = Dict{UInt64, Float64}()
            masked_urgencies = Dict{UInt64, Float64}()
            value = 0.0

            for feature in board
                latent_urgencies[feature] = rand(Normal(urgencies_sample[feature], beta))

                sum_of_row = 0.0
                for feature2 in board
                    sum_of_row += weights_sample[(feature, feature2)]
                end
                sum_of_rows[feature] = sum_of_row
                mask[feature] = (sum_of_row > 0.0) ? 1.0 : 0.0
                masked_urgencies[feature] = latent_urgencies[feature] * mask[feature]
                value += masked_urgencies[feature]
            end

            latent_urgencies_all_boards[k] = latent_urgencies
            sum_of_rows_all_boards[k] = sum_of_rows
            mask_all_boards[k] = mask
            masked_urgencies_all_boards[k] = masked_urgencies
            values_all_boards[k] = value

            old_value = values[k]
            new_value = old_value + (value - old_value) / i
            values[k] = new_value
        end
    end

    return values
end